#!/usr/bin/perl

# cum_hyperg_pval_info (Cummulative hypergeometric) gets 4 values gp, tg, tp, and t (see below for definitions).
# It calculates the cumulative hypergeometric distribution p-values from
# 0 to gp as we as gp to tp.  Which ever cumulative p-value is smaller is returned.  
# If the sum from 0 to gp is returned the number of gp in our tp is under-represented.
# If the sum from go to tp is returned the number of gp in our tp is over-reresentative of the total good population (tg)

# disttest (distribution test) takes the same parameters as cum_hyperg_pval_info but returns 
# the sum from 0 to tp to test the accuracy of the distribution (should be very close to 1)

# $gp = good picked
# $tg = total good
# $tp = total picked
# $t = total

use strict;

package Statistics::Hypergeometric;
require Exporter;

our @ISA = qw(Exporter);

our @EXPORT = qw(ln_n_choose_k cum_hyperg_pval_info disttest $pi @fact);
our @EXPORT_OK = qw(ln_n_choose_k LNfact LNhypergeometric LNstirling);
our %nk;
our %LNfact;
our $pi = atan2(1,1)*4; # value needed for Stirling's approximation of factorials
our @fact = (0,0,0.693147180559945,1.791759469228055,3.178053830347946,4.787491742782046,6.579251212010101,8.525161361065415,
						 10.60460290274525,12.80182748008147,15.10441257307552,17.50230784587389,19.98721449566188,22.55216385312342,
						 25.19122118273868,27.89927138384089,30.6718743941422, 33.5050860689909, 36.3954564338402, 39.3398942384233, 42.335625512472, 45.3801470926379); # A list of factorial values of their respective reference nu
	
sub ln_n_choose_k { # Returns the natural log of n choose k        
	my ($n, $k) = @_;
	if($nk{"$n-$k"}){return $nk{"$n-$k"};}
	die "improper k: $k, n: $n\n" if $k > $n or $k < 0;
	$k = ($n - $k) if ($n - $k) < $k;
	$LNfact{$n} = &LNfact($n) unless $LNfact{$n};
	$LNfact{$k} = &LNfact($k) unless $LNfact{$k};
	$LNfact{$n-$k} = &LNfact($n-$k) unless $LNfact{$n-$k};
	my $result = $LNfact{$n}-$LNfact{$k}-$LNfact{$n-$k};
	$nk{"$n-$k"}=$result;
	return $result;
	#	$k = ($n - $k) if ($n/2) < $k;
		# $k = ($n - $k) if ($n - $k) < $k;
	#	my $result=1;
		#for(my $i=1;$i<=$k;$i++){$result *= ($n-$k+$i)/$i;}
		#return $result;
}

sub LNfact { # Returns the natural log of the factorial of the value passed to it.  Uses Stirling's approximation for large factorials
	my ($z) = @_;
	if ($z >= scalar(@fact)) {return &LNstirling($z); }# print "approx of z ($z) = $result<br/>";
	elsif ($z < scalar(@fact)) {return $fact[$z]}
}

sub LNhypergeometric { # Returns the p-value for a particular overlap
	my ($gp, $tg, $tp, $t) = @_;
	#print "2nd -> ($gp, $tg, $tp, $t)<br/>";
	return 0 if $t - $tg < $tp - $gp;
	return &ln_n_choose_k($tg, $gp) + &ln_n_choose_k($t - $tg, $tp - $gp) - &ln_n_choose_k($t, $tp);
}

sub LNstirling { # For large values of n, (n/e)n square root(2n pi) < n! < (n/e)n(1 + 1/(12n-1)) square root(2n pi): Stirling's Formula.
	my ($x) = @_;
	my $S = 0.5*(log (2*$pi)) + 0.5*(log $x) + $x*(log $x) - $x;
	my $upadd = log(1 + (1/(12*$x - 1)));
	my $approx = $S + $upadd; # using the upper bound gives more conservative (and accurate) p-values.
	return $approx;
}

sub cum_hyperg_pval_info { 
	my ($gp, $tg, $tp, $t) = @_;
#	print "-> $gp, $tg, $tp, $t<br/>";
	if($tg==$t){return (1, "tg == t, what did you expect?");}
	if($tg==0){return (1, "tg == 0, what did you expect?");}
	if($tp==$t && $tg == $gp){return (1, "represented?: $gp|$tp|$tg|$t");}
#	die "ERROR: improper input values for hypergeometric distribution.\n" if $gp<0 or $gp>$tg or $gp>$tp or $tg<0 or $tg>$t or $tp<0 or $tp>=$t or $t<0;
	if ($tg < $tp){ # setting B to the smaller of the two counts optimizes the p-value calculation
		my $temp = $tp;
		$tp = $tg;
		$tg = $temp;
	}
	#print "1st -> ($gp, $tg, $tp, $t)<br/>";
	my ($resultR,$resultL);
	for (my $i = $gp; $i<=$tp; $i++){ # sum from AB to right in distribution
		# exp = e ^ x (inverse of ln)
		my $right = &LNhypergeometric($i,$tg,$tp,$t);
		if($right != 0){$right = exp($right);}
		$resultR += $right;
	}
	for (my $i = 0; $i<=$gp; $i++){ # sum from left to AB in distribution
		my $left = &LNhypergeometric($i,$tg,$tp,$t);
		if($left != 0){$left = exp($left);}
		$resultL += $left;
	}

	# pick the smaller of the two sections of the distribution as it is the one that is in the tail instead of around the mean and a tail...meaning that
	# which ever is smaller tells us if we are over or under represented....
	if ($resultR < $resultL){return ($resultR, "over-represented: $gp|$tp|$tg|$t")}
	else{return ($resultL, "under-represented: $gp|$tp|$tg|$t")} 
}

sub disttest{ #sums over all overlaps to test the accuracy of the distribution
	my ($gp, $tg, $tp, $t) = @_;
	die "ERROR: improper input values for hypergeometric distribution.\n" if $gp<0 or $gp>$tg or $gp>$tp or $tg<0 or $tg>$t or $tp<0 or $tp>$t or $t<0;
	if ($tg < $tp){ # setting B to the smaller of the two counts optimizes the p-value calculation
		my $temp = $tp;
		$tp = $tg;
		$tg = $temp;
	}
	my $result;
	for (my $i = 0; $i<=$tp; $i++){ # sum from left to AB in distribution
		$result += exp (&LNhypergeometric($i,$tg,$tp,$t));
	}
	return ($result);
}
