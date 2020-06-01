#!/usr/bin/perl -w

# ******************************************************
# Output selected sets to excel file
# Program created on 15 - September - 2007
# Authored by: John Dittmar
# ******************************************************

BEGIN {
	$|=1;
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}

use strict;
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';

use Spreadsheet::WriteExcel;
use Modules::ScreenAnalysis qw(:fileDL);
use CGI qw/:standard/;
my $size_limit = 1;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 1 MB limit
use Storable qw(retrieve);
my $q=new CGI;
my %variables;
unless(&initialize($q, $size_limit)){exit;}
unless(&validateUser(\%variables,$q)){exit;} # validate user
# retrieve user session data....
my $asset_prefix = &static_asset_path();
# temporary directory where we will store stuff
# set '$variables{base_upload_dir'} and $variables{'base_dir'}
&getBaseDirInfo(\%variables,'sv',$q);
# retreive current working directory (the temporary directory specific to this user where data structures are stored via storable)
my $upload_dir=&setSession('sv_engine', \%variables, $q);


if($q->param){
	print <<EOM;
	<html>
	<head>
		<link href="$asset_prefix->{'stylesheets'}/dr_engine/sv_engine.css" media="screen" rel="Stylesheet" type="text/css" />
	</head>
EOM

	&update_message("Processing Selected Sets...",$q, 'one_extra');
	my $selected_sets=$q->param("selected_sets");
	my ($normalization_values);
	my $variables= eval{retrieve("$upload_dir/variables.dat")};
	if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q, 'one_extra'); die "Serious error from Storable with variables.dat - ud = $upload_dir : $@";}
	elsif(!$variables){&update_error('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q, 'one_extra');  die "I/O error from Storable with variables.dat: $!";}
	if($variables->{'processing_choice'} eq 'log_file'){
		$normalization_values= eval{retrieve("$upload_dir/normalization_values.dat")};
		if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q, 'one_extra'); die "Serious error from Storable with normalization_values.dat: $@";}
		elsif(!$normalization_values){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q, 'one_extra');  die "I/O error from Storable with normalization_values.dat: $!";}
	}
	if($variables->{'save_directory'} ne $upload_dir){
		&update_error('Error finding temporary directory.  '.&try_again_or_contact_admin(), $q, 'one_extra');
		die "The upload directory calculated ($upload_dir) does not match your earlier stored upload directory ($variables->{'save_directory'}).";
	}
	my $dinfo = eval{retrieve("$upload_dir/out_all_shorty.dat")};
	if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q, 'one_extra'); die "Serious error from Storable with out_all.dat: $@";}
	elsif(!$dinfo){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q, 'one_extra'); die "I/O error from Storable with out_all.dat: $!";}
	$selected_sets=&checkSelectedSets($variables, $q, $normalization_values, $dinfo, 'out');
}
