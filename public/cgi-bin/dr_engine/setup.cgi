#!/usr/bin/perl -w
# ******************************************************
# Data alidation
# Program created on 21 - June - 2008
# Authored by: John Dittmar
# goal of program:
# check integrity of data
# initialize data structures
# raise errors if needed
# ******************************************************

use strict;

BEGIN {
	$|=1;
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
	use CGI qw/-unique_headers :standard/;
	$CGI::HEADERS_ONCE = 1;
}


my $size_limit = 10;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 10 MB limit
use Storable qw(store retrieve); # the storable data persistence module
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use Modules::ScreenAnalysis qw(:validation); # use my module and only load routines in analysis
my $q=new CGI;
my $asset_prefix = &static_asset_path();
my %variables;

unless(&initialize($q, $size_limit)){exit;}
unless(&validateUser(\%variables,$q)){exit;} # validate user

# temporary directory where we will store stuff
# set $variables{'base_upload_dir'} and $variables{'base_dir'}
&getBaseDirInfo(\%variables,'dr',$q);

# generate user specific directories
&directory_setup(\%variables, $q);
#warn "\n $variables{'upload_dir'}";
# set user session
if(!&setSession('dr_engine_setup', \%variables, $q)){
	&update_error("Error setting user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
	die "Could not set user session $! --> $variables{'user'}";
}

#&setupValLoadingPage($q); # setup HTML document
#print $q->hide_progress_bar;

# the variables ash will hold a bunch of static variables while this program is being performed so that they do not have to be passed via forms
# %variables contains: density, control, replicates, justAnalysis, project_id, user, key_choice, lib_screened, pre_screen_library_replicates,
# matingT, gal_leu, sec_gal_leu, final

# verify that the page we came from is correct
my $referer=$ENV{HTTP_REFERER};

print "<html><body>";
## ***************************************************************************
## ************************ GET NORMALIZATION METHOD *************************
## THIS HAS TO BE DONE BEFORE THE KEY FILE IS PROCESSED BECAUSE IF 'controls'
## IS CHOSEN AS THE NORMALIZATION METHOD WE NEED TO FIGURE OUT WHERE THE
## CONTROLS ARE. CONTROLS ARE INDICATED IN THE KEY FILE WITH THE PHASE
## "POSITIVE CONTROL" IN THE ID COLUMN
## ***************************************************************************
#$variables{'normalization_method'} = 'nothing';
$variables{'normalization_method'}=$q->param("normalizationMethod");
#$variables{'normalization_method'} = ($variables{'normalization_method'}) ? 'median' : 'nothing';
if(!$variables{'normalization_method'} || ($variables{'normalization_method'} ne 'krogan' && $variables{'normalization_method'} ne 'median' && $variables{'normalization_method'} ne 'mean' && $variables{'normalization_method'} ne 'nothing' && $variables{'normalization_method'} ne 'controls') ){
	&update_error('There is something wrong with the data normalization method you have selected.<br/>'.&contact_admin().'<br/>', $q);
	die "normalization_method error  (".$variables{'normalization_method'}.")";
}

$variables{'generateHistogram'}=$q->param("generateHistogram");
if( $variables{'generateHistogram'} !~ /^(1|0)$/i){	$variables{'generateHistogram'}=0;	}


## ***************************************************************************
## ***************************** VERIFY KEY FILE *****************************
## ***************************************************************************
&update_message('Verifying key file.', $q);

$variables{'key_choice'}=lc($q->param("key")); # key file we are using for analysis
if($variables{'key_choice'} eq 'custom'){

	$variables{'key_dir'} = $variables{'save_directory'};

	$variables{'id_col'}=lc($q->param("id_col"));
	# check for non-word characters (excluding space)
	if( $variables{'id_col'} =~ m/[^a-zA-Z0-9_'"\,\-\.\?!\(\)\s]+/ ){
		&update_error('There is something wrong with your id column, illegal characters present.<br/>Acceptable characters include a-z, A-Z, 0-9, "_", "-", "?", "!", "(", ")", periods, commas, and double quotes.<br/>'.&contact_admin().'<br/>', $q);
		die "Key file id column error (".$variables{'id_col'}."): $!";
	}
	if($variables{'id_col'} =~ /^(Plate|Row|Column|n\/a)$/i){
		&update_error('Illegal id column.<br/>The id column you select cannot be "plate", "row", "column" or "n/a".<br/>'.&contact_admin().'<br/>', $q);
		die "Key file id column error (".$variables{'id_col'}."): $!";
	}
}
# if key choice eq none there is no key dir
elsif($variables{'key_choice'} ne 'none'){$variables{'key_dir'} = "../../tools/../data/key_file_data";}

# cannot have NO key choice and normalize to controls simultaneously selected!!!
if($variables{'key_choice'} eq 'none' && $variables{'normalization_method'} eq 'controls'){
	&update_error('You have selected "Designated Controls" as your normalization method, but this is impossible since you have also elected to analyze your data without a key file (No KEY FILE has been selected). Please select a different key file option or select a different normalization method to continue.<br/><br/>'.&contact_admin().'<br/>', $q);
	die "key file / normalization_method error  (key choice = $variables{'key_choice'} -- n method = ".$variables{'normalization_method'}.")";
}
$variables{'go_dir'}= "../../tools/../data/key_file_data";
my ($keyinfo,$resthead)=&validateKeyChoice($q, \%variables);
## *****************************************************************************
## **************************** END VERIFY KEY FILE ****************************
## *****************************************************************************


## **************************************************************************
## **************** VERIFY PROPER SCREEN CONDITION VARIABLES ****************
## **************************************************************************

&update_message('Verifying Proper Screen Condition Variables', $q);
$variables{'log_description'}=$q->param("log_description");
# check for non-word characters (excluding space)
if( $variables{'log_description'} =~ m/[^a-zA-Z0-9_'"\,\-\.\?!\(\)\s&%#@\+\:\;~]+/ ){
	&update_error('There is something wrong with your log description, illegal characters present.<br/>Acceptable characters include a-z, A-Z, 0-9, "_", "-", "?", "!",
				 "(", ")", periods, commas, and double quotes.<br/>'.&contact_admin().'<br/>', $q);
	exit(0);
}

$variables{'justAnalysis'}=$q->param("justAnalysis"); #tell us if we are in disconnected data analysis mode or automatic experiment creation mode
# get project_id if required
if($variables{'justAnalysis'} eq "no" || $variables{'justAnalysis'} eq "yes"){
	if($variables{'justAnalysis'} eq "no"){
		$variables{'project_id'} = $q->param("project_id");  # get the project_id that this data will correspond to
		unless($variables{'project_id'}=~/^(0)$|^([1-9][0-9]*)$/){
			#&update_error("Invalid project_id entered. project_id entered = $variables{'project_id'}", $q);
			&update_error(&generic_message(), $q);
			exit(0);
		}
	}
	else{$variables{'project_id'}="";}
}
else{&update_error(&generic_message(), $q); die "Bad value for justAnalysis. $!";}
# don't have a good check to verify that this is valid enter.
# will use the same one I use for log_description
$variables{'control'}=$q->param("control"); # control query
if( $variables{'control'} =~ m/[^a-zA-Z0-9_'"\,\-\.\?!\(\)\s]+/ ){
	&update_error('There is something wrong with the query you entered as a comparer, illegal characters present. Acceptable characters include a-z, A-Z, 0-9, "_", "-",
					"?", "!", "(", ")", periods, commas, and double quotes.<br/>Whatever name you choose <u>MUST</u> match the name you used to identify
				 comparer data in your log file.<br/>'.&contact_admin().'<br/>', $q);
	die "comparer query error (".$variables{'control'}.")";
}
$variables{'originalData'}->{'control'}=$variables{'control'};
$variables{'control'}="\L$variables{'control'}";

$variables{'runGlobalExclusion'}=$q->param("gExclusion");
if( $variables{'runGlobalExclusion'} !~ /^(1|0)$/i){
	&update_error('There is something wrong with value you have selected for "Run Global Exclusion". You may only select "yes" or "no".<br/>'.&contact_admin().'<br/>', $q);
	die "runGlobalExclusion error! (".$variables{'runGlobalExclusion'}.")";
}
$variables{'replicateExclusion'}=$q->param("replicateExclusion");
if( $variables{'replicateExclusion'} !~ /^(1|0)$/i){
	&update_error('There is something wrong with value you have selected for "Run Replicate Exclusion". You may only select "yes" or "no".<br/>'.&contact_admin().'<br/>', $q);
	die "replicate exclusion error  (".$variables{'replicateExclusion'}.")";
}
$variables{'death_threshold_cutoff'}=$q->param("death");
if( $variables{'death_threshold_cutoff'} % 5 != 0 ||  $variables{'death_threshold_cutoff'} < 0 || $variables{'death_threshold_cutoff'} > 95 ){
	&update_error('There is something wrong with the death threshold you have selected.<br/>'.&contact_admin().'<br/>', $q);
	die "death threshold  (".$variables{'death_threshold_cutoff'}.")";
}

$variables{'ignoreZeros'}=$q->param("ignoreZeros");
if( $variables{'ignoreZeros'} !~ /^(1|0)$/i){
	&update_error('There is something wrong with the death threshold you have selected.<br/>'.&contact_admin().'<br/>', $q);
	die "death threshold  (".$variables{'death_threshold_cutoff'}.")";
}

$variables{'death_threshold_cutoff'}= ($variables{'death_threshold_cutoff'} == 0 || $variables{'normalization_method'} eq 'nothing') ? 0 : ($variables{'death_threshold_cutoff'}/100);

$variables{'statsMethod'} = $q->param("statMethod");
if($variables{'statsMethod'} ne 'normal' && $variables{'statsMethod'} ne 't-test' && $variables{'statsMethod'} ne 'Mann-Whitney'){
	&update_error('There is something wrong with the statistical choice you have selected. Valid choices are T-Test,  Normal or Mann-Whitney (mann), you entered'.$variables{'statsMethod'}.'.<br/>'.&contact_admin().'<br/>', $q);
	die "statsMethod error  (".$variables{'statsMethod'}.")";
}

$variables{'bonferroni'}=$q->param("bonferroni");
if( $variables{'bonferroni'} !~ /^(1|0)$/i){
	&update_error('There is something wrong with value you have selected for "bonferroni correction". You may only select "yes" or "no".<br/>'.&contact_admin().'<br/>', $q);
	die "bonferroni correction  (".$variables{'bonferroni'}.")";
}

$variables{'generateHistogram'}=$q->param("generateHistogram");
if( $variables{'generateHistogram'} !~ /^(1|0)$/i){	$variables{'generateHistogram'}=0;	}


# should data be stored in database??
$variables{'store'} = 0;
if(defined $q->param("store")){
	$variables{'store'} = 1;
	$variables{'store_params'}->{'batch_date'}=$q->param("store_params[batch_date]");
	# validate proper numeric month / validate proper numeric day / validate proper numeric year
	# OR  could add the format below to  validate proper word month validate proper numeric day with trailing comma, validate proper numeric year again
	# ((January|February|March|April|May|June|July|August|September|October|November|December)([1-2][0-9]|3[0-1]|0?[1-9]),(19|20)?[0-9][0-9]\z)
	my $reg=qr/((^0?[1-9]|^1[0-2])\/(0?[1-9]|[1-2][0-9]|3[0-1])\/(19|20)?[0-9][0-9]\z)/;
	if($variables{'store_params'}->{'batch_date'} !~ $reg){
		&update_error("Invalid start date format ($variables{'store_params'}->{'batch_date'}). Exiting.<br/>".&contact_admin(), $q);
		die "Invalid start date format ($variables{'store_params'}->{'batch_date'}): (".$variables{'store_params'}->{'batch_date'}."): $!";
	}
	# switch to 'yyyy-mm-dd' format so that days will be sortable.  Sqlite ignores date types and thus this type
	# of transformation must occur...
	$variables{'store_params'}->{'batch_date'}=join '-',substr($variables{'store_params'}->{'batch_date'}, 6),substr($variables{'store_params'}->{'batch_date'}, 0,2),substr($variables{'store_params'}->{'batch_date'}, 3,2);

	$variables{'store_params'}->{'screen_purpose'}=$q->param("store_params[screen_purpose]");
	if(!$variables{'store_params'}->{'screen_purpose'}){
		&update_error("Invalid screen purpose ($variables{'store_params'}->{'screen_purpose'}). Exiting.<br/>".&contact_admin(), $q);
		exit(0);
	}

	$variables{'store_params'}->{'screen_type'}=$q->param("store_params[screen_type]");
	if(!$variables{'store_params'}->{'screen_type'}){
		&update_error("Invalid screen type ($variables{'store_params'}->{'screen_type'}). Exiting.<br/>".&contact_admin(), $q);
		exit(0);
	}

	$variables{'store_params'}->{'donor_strain_used'}=$q->param("store_params[donor_strain_used]");
	if(!$variables{'store_params'}->{'donor_strain_used'}){
		&update_error("Invalid donor strain ($variables{'store_params'}->{'donor_strain_used'}). Exiting.<br/>".&contact_admin(), $q);
		exit(0);
	}

	$variables{'store_params'}->{'incubation_temperature'}=$q->param("store_params[incubation_temperature]");
	if($variables{'store_params'}->{'incubation_temperature'} !~ /^[1-6][0-9]$/ ){
		&update_error("Invalid incubation temperature ($variables{'store_params'}->{'incubation_temperature'}). Exiting.<br/>".&contact_admin(), $q);
		exit(0);
	}

	$variables{'store_params'}->{'pre_screen_library_replicates'}=$q->param("store_params[lreps]");
	if($variables{'store_params'}->{'pre_screen_library_replicates'} !~ /^[1-3]$/ ){
		&update_error("Invalid number of pre-screen library replicated ($variables{'store_params'}->{'pre_screen_library_replicates'}). Exiting.<br/>".&contact_admin(), $q);
		die "Invalid number of pre-screen library replicated : (".$variables{'store_params'}->{'pre_screen_library_replicates'}."): $!";
	}

	$variables{'store_params'}->{'mating_time'}=$q->param("store_params[mating_time]");

	if($variables{'store_params'}->{'mating_time'} !~ /^([3-9]|[1][0-5])$/ ){
		&update_error("Invalid mating time ($variables{'store_params'}->{'mating_time'}). Exiting.<br/>".&contact_admin(), $q);
		die "Invalid mating time: (".$variables{'store_params'}->{'mating_time'}."): $!";
	}

	$variables{'store_params'}->{'first_gal_leu_time'}=$q->param("store_params[first_gl]");
	my %timing_choices=(12=>'1',18=>'1',24=>'1',30=>'1',36=>'1',42=>'1',48=>'1', 'n/a'=>'1');
	if(!defined $timing_choices{$variables{'store_params'}->{'first_gal_leu_time'}}){
		&update_error("Invalid 1st Gal -Leu incubation time ($variables{'store_params'}->{'first_gal_leu_time'}). Exiting.<br/>".&contact_admin(), $q);
		die "Invalid 1st Gal -Leu incubation time: ( 1st = ".$variables{'store_params'}->{'first_gal_leu_time'}." ): $!";
	}

	$variables{'store_params'}->{'second_gal_leu_time'}=$q->param("store_params[second_gl]");
	if(!defined $timing_choices{$variables{'store_params'}->{'second_gal_leu_time'}}){
		&update_error("Invalid 2nd Gal -Leu incubation time ($variables{'store_params'}->{'second_gal_leu_time'}). Exiting.<br/>".&contact_admin(), $q);
		die "Invalid 2nd Gal -Leu incubation time: ( ".$variables{'store_params'}->{'second_gal_leu_time'}." ): $!";
	}

	$variables{'store_params'}->{'final_incubation_time'}=$q->param("store_params[final_incubation]");
	%timing_choices=(24=>'1',30=>'1',36=>'1',42=>'1',48=>'1',54=>'1',60=>'1',66=>'1',72=>'1',78=>'1',84=>'1');
	if(!defined $timing_choices{$variables{'store_params'}->{'final_incubation_time'}}){
		&update_error("Invalid final incubation time ($variables{'store_params'}->{'final_incubation_time'}). Exiting.<br/>".&contact_admin(), $q);
		die "Invalid final incubation time: (".$variables{'store_params'}->{'final_incubation_time'}."): $!";
	}


	my $dbh = &connectToMySQL();
	my $select = 'SELECT `login` from `users` WHERE `id` = ? LIMIT 1';
	my $st = $dbh->prepare($select);
	$st->execute($variables{'user'});
	$variables{'store_params'}->{'performed_by'} = '?';
	while ( my $row = $st->fetchrow_arrayref() ) {
		if(defined $row->[0] && $row->[0] ne ""){
			$variables{'store_params'}->{'performed_by'} = $row->[0];
		}
	}
	$st->finish();
	$select = 'SELECT `name` from `strain_libraries` WHERE `short_name` = ? LIMIT 1';
	$st = $dbh->prepare($select);
	$st->execute($q->param("key"));
	$variables{'store_params'}->{'library_used'} = '?';
	while ( my $row = $st->fetchrow_arrayref() ) {
		if(defined $row->[0] && $row->[0] ne ""){
			$variables{'store_params'}->{'library_used'} = $row->[0];
		}
	}
	$st->finish();
	# $variables{"store_params"}->{'library_used'} = ;

	$dbh->disconnect();

}


$variables{'authenticity_token'} = $q->param('authenticity_token');
## ******************************************************************************
## **************** END VERIFY PROPER SCREEN CONDITION VARIABLES ****************
## ******************************************************************************

&update_message('Processing Log File', $q);

## **************************************************************************
## ********************** BEGIN PROCESSING LOG FILE *************************
## **************************************************************************
# Log files are processed as follows:
# if the loop encounters a new data line that contains one or more commas it considers
# it to be a new file name and processes the file name accordingly.  If the data does not
# contain any commas it is considered raw data and is stored in the appropriate array
# File names are processed as follows:
# 1) the file extension is discarded
# 2) the file name is split by commas into an array
# 3) the individual parts of the filename stored in the array are stored in a data structure
# array index 0 should be equal to the query/plasmid name
# 1 = the plate number (101, 102, etc.)
# 2 = the conditions of the plate (i.e. with or without copper)
# if the filename is constructed so that when it is split the array does not store the appropriate information
# in the appropriate index, the program will not work.
#
# once processed the data is stored in the following structure:
# plate_number->query/plasmid_name->data->condition
#    HASH-------->HASH---------->HASH-------->array

# will also need to validate later that the density calculated matches the key choice entered...

#&update_message("key  = $variables{'key_choice'}", $q);

# control locations is only defined if we are normalized to positive controls
# do the check below to avoid annoying warning messages...

$keyinfo->{'controlLocations'} = '' if(!$keyinfo || !$keyinfo->{'controlLocations'});
my ($plate, $query_condition_combos) = &processLogFile($q, 'review', \%variables, $keyinfo->{'controlLocations'});

# verify that data in log file correlates with data in key file
if($variables{'key_choice'} ne 'none'){
	foreach my $p(keys %{$plate}){
		if($p && !defined $keyinfo->{$p}){
			&update_error("Cannot find plate $p from your log file in your key file.<br/>ALL plate names in your log file MUST be present in your key file.<br/>".&contact_admin(), $q);
			die "Cannot find plate $p from your log file in your key file.";
		}
	}
}

if($variables{'generateHistogram'}){
	&update_message('Data looks good, now generating histograms of your data. This many take a couple of minutes.', $q);
	print <<SCRIPT;
	<form action="$asset_prefix->{'base'}/cgi-bin/dr_engine/histogram.cgi" name="dr_histogram"  id="dr_histogram_form" method = "post" target="result_fake">
	</form>
	<script type="text/javascript">document.getElementById('dr_histogram_form').submit();</script>
	</body></html>
SCRIPT
}
else{
	if($variables{'store'}){
		use Modules::JSON::JSON;
		my $json = JSON->new;
		$json = $json->utf8;
		&update_message('Validating query condition combos.', $q);
		print "<form name='validate_query_and_conditions' target='result_fake'>";
		my $count = 0;
		foreach my $q(sort keys %{$query_condition_combos}){
			foreach my $c(sort keys %{$query_condition_combos->{$q}}){
				print "<input type='hidden' name='query[$count]' value='$q' />";
				print "<input type='hidden' name='condition[$count]' value='$c' />";
				$count++;
			}
		}

		$variables{"store_params"}->{'comparer'} = $variables{'control'};
		$variables{"store_params"}->{'comparer'} =~ s/^0000_//;
		$variables{"store_params"}->{'replicates'} = $variables{'replicates'};
		$variables{"store_params"}->{'density'} = $variables{'density'};

		print '</form><script type="text/javascript">parent.setup_query_condition_validations('.$count.', \''.$json->encode($variables{"store_params"}).'\');</script>';
	}
	else{
		&update_message('All good', $q);
		print '<form action="'.$asset_prefix->{"base"}.'/screen_mill/dr_engine" name="next_plates" method = "post" target="_parent">';
		print '<input type="hidden" name="page_num" value="FIRST_PAGE" />';
		print '<input type="hidden" name="authenticity_token" value="'.$variables{"authenticity_token"}.'" /></form>';
		print '<script type="text/javascript">document.next_plates.submit();</script>'
	}
	print  "</body></html>";
}
