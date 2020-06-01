#!/usr/bin/perl -w
# ******************************************************
# histogram creation tool
# Program created on 30 - April - 2010
# Authored by: John Dittmar
# ******************************************************

BEGIN {
	$|=1;
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
	use CGI qw/:standard/;
	$CGI::HEADERS_ONCE = 1;
}

use strict;
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use GD::Graph::histogram;
use Statistics::Descriptive;
use DBI;
use Storable qw(retrieve); # the storable data persistence module
use Modules::ScreenAnalysis qw(:histogram); # use my module and only load routines in analysis

my $size_limit = 10;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 10 MB limit
my $q=new CGI;

my $static_path = &static_asset_path();
my %variables;
unless(&initialize($q, $size_limit)){die;}
if(&validateUser(\%variables, $q) != 1){die;} # validate user

# temporary directory where we will store stuff
# set '$variables{base_upload_dir'} and $variables{'base_dir'}
&getBaseDirInfo(\%variables,'dr',$q);
# retrieve current working directory (the temporary directory specific to this user where data structures are stored via storable)
my $upload_dir=&setSession('dr_engine', \%variables, $q);

if(!$upload_dir){
	print $q->header(); # the "magic line" that tells the WWW that we are an HTML document
	&update_error("Error with user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
	die "Could not set user session $!";
}


&directory_setup(\%variables, $q);


# the variables hash holds a bunch of static variables while this program is being performed so that they do not have to be passed via forms
# %variables contains: density, control, replicates, justAnalysis, project_id, user, key_choice, lib_screened, pre_screen_reps,
# matingT, gal_leu, sec_gal_leu, final
my $variables= eval{retrieve("$upload_dir/variables.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with variables.dat: $@";}
elsif(!$variables){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with variables.dat: $!";}
if($variables->{'save_directory'} ne $upload_dir){
	&update_error("The upload directory calculated does not match your earlier stored upload directory.<br/>Cannot find your data!<br/>".&contact_admin(), $q);
	die "The upload directory calculated ($upload_dir) does not match your earlier stored upload directory ($variables{'save_directory'}).  Quiting. $!";
}
# ++++++++++++++++++ START RETRIEVING DATA STRUCTURES SAVED TO DISK +++++++++++++++++++++

my $plateData = eval{retrieve("$upload_dir/plate_data.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with plate_data.dat: $@";}
elsif(!$plateData){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with plate_data.dat: $!";}
my $normalization_values= eval{retrieve("$upload_dir/normalization_values.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with normalization_values.dat: $@";}
elsif(!$normalization_values){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with normalization_values.dat: $!";}
my $dynamicVariables;
# ++++++++++++++++++ END RETRIEVING DATA STRUCTURES SAVED TO DISK +++++++++++++++++++++

%variables=(); # no longer need this one
$variables->{'publicSaveDir'} = &setupPublicTempDir("../../temp/dr/", $variables->{'user'},$q);
$variables->{'htmlDir'} = $variables->{'publicSaveDir'};
$variables->{'htmlDir'} =~ s/^[\.\.\/]+/$static_path->{'base'}\//;

#++++++++++++++++ START COLONY EXCLUSION SET UP +++++++++++++++++++++++++++++++++
# in the previous section of the screen data analysis process users were given to option to
# exclude colonies from statistical consideration.  The following code takes those choices and builds
# a data structure from them.  In this way, later in this program we can use the exists funciton
# to determine if a particular colony is supposed to be excluded from statistical consideration or not.
# the data structure is:
# hash -> hash -> hash -> hash
# gene->condition->plate->plate_position
# plate position is the numerical colony position, counting vertically then horizontally (eg the top left most colony in a 384 formated plate = 0
# and the bottom right most colony = 383)
my $modDivisor = ($variables->{'replicates'} eq '16') ? 4 : 2;
my %reOrderedPlateData;
foreach my $plate(keys %{$plateData}){
	foreach my $query(keys %{$plateData->{$plate}}){
		foreach my $condition(keys %{$plateData->{$plate}->{$query}}){
			$reOrderedPlateData{$query}->{$condition}->{$plate}=1;
		}
	}
}

&update_message("Analyzing Raw Data", $q);
my $html='<br/>NOTE! The scale of the y-axis may be different for each image.</br><center>';
foreach my $query(keys %reOrderedPlateData){
	foreach my $condition(keys %{$reOrderedPlateData{$query}}){
		my $count=0;
		my (@rawData,@normalizedData) =((),());
		my $modQuery = $query; # still need this
		$modQuery=~ s/^0000_// if $query eq $variables->{'control'}; # remove 0000_ tag used to present controls first
		my $plateLabel;
		if(! defined $condition){	$condition='';	}
		foreach my $plate(keys %{$reOrderedPlateData{$query}->{$condition}}){

			$plateLabel = $variables->{'originalData'}->{$plate}->{$modQuery}->{$condition};
			my $dead_size=($normalization_values->{$plate}->{$modQuery}->{$condition}*$variables->{'death_threshold_cutoff'});
			if(!defined($plateData->{$plate}->{$query}->{$condition}->[0])){
				delete($plateData->{$plate}->{$query}->{$condition});
				$query =~ s/^0000_//;
			}

			# if exclusion data structure does not exists for this plate, query, condition combo, then initialize it!
			if(!$dynamicVariables->{'excluded_colonies'}->{$plate}->{$modQuery}->{$condition}){
				$dynamicVariables->{'excluded_colonies'}->{$plate}->{$modQuery}->{$condition}={};
			}
			# if the user has elected to run global exclusion
			if($variables->{'runGlobalExclusion'}){
				&checkForGlobalExclusion(
					$plateData->{$plate}->{$query}->{$condition}->[0], # reference to an array that contains all the data for a given plate, condition, and gene combo
					$dynamicVariables->{'excluded_colonies'}->{$plate}->{$modQuery}->{$condition},
					$dead_size,
					$variables->{'density'},
					$variables->{'rows'},
					$variables->{'cols'},
					$plateLabel,
					$q);
			}
			&checkForReplicateExclusion(
					$dynamicVariables->{'excluded_colonies'}->{$plate}->{$modQuery}->{$condition},
					$variables->{'rows'},
					$variables->{'cols'},
					$dead_size,
					$plateData->{$plate}->{$query}->{$condition}->[0], # reference to an array that contains all the data for a given plate, condition, and gene combo
					$variables->{'replicates'},$variables->{'replicateExclusion'}, $modDivisor, $q);

			my $nv = $normalization_values->{$plate}->{$query}->{$condition};
			if($variables->{'normalization_method'} eq 'nothing'){
				$nv=&getArrayMedian($plateData->{$plate}->{$query}->{$condition}->[0]);
				$variables->{'normalization_method'}='median';
			}
			if(!$nv){$nv=1;}
			my($current_col, $current_row)=(0,0);
			for(my $current_row=0;$current_row < $variables->{'rows'};$current_row++) {
				for(my $current_col = 0; $current_col < $variables->{'cols'}; $current_col++){
					my $pos=($current_row)+($current_col*$variables->{'rows'});
					# if colony is not excluded, then consider it....
					if(!${$dynamicVariables->{'excluded_colonies'}->{$plate}->{$query}->{$condition}->{$pos}}[0]){
						push(@rawData, $plateData->{$plate}->{$query}->{$condition}->[0]->[$pos]);
						#if($nv != 1){push(@normalizedData, ($plateData->{$plate}->{$query}->{$condition}->[0]->[$pos] / $nv ));}
						if($plateData->{$plate}->{$query}->{$condition}->[0]->[$pos] < 5){$count++;}
					}
				}
			}
		}
		my $label = (defined $condition && $condition ne '') ? "$plateLabel->{'query'} - $plateLabel->{'condition'}" : $plateLabel->{'query'};
		&update_message("Generating histogram for $label", $q);
		&plotHistogram(\@rawData, "$plateLabel->{'query'}$plateLabel->{'condition'} - raw", $variables->{'publicSaveDir'});
		$html.="<br/>Raw Data - $label<br/><img src=\"$variables->{'htmlDir'}/$plateLabel->{'query'}$plateLabel->{'condition'} - raw.png\" /></br/><br/>";
	}
}
$html.='</center><br/><br/><small><strong>Note: Histograms are based on raw data values only. Histogram bin selection based on:<br/>Shimazaki H. and Shinomoto S., A method for selecting the bin size of a time histogram. Neural Computation (2007) Vol. 19(6), 1503-1527</br/>';
print	<<HTML;
	<script type="text/javascript">
		parent.document.getElementById('flashMessageContainer').style.top='10px';
		parent.document.getElementById('flashMessageContainer').style.width='600px';
		parent.document.getElementById('flashMessageContainer').style.height='90%';
		parent.document.getElementById('flashMessageContainer').style.overflowX ='scroll';
		parent.document.getElementById('flashMessageContainer').style.background ='white';
	</script>
HTML
&update_done($html, 'Histogram Results',  $q);
exit;
#+++++++++++++++++++++++++ END COLONY EXCLUSION SET UP +++++++++++++++++++++++++++

# setup an alphabet array so that rows can be associated with the proper letter
# designation
my @alphabet=("A".."ZZ");
my $keyInfo;
my $resthead ='';
#+++++++++++++++++++++++ START KEY FILE PROCESSING +++++++++++++++++++++++++++++++++
if($variables->{'key_choice'} ne 'none'){
	# retrieve the key file that the user selected, store in file handle
	$keyInfo = eval{retrieve("$variables->{'key_dir'}/$variables->{'key_file_name'}.dat")};
	my $err=$@;
	$resthead = eval{${retrieve("$variables->{'key_dir'}/$variables->{'key_file_name'}-head.dat")}};
	if($@ || $err || !$resthead || !$keyInfo){
		if($err || !$keyInfo){warn "Could not retrieve stored key data structure from $variables->{'key_dir'}/$variables->{'key_file_name'}.dat: $err";}
		else{warn "Could not retrieve stored key data structure from $variables->{'key_dir'}/$variables->{'key_file_name'}-head.dat: $@";}
		my ($keyInfo, $resthead)= &setupKeyFile($variables, $q);
	}
}
#+++++++++++++++++++++++ END KEY FILE PROCESSING +++++++++++++++++++++++++++++++++

## NOW THAT ALL VARIABLES HAVE BEEN INITIALIZED AND VERIFIED....
## *************************************************************************************
## ************ CHECK IF DATA FROM THIS ANALYSIS (SCREEN) IS ALREADY STORED ************
## *************************************************************************************

my($screen_id, $dbh, $cpad_dh, $cpas_dh, $sqlite_flag,$sqlite_info);
$variables->{'store'}=0;
$sqlite_info->{'flag'}=0;
$variables->{'statsMethod'}="normal";


my($plateStats,
	 $originalData,
	 $excludedData,
	 $plate_summary,
	 $control_plate_details	)=&generateDescriptiveStats(
																								$variables->{'control'}, $plateData, $normalization_values, $variables,
																								$dynamicVariables->{'excluded_plates'}, $dynamicVariables->{'excluded_colonies'},
																								$sqlite_info, $q
																							);


sub plotHistogram{
	my($data, $fileName, $saveTo, $xLabel, $yLabel)=@_;
	if(!$fileName){$fileName = "histogram";}
	my $graph = new GD::Graph::histogram(450,450);
	# my $bins = int(($numberDataPoints**(1/3)*2+0.5)); # rice rule
	# $bins = int((1 + &log2($numberDataPoints)+0.5)); # Sturgis's rule
	my $bins =  &shimazakiBinOpt($data);
	$graph->set(
						x_label         => 'Bin Center',
						y_label         => 'Count',
						title           => '',
						x_labels_vertical => 1,
						bar_spacing     => 0,
						shadow_depth    => 1,
						shadowclr       => 'dred',
						transparent     => 0,
						histogram_bins => $bins,
						histogram_type => 'count',

	) or warn $graph->error;

	my $gd = $graph->plot($data) or die $graph->error;

	open(IMG, ">$saveTo/$fileName".'.png') or die $!;
	binmode IMG;
	print IMG $gd->png;
	close IMG;
}


sub shimazakiBinOpt{
	my $data = shift;
	my ($max, $min) = (sort { $b <=> $a } @{$data})[0, $#{$data}];
	my $nMin = 4; # minimum # of bins
	my $nMax = 50; # maximum # of bins
	my @n = ($nMin..$nMax); # number of bins
	my @d; # bin size vector
	my $diff = $max-$min;
	foreach(@n){	push(@d, $diff/$_); }
	my $ki;
	my @costFunction;
	for(my $i=0; $i < @n; $i++){
		my $edges = &linspace($min, $max, $n[$i]+1);
		$ki = &histc($data, $edges);
		my $stat = Statistics::Descriptive::Full->new();
		pop(@$ki);
		$stat->add_data($ki);
		$costFunction[$i]=(2*$stat->mean()-$stat->sampleVariance()) / $d[$i]**2;
	}
	my $stat = Statistics::Descriptive::Full->new();
	my $minIndex = &findMinIndex(\@costFunction);
	$stat->add_data(\@costFunction);
	#my @edges = &linspace($min,$max,($n[$stat->mindex()]+1));
	return ($n[$minIndex]+1);
}

# The linspace function generates linearly spaced arrays.
# y = linspace(start,end,n) generates an array y of n points linearly spaced between and including start and end. For n < 2, linspace returns end.
sub linspace{
	my($start, $end, $n)=@_;
	if($n < 2){return $end;}
	my $diff=$end-$start;
	my $interval = $diff / ($n-1);
	my @values=($start);
	for(my $i=1;$i<$n;$i++){
		push(@values, $values[$i-1]+$interval);
	}
	return \@values;
}

# n = histc(x,edges) counts the number of values in vector x that fall between the elements in the edges vector
# assumes edges is sorted...
sub histc{
	my($data, $edges) = @_;
	my $numEdges = scalar(@{$edges});
	my @bins = ((0) x $numEdges); # will hold data, should be equla to the number of edges +3
	foreach my $datum(@{$data}){
		if($datum < $edges->[0]){
			#$bins[0]++;
		}
		elsif($datum > $edges->[-1]){
			#$bins[$numEdges+1]++;
		}
		elsif($datum == $edges->[-1]){
			$bins[$numEdges]++;
			#$bins[$numEdges+1]++;
		}
		else{
			for(my $j=1;$j<$numEdges;$j++){
				if($datum < $edges->[$j]){$bins[$j]++;$j=$numEdges;}
			}
		}
	}
	shift(@bins);
	return \@bins;
}

sub findMinIndex{
	my $data=shift;
	my $min = 0;
	for(my $i=0;$i<@{$data};$i++){
		if($data->[$i]<$data->[$min]){$min=$i;}
	}
	return $min;
}

sub log10 {return log($_[0])/log(10);}
sub log2{return log($_[0])/log(2);}


sub setupPublicTempDir{
	my ($base, $user, $q) = @_;
	if(! -d $base ){
		eval{mkdir($base, 0755) || die "Could not create directory $base: $!";};
		if($@){
			&update_error("Unable to generate temporary files!<br/>".&contact_admin(), $q);
			die "Unable to generate temporary files in dr_histogram ($base)!";
		}
	}
	my $userDir = ($base =~ /\/$/) ? $base.$user : "$base/$user";
	if(! -d $userDir ){
		eval{mkdir($userDir, 0755) || die "Could not create directory $userDir: $!";};
		if($@){
			&update_error("Unable to generate temporary files!<br/>".&contact_admin(), $q);
			die "Unable to generate temporary files in dr_histogram ($userDir)!";
		}
	}
	opendir(DIR, "$userDir/");
	my @files = grep {
			-d "$userDir/$_"  # is a directory
			&&	!/^\./	# does not begin with a period
			} readdir(DIR);
	close DIR;
	foreach my $file(@files){
		# remove directories older than 5 days...
		if(-M "$userDir/$file" > 5){
			rmdir "$userDir/$file";
		}
	}

	my $count = scalar(@files);

	my $limit=100;
	COUNTER:while(-d "$userDir/$count"){
		$count++;$limit--;
		if($limit<0){&update_error("Problem creating user directory. Please contact the administrator.",$q); die "Can't find valid image directory!";	}
	}
	$userDir.="/$count/";
	eval{mkdir($userDir, 0755) || die "Could not create directory $userDir: $!";};
	if($@){&update_error("Problem creating user directory. Please contact the administrator.", $q);die $@;	}
	return $userDir;
}
