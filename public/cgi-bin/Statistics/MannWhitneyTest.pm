#! /usr/bin/perl -w

package Statistics::MannWhitneyTest;
use strict;

use Statistics::Distributions qw(uprob); # for determining the p-value of a z-score
use Carp;
#use Data::Dumper;
##Define the fields to be used as methods
my %fields = (
		  data1	=>	undef,  # dataset1
			data2 => undef # dataset2
		);


# stuff needed for EXACT calculation (n choose k, specifically)
our %LNfact;
our $pi = atan2(1,1)*4; # value needed for Stirling's approximation of factorials
our @fact = (0,0,0.693147180559945,1.791759469228055,3.178053830347946,4.787491742782046,6.579251212010101,8.525161361065415,
						 10.60460290274525,12.80182748008147,15.10441257307552,17.50230784587389,19.98721449566188,22.55216385312342,
						 25.19122118273868,27.89927138384089,30.6718743941422, 33.5050860689909, 36.3954564338402, 39.3398942384233, 42.335625512472, 45.3801470926379); # A list of factorial values of their respective reference nu
						
						
# initialize
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = {
    %fields,
    data1 => \%fields,
		data2 => \%fields
  };
	$self->{shortest} = [];
	$self->{rankData} = [];
	
  bless ($self, $class);
  return $self;
}

# load 2 data sets
sub load_data{
  my ($self, $dataset1, $dataset2) = @_;
	# check that dataSets exist and that they are valid array references
	if(!$dataset1 || !$dataset2 || ref($dataset1) ne 'ARRAY' || ref($dataset2) ne 'ARRAY'){
		croak "Need to pass 2 array references to load_data";
	}
	# check that datasets contain data > 0 
	my @dataset = grep { $_ > 0 } @{ $dataset1 };
	croak "dataset1 has no element greater 0\n" unless (@dataset);
	@dataset = grep { $_ > 0 } @{ $dataset2 };
	croak "dataset2 has no element greater 0\n" unless (@dataset);
	
	# store the 2 datasets, sorted. By default dataset1 will be the shorter one
	my @sorted1 = sort {$a <=> $b} @{$dataset1};
	my @sorted2 = sort {$a <=> $b} @{$dataset2};
	if(scalar(@sorted1) <  scalar(@sorted2)){
		$self->{data1} = \@sorted1;
		$self->{n1} = scalar(@sorted1);
		$self->{data2} = \@sorted2;
	  $self->{n2} = scalar(@sorted2);
	}
	else{
		$self->{data1} = \@sorted2;
		$self->{n1} = scalar(@sorted2);
		$self->{data2} = \@sorted1;
	  $self->{n2} = scalar(@sorted1);
	}
	
	# store an array that contains the data from both sets
	my @total = sort {$a <=> $b} (@sorted1, @sorted2);
	$self->{totalData} = \@total;
	$self->{totalN} = $self->{n2} + $self->{n1};
		
	# iterate over totalData, push ranks of data into rankData, averaging the ranks of ties
	# also store info about ties since if we are using the normal approxiamtion to
	# calculate a p-value we will need it to calculate the standard deviation
	$self->{rankData} = [];
	$self->{tieData} = {};
	my $previous = $self->{totalData}->[1];
	my $start = 0;
	my $tieCounter=0;
	for(my $i=0; $i < $self->{totalN}; $i++){
		# if we've hit a tie
		if($self->{totalData}->[$i] == $previous){
			$self->{tieData}->{$self->{totalData}->[$i]} = 0;
			my $mean_rank = ($start+$i+2)/2.0;
	    for(my $j=$start; $j<=$i; $j++){
				$self->{tieData}->{$self->{totalData}->[$i]}++;
		 		$self->{rankData}->[$j] = $mean_rank;
	    }
	  }
	  else{
		 	$self->{rankData}->[$i] = $i+1;
	    $previous = $self->{totalData}->[$i];
	    $start = $i;
	  }
	}
	
	# sum the ranks in the shortest (meaning dataset 1, see above) list (because it is the fastest?)
	$self->{sumRank1} = 0;
	$previous=0;
	for(my $i=0; $i < $self->{n1}; $i++){
		for(my $j=$previous; $j < $self->{totalN}; $j++){
			if($self->{data1}->[$i] == $self->{totalData}->[$j]){
				$j = $self->{totalN}; $previous--;
			}
			$previous++;
		}
		$self->{sumRank1} += $self->{rankData}->[$previous];	  
	}
	return;
}

