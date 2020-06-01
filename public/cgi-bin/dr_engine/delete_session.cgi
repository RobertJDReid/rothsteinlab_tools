#!/usr/bin/perl -w

BEGIN {
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}
use strict;
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use Modules::ScreenAnalysis qw(:sessions); # use my module and only load routines in sessions
use CGI qw/:standard/;
my $size_limit = 1;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 1 MB limit
use File::Find; # needed for finddepth
my $q  = CGI->new(); # start a new CGI instance

# get directory we are trying to delete
my %variables;
unless(&initialize($q, $size_limit)){exit;}
unless(&validateUser(\%variables,$q)){exit;} # validate user
my $directory = $q->param('directory');
print $q->header(); # print out header stuff...this is required
if($directory !~ m/\w/){
	&update_error(&generic_message()."<br/>",$q);
	die "Bad restore session directory --> $directory, user = $variables{'user'}";
}
my $delete_dir='../../../data/user_data/dr/user_directory/'.$variables{'user'}.'/'.$directory;

# ************************* start deleting everything in $delete_dir *****************************
eval{
	opendir (DH,"$delete_dir");
	if(! -d $delete_dir){		print "<script>alert('Delete NOT successful.')</script>";	exit(0);}
	while (my $file = readdir DH) {		unlink "$delete_dir/$file";	}
	rmdir "$delete_dir";
};
if($@){
	# use Data::Dumper;
	# warn Dumper($@);
	print "<script>alert('Delete NOT successful.')</script>";
}
else{
	print "<script>alert('Delete Successful.')</script>";
}
