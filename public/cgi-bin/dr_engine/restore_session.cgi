#!/usr/bin/perl -w

BEGIN {
	$|=1;
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
	use CGI qw/-unique_headers :standard/;
	$CGI::HEADERS_ONCE = 1;
}


use strict;
my $size_limit = 1;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 1 MB limit
use Storable qw(store retrieve); # the storable data persistence module
use File::Find; # needed for finddepth
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use Modules::ScreenAnalysis qw(:sessions); # use my module and only load routines in sessions
my $q=new CGI;
my %variables;
unless(&initialize($q, $size_limit)){exit;}
unless(&validateUser(\%variables,$q)){exit;}
my $asset_prefix = &static_asset_path();
my $directory = $q->param('directory'); # get directory we are trying to restore
my $restore_dir='../..'.$asset_prefix->{'base'}.'/../data/user_data/dr/user_directory/'.$variables{'user'}.'/'.$directory;
# warn $restore_dir;
if($directory !~ m/\w/ || !(-d $restore_dir)){
	print $q->header(); # the "magic line" that tells the WWW that we are an HTML document
	&update_error(&generic_message(),$q);
	die "Bad restore session directory --> $directory, user = $variables{'user'} -- restore_dir = $restore_dir";
}


my $user = $variables{'user'};
my $variables= eval{retrieve("$restore_dir/variables.dat")};
$variables->{'user'} = $user;
if($@ || !$variables){
	print $q->header(); # the "magic line" that tells the WWW that we are an HTML document
	&update_error(&generic_message(),$q);
	die "Serious error from Storable with variables.dat: $@";
}
if($restore_dir ne $variables->{'save_directory'}) # redundant check to make sure we are ok...
{
	print $q->header(); # the "magic line" that tells the WWW that we are an HTML document
	&update_error(&generic_message(),$q);
	die "Error validating properly formatted restore directory(restore_dir = $restore_dir, stored save dir = $variables->{'save_directory'})";
}


&getBaseDirInfo($variables,'dr',$q);
# retrieve current working directory (the temporary directory specific to this user where data structures are stored via storable)
if(!&setSession('dr_engine_setup', $variables, $q)){
	print $q->header();
	&update_error("Error setting user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
	die "Could not set user session $! --> $variables->{'upload_dir'}";
}
my $results='document.restore_this_session.submit()';
#*************** start printing out form to direct user to dr_engine/main.cgi ********************
print '
	<html><body>
	<form action="'.$asset_prefix->{"base"}.'/screen_mill/dr_engine"  name="restore_this_session" id="restore_this_session" method = "post" target="_parent">
	<input type="hidden" name="page_num" value=1>
	<input type="hidden" name="authenticity_token" value="'.$q->param("at").'">
	</form>
	<script type="text/javascript">
	'.$results.'
	</script>
	</body>
	</html>
	';
#*************** end printing out form to direct user to dr_engine/main.cgi ********************