# return MannWhitney probability
sub probability{
	my $self=shift;
	if(!$self->{n1} || !$self->{n2}){croak "Need to load data using load_data before you can call this method!";}
	if($self->{totalN} <= 20){
		return $self->exactPvalue();
	}
	# else return normal approximation
	return $self->normalApproximation();
}

# 2 sided normal approxiamation of p-value
sub normalApproximation{
	my $self = shift;	
	return 2*&uprob(abs($self->normalZscore()));
}

sub normalZscore{
	my $self = shift;
	if(!$self->{n1} || !$self->{n2}){croak "Need to load data using load_data before you can call this method!";}
	# calculate U values
	$self->uValues();
	
	# calculate mean
	$self->mean();
	
	# calculate standard deviation
	$self->std_dev();
	
	# continuity correction, to account for the fact that we use a continuous probability 
	# function (the normal distribution) and our test value is based on discrete (ordinal, ranked) data. 
	# If the difference U-mean is negative the continuity correction is +0.5 (this is the case when U < mean). 
	# If the difference U-mean is positive the correction is -0.5 (this is the case when U > mean).
	my $continuity = ($self->{mean} > $self->{smallestU}) ? 0.5 : -0.5;
	return abs($self->{smallestU} - $self->{mean} + $continuity ) / $self->{std_dev};
}


# return the calculated U values for the 2 datasets...
sub uValues{
	my $self=shift;
	# Cached?
  return ($self->{U1}, $self->{U2}) if (defined $self->{U1} && defined $self->{U2});

	if(!$self->{n1} || !$self->{n2}){croak "Need to load data using load_data before you can call this method!";}
	$self->{U1} = $self->{sumRank1} - (($self->{n1} * ($self->{n1}+1) ) / 2) ;
	$self->{U2} = $self->{n2} * $self->{n1} - $self->{U1};
	$self->{smallestU} = ( $self->{U1} < $self->{U2} ) ? $self->{U1} : $self->{U2};
	return ($self->{U1}, $self->{U2});
}

sub mean{
	my $self=shift;
	# Cached?
  return $self->{mean} if defined $self->{mean};
	if(!$self->{n1} || !$self->{n2}){croak "Need to load data using load_data before you can call this method!";}
  return $self->{mean} = ($self->{n2} * $self->{n1})/ 2;
}

sub std_dev{
	# standard deviation calculation from http://www.distancelearningcentre.com/resources/Mannwhitney.pdf
	my $self=shift;
	# Cached?
  return $self->{std_dev} if defined $self->{std_dev};
	if(!$self->{n1} || !$self->{n2}){croak "Need to load data using load_data before you can call this method!";}
	
	my @tieArray = values %{$self->{tieData}};
	if(@tieArray > 0){
		my $lhs = ($self->{n1}*$self->{n2} ) / ($self->{totalN} * ($self->{totalN} - 1));
		my $rhsStart = ($self->{totalN}**3 - $self->{totalN}) / 12;
		my $rhsEnd = 0;
		foreach my $size(@tieArray){
			$rhsEnd+= ($size**3 - $size) / 12;
		}
		return $self->{std_dev} = sqrt($lhs * ($rhsStart - $rhsEnd));
	}
	else{
		return $self->{std_dev} = sqrt($self->{n1}*$self->{n2}*($self->{totalN}+1)/12.0);
	}
}

