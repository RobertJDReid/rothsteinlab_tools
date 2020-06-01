#!/usr/bin/perl -w

#--- ==> temp commented out, if program works fine can delete thesse lines...
# -----------------------------------------------------------------------------------------------
# NEED TO ADD CHECK TO SEE IF FOR EVERY EXPERIMENTAL PLATE THERE IS A CORRESPONDING CONTROL PLATE
# ----
# DOES THE DBI FINSIH COMMAND ALSO COMMIT CHANGES TO DATABASE? <-- NO MEARLY FREES UP MEMORY FOR
# THE HANDLE THAT YOU ARE 'FINISHING'
# -----------------------------------------------------------------------------------------------

use strict;

BEGIN {
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}

use CGI qw/:standard/;
my $size_limit = 1;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 1 MB limit
$|=1;
use DBI;
use Storable qw(store retrieve); # the storable data persistence module
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use Modules::ScreenAnalysis qw(:analysis); # use my module and only load routines in analysis
my $from_address = 'web_tools@rothsteinlab.com';
my $to_address = 'admin@rothsteinlab.com';
my $subject = "Screen Analysis DBI error";
my $q=new CGI; # FYI throws "Use of uninitialized value in substitution (s///) at (eval 9) line 23." warnings

my %variables;
unless(&initialize($q, $size_limit)){die;}
unless(&validateUser(\%variables, $q)){die;} # validate user
my $asset_prefix = &static_asset_path();
# temporary directory where we will store stuff
# set '$variables{base_upload_dir'} and $variables{'base_dir'}
&getBaseDirInfo(\%variables,'dr',$q);
# retreive current working directory (the temporary directory specific to this user where data structures are stored via storable)
my $upload_dir=&setSession('dr_engine', \%variables, $q);

#+++++++++++++++++++++++++++ PRINT HEADERS --> CSS, Javascripts, and formating ++++++++++++++++++
print <<STUFF;
<html><head>
<link href="$asset_prefix->{'stylesheets'}/public/tags.css" media="screen" rel="Stylesheet" type="text/css">
<link href="$asset_prefix->{'stylesheets'}/dr_engine/flash_message.css" media="screen" rel="Stylesheet" type="text/css">
</head><body>
STUFF
#+++++++++++++++++++++++++++++++++ END HEADER INFO ++++++++++++++++++++++++++++++
my $referer=$ENV{HTTP_REFERER};

# the variables hash holds a bunch of static variables while this program is being performed so that they do not have to be passed via forms
# %variables contains: density, control, replicates, justAnalysis, project_id, user, key_choice, lib_screened, pre_screen_reps,
# matingT, gal_leu, sec_gal_leu, final
my $variables= eval{retrieve("$upload_dir/variables.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with variables.dat: $@";}
elsif(! defined $variables){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with variables.dat: $!";}
if($variables->{'save_directory'} ne $upload_dir){
	&update_error("The upload directory calculated does not match your earlier stored upload directory.<br/>Cannot find your data!<br/>".&contact_admin(), $q);
	die "The upload directory calculated ($upload_dir) does not match your earlier stored upload directory ($variables->{'save_directory'}).  Quiting. $!";
}
# ++++++++++++++++++ START RETRIEVING DATA STRUCTURES SAVED TO DISK +++++++++++++++++++++


my $plateData = eval{retrieve("$upload_dir/plate_data.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with plate_data.dat: $@";}
elsif(! defined $plateData){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with plate_data.dat: $!";}
my $normalization_values= eval{retrieve("$upload_dir/normalization_values.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with normalization_values.dat: $@";}
elsif(! defined $normalization_values){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with normalization_values.dat: $!";}
my $dynamicVariables= eval{retrieve("$upload_dir/dynamicVariables.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with dynamicVariables.dat: $@";}
elsif(! defined $dynamicVariables){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with dynamicVariables.dat: $!";}
# ++++++++++++++++++ END RETRIEVING DATA STRUCTURES SAVED TO DISK +++++++++++++++++++++

# use  $dynamicVariables->{'current_page'} to tell use which plates were reviewed on the last page
# --> in this context (before update by $page_num it should be the plate the refered us to the last page
if(defined $dynamicVariables->{'current_page'} && $dynamicVariables->{'current_page'} =~ m/^[0-9]+$/){
	my $start=(($dynamicVariables->{'current_page'}-1)*$variables->{'num_to_display'});
	my $limit = ($#{$variables->{'plate_order'}}+1)<($start+$variables->{'num_to_display'}) ? ($#{$variables->{'plate_order'}}+1) : ($start+$variables->{'num_to_display'});
	for(my $p=$start; $p<$limit; $p++){
		my $plateInfo=${$variables->{'plate_order'}}[$p];
		my $query = $plateInfo->{'query'};
		$query=~ s/^0000_// if $query eq $variables->{'control'}; # remove 0000_ tag used to present controls first
		$dynamicVariables->{'plates_reviewed'}->{"$plateInfo->{'plateNum'},$query,$plateInfo->{'condition'}"}=1;
	}
}

# if using the pull down menu, page_num should == the page we are going to (forward or backwards)
# if using the button page_num is just iterated +1 from it's previous value before form submission
# prior to setting this variable, $dynamicVariables->{"current_page"} should also tell use where we are coming from.
$dynamicVariables->{"current_page"}=$q->param("page_num");
if($dynamicVariables->{"current_page"} !~ m/^([0-9]+|analysis)$/i){
	&update_error(&generic_message()."<br/>".&return_to_dr(),$q);
	die "Current page number is not an integer or is out of bounds.<br/>Page number = $dynamicVariables->{'current_page'}.";
}

&setupDynamicVariables($normalization_values, $dynamicVariables, $q, $variables);

#++++++++++++++++ START COLONY EXCLUSION SET UP +++++++++++++++++++++++++++++++++
# in the previous section of the screen data analysis process users were given to option to
# exclude colonies from statistical consideration.  The following code takes those choices and builds
# a data structure from them.  In this way, later in this program we can use the exists funciton
# to determine if a particular colony is supposed to be excluded from statistical consideration or not.
# the data structure is:
# hash -> hash -> hash -> hash
# gene->condition->plate->plate_position
# plate position is the numberical colony position, counting vertically then horizontally (eg the top left most colony in a 384 formated plate = 0
# and the bottom right most colony = 383)
my $modDivisor = ($variables->{'replicates'} eq '16') ? 4 : 2;

# dataset labels are used when displaying the stat results to the user
my %datasetLabels = ();


foreach my $plate(keys %{$plateData}){
	foreach my $query(keys %{$plateData->{$plate}}){
		foreach my $condition(keys %{$plateData->{$plate}->{$query}}){

			my $plateLabel = $variables->{'originalData'}->{$plate}->{$query}->{$condition};
			$datasetLabels{$query}->{$condition} = {'q'=>$plateLabel->{'query'}, 'c'=>$plateLabel->{'condition'}};

			my $modQuery = $query; # still need this
			$modQuery=~ s/^0000_// if $query eq $variables->{'control'}; # remove 0000_ tag used to present controls first
			if(! defined $condition){$condition='';}
			if(! defined $dynamicVariables->{'plates_reviewed'}->{"$plate,$modQuery,$condition"} || $dynamicVariables->{'plates_reviewed'}->{"$plate,$modQuery,$condition"}!=1){
				my $dead_size=($normalization_values->{$plate}->{$modQuery}->{$condition}*$variables->{'death_threshold_cutoff'});
				if(! defined $condition || $condition eq '' || $condition eq '-'){&update_message("Performing/Finalizing Colony Exclusion - $plate, $modQuery", $q);}
				else{&update_message("Performing/Finalizing Colony Exclusion - $plate, $modQuery, $condition", $q);}
				if(!defined($plateData->{$plate}->{$query}->{$condition}->[0])){
					delete($plateData->{$plate}->{$query}->{$condition});
					$query =~ s/^0000_//
				}

				# if exclusion data structure does not exists for this plate, query, condition combo, then initialize it!
				if(! defined $dynamicVariables->{'excluded_colonies'}->{$plate}->{$modQuery}->{$condition}){
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
						$variables->{'originalData'}->{$plate}->{$query}->{$condition},
						$q
					);
				}
				&checkForReplicateExclusion(
						$dynamicVariables->{'excluded_colonies'}->{$plate}->{$modQuery}->{$condition},
						$variables->{'rows'},
						$variables->{'cols'},
						$dead_size,
						$plateData->{$plate}->{$query}->{$condition}->[0], # reference to an array that contains all the data for a given plate, condition, and gene combo
						$variables->{'replicates'},$variables->{'replicateExclusion'}, $modDivisor, $q);
				$dynamicVariables->{'plates_reviewed'}->{"$plate,$modQuery,$condition"}=1;
			}
		}
	}
}

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

# connect to database
if($variables->{'store'}){
	# $variables->{'store_params'}->{'sql'} is a hash that contains the following keys:
	# 'dbh' → the db handle
	# {'experiment_id'}->{$q}->{$c} === a hash of hashes holding the experiment id for each query condition combo
	$variables->{'store_params'}->{'sql_vars'} =  &mysql_setup_dr_experiment($q, $variables);
}
else{	$variables->{'store_params'}->{'sql_vars'} = 0;}

my($plateStats,
	 $originalData,
	 $excludedData,
	 $plate_summary,
	 $control_plate_details	)=&generateDescriptiveStats(
																								$variables->{'control'}, $plateData, $normalization_values, $variables,
																								$dynamicVariables->{'excluded_plates'}, $dynamicVariables->{'excluded_colonies'},
																							  $q
																							);


&update_message('Crunching Stats - Setting up', $q);
my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
$year += 1900;
$mon++;
$mon = "0$mon" if $mon < 10;
$mday = "0$mday" if $mday < 10;
my $date = "$year-$mon-$mday";
my($stats, $enrichedGO);


# my $variables->{'screen_results_sql_sub'} = sub{ return 0;};
# if($variables->{'store_params'}->{'sql_vars'}){
# 	&mysql_setup_screen_results_statement_handle($variables);
# 	$variables->{'screen_results_sql_sub'} = \&mysql_insert_screen_results;
# }

# if performing normal stats
if($variables->{'statsMethod'} eq 'normal'){
	my ($num_orfs_considered, $log_ratio_sum, $considered_ratios )=&calculateControlExperimentalRatios($plateStats, $variables, $excludedData, $keyInfo, $normalization_values, $q);
	($stats, $enrichedGO)=&crunchNormalStatsAndOutput($plateStats, $variables, $originalData, $keyInfo,
																														$log_ratio_sum, $resthead, $plate_summary,
																														$control_plate_details, $num_orfs_considered,
																														$considered_ratios, $date, $q);
}
# else if performing t-test or mann-whitney
elsif($variables->{'statsMethod'} eq 't-test' || $variables->{'statsMethod'} eq 'Mann-Whitney'){
($enrichedGO)=&calculateOtherStatsAndOutput( $plateStats, $variables, $excludedData, $originalData, $keyInfo, $resthead,
																													$plate_summary, $control_plate_details, $date, $q);
}

# commit changes to db, disconnect
if($variables->{'store'}){
	$variables->{'store_params'}->{'sql_vars'}->{'dbh'}->commit();
	$variables->{'store_params'}->{'sql_vars'}->{'dbh'}->disconnect();
	$variables->{'store_params'}->{'sql_vars'}=();
}

&update_message('Done! Redirecting to Results Page.', $q);

#*************** start storing data structures in $variables->{'save_directory'} ********************
#  only save ones that may have changed from previous page
my $frozen=eval {store($variables, "$variables->{'save_directory'}/variables.dat")};
if($@){ warn 'Serious error from Storable, storing %variables: '.$@;}
$frozen=eval {store($dynamicVariables, "$variables->{'save_directory'}/dynamicVariables.dat")};
if($@){ warn 'Serious error from Storable, storing %dynamicVariables: '.$@;}
#*************** end storing data structures in $variables{'save_directory'} ********************

# &deleteSession($variables->{'user_directory'});#  delete everything in $variables->{'user_directory'}
# if($sqlite_info->{'log_message'}){
# 	&send_results($sqlite_info->{'log_message'},$from_address,$subject,$to_address);
# 	warn $sqlite_info->{'log_message'};
# }
#
my $statTable = &createStatsTable($stats,\%datasetLabels);

my @temp = split("/",$variables->{'save_directory'});
$variables->{'id_col'} = (defined ($variables->{'id_col'})) ? $variables->{'id_col'} : 'n/a';
print <<FORM;
<form name="results" action="$asset_prefix->{'base'}/screen_mill/dr_results" method="post" enctype="multipart/form-data" target="_parent">
	<input type="hidden" name="stats" value="$statTable">
	<input type="hidden" name="id_col" value="$variables->{'id_col'}">
	<input type="hidden" name="enrichedGO" value="$enrichedGO">
	<input type="hidden" name="sessionID" value="$temp[$#temp]">
	<input type="hidden" name="date" value="$date">
	<input type="hidden" name="authenticity_token" value="$variables->{'authenticity_token'}" />
</form>
<script language="javascript" type="text/javascript">
document.results.submit();
</script>
<div id="fullyLoaded"></div>
FORM


print '
</body></html>
';
exit(0);
sub createStatsTable{
	my ($stats,$labels) = @_;
	if(! defined $stats){return '';}
	my $table = "<table><tr><th>Query</th><th>Condition</th><th>Standard Deviation</th><th>P-Value Threshold</th></tr>";
	foreach my $q(keys %{$stats}){
		foreach my $c(keys %{$stats->{$q}}){
			my $condition1 = ($labels->{$q}->{$c}->{'c'} && $labels->{$q}->{$c}->{'c'} ne '' && $labels->{$q}->{$c}->{'c'} ne '-') ? $labels->{$q}->{$c}->{'c'} : '';
			$table.="<tr><td>".($labels->{$q}->{$c}->{'q'})."</td><td>$condition1</td><td>$stats->{$q}->{$c}->[0]</td><td>$stats->{$q}->{$c}->[2]</td></tr>";
		}
	}
	return "$table</table>";
}