#
# This routine recursively counts the number of distributions of ranks over two
# samples for which the sum of the ranks in the smaller sample is smaller than or
# equal to a given upper bound W.
# $W = the bound, $Sum = the sum of ranks upto now, $m-1 = one less than the
# number of elements in the smaller sample that still have to be done, 
# $Start = the current position in the ranks list, *RankList = the array
# with all the ranks (this is NOT just the numbers from 1 - N because of ties).
# The list with ranks MUST be sorted in INCREASING order.
# CountSmallerRanks($W, $Sum, $m-1, $Start, $RankList) -> Smaller
sub CountSmallerRanks{		
  my($W, $Sum, $m, $Start, $rankList) = @_;
	# use Data::Dumper;
	# print Dumper(\@_);
  my($i, $Temp, $Smaller, $End, $mminus1) = (0, 0, 0, 0, 0);
  # There are no values smaller than W
  if($Sum > $W){ return 0;}
  $End = $#{$rankList};
  # Check all subsets of the remaining of RankList
  if($m > 0){ 
    $mminus1 = $m-1;
    for($i = $Start; $i <= $End-$m; ++$i){ 
      my $temp = $Sum + $rankList->[$i];
      if($temp > $W){ return $Smaller;};	# No smaller values expected anymore
      $Smaller += &CountSmallerRanks($W, $temp, $mminus1, $i+1, $rankList);
    }
  }
  else{ 
    # If even adding the highest rank doesn't reach $W, 
    # return the remaining number of items
    if($Sum + $End + 1 <= $W){ return $End - $Start + 1;};
    for($i = $Start; $i <= $End; ++$i){ 
      my $temp = $Sum + $rankList->[$i];
      if($temp <= $W){ $Smaller++;}
			# No smaller values expected anymore
      else{ return $Smaller;}
    }
  }
  $Smaller;
}

sub exactPvalue{
	my $self=shift;
	my $lnPartitionCount = &ln_n_choose_k($self->{totalN}, $self->{n1});
	my $sumFrequencies = 2.718281828459045**$lnPartitionCount;
	
	my $MaxSum = $self->{totalN}*($self->{totalN}+1)/2;
	my $H0 = $MaxSum/2.0;
	$self->{sumRank1}  = ($self->{sumRank1} > $H0) ? $MaxSum - $self->{sumRank1}  : $self->{sumRank1} ;
	my $less = &CountSmallerRanks($self->{sumRank1}, 0, $self->{n1}-1, 0, $self->{rankData});
	if(log(2*$less) > $lnPartitionCount){
		$less = CountSmallerRanks($self->{sumRank1}-1, 0, $self->{n1}-1, 0, $self->{rankData});
		$less = $lnPartitionCount - $less;
	}

	my $p = 2.0*$less / $sumFrequencies;
	return $p;
}
	
sub ln_n_choose_k { # Returns the natural log of n choose k        
	my ($n, $k) = @_;
	die "improper k: $k, n: $n\n" if $k > $n or $k < 0 or !$n or !$k;
	$k = ($n - $k) if ($n - $k) < $k;
	$LNfact{$n} = &LNfact($n) unless $LNfact{$n};
	$LNfact{$k} = &LNfact($k) unless $LNfact{$k};
	$LNfact{$n-$k} = &LNfact($n-$k) unless $LNfact{$n-$k};
	my $result = $LNfact{$n}-$LNfact{$k}-$LNfact{$n-$k};
	return $result;
}

# Returns the natural log of the factorial of the value passed to it.  Uses Stirling's approximation for large factorials
sub LNfact { 
	my ($z) = @_;
	if ($z >= scalar(@fact)) {return &LNstirling($z); }# print "approx of z ($z) = $result<br/>";
	elsif ($z < scalar(@fact)) {return $fact[$z]}
}

# For large values of n, (n/e)n square root(2n pi) < n! < (n/e)n(1 + 1/(12n-1)) square root(2n pi): Stirling's Formula.
sub LNstirling { 
	my ($x) = @_;
	my $S = 0.5*(log (2*$pi)) + 0.5*(log $x) + $x*(log $x) - $x;
	my $upadd = log(1 + (1/(12*$x - 1)));
	my $approx = $S + $upadd; # using the upper bound gives more conservative (and accurate) p-values.
	return $approx;
}

1;

