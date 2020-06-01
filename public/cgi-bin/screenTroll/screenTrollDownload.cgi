#!/usr/bin/perl -w

BEGIN {
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use CGI qw(:standard);
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );   # imports
use Modules::ScreenAnalysis qw(:asset);
my $q=new CGI;
print $q->header(); # the "magic line" that tells the WWW that we are an HTML document
#This script makes a tab delimited file of the ScreenTroll database
my $asset_prefix = &static_asset_path();
my $dir = 'screens';

opendir D, $dir or die $!;
my @files = grep {/\.tab$/} readdir D;			# count the array files
close D;
$dir = 'screens/competition';
opendir D, $dir or die $!;
$dir = '/competition';
my $file;
my @cFiles = ();
while(defined ($file=readdir(D))){
	next unless $file =~ /\.tab$/;			# count the array files
	push(@cFiles, "$dir/$file");
}
close D;
push(@files, @cFiles);
$dir = 'screens/costanzo';
opendir D, $dir or die $!;
$dir = '/costanzo';
$file=undef;
@cFiles = ();
while(defined ($file=readdir(D))){
	next unless $file =~ /\.tab$/;			# count the array files
	push(@cFiles, "$dir/$file");
}
close D;
push(@files, @cFiles);
my $i = scalar(@files);
if ($i == 0) {print '<div id="error">No data found!</div>'; die "I can't find any screen files in the directory, they should be called \"array0.tab\" \"array1.tab\" etc";}
else {
	#				print out how many arrays are in the database
	#print "There are ", $i, " arrays in your folder.\n";
}
$dir = 'screens';
my $obj = Archive::Zip->new();   # new instance
foreach my $screen(@files){		# loop for each array in the database
  $obj->addFile("$dir/$screen");   # add files
}


if ($obj->writeToFileNamed('../../screens.zip') != AZ_OK) {  # write to disk
    print '<div id="error">Error in archive creation!</div>';die 'write error';
}
print '<a href="'.$asset_prefix->{"base"}.'/screens.zip" id="screensDownloadLink" style="padding-left:10px"> --> If download does not start immediately click here.</a>';
#
################# a subroutine to replace the line breaks #######################

# line_break_check receives a file handle as its input and returns
# the new line character used in the file handle

sub line_break_check{
	my $file = shift;
	local $/ = \1000; 								# read first 1000 bytes
	local $_ = <$file>; 							# read
	my ($newline) = /(\015\012?)/ ? $1 : "\012"; 	# Default to unix.
	seek $file,0,0; 								# rewind to start of file
	return ($newline);
}

#################################################################################
#subroutine to trim off the white space from both ends of each string
sub trim {
	$_[0]=~ s/^\s+//;
	$_[0]=~ s/\s+$//;
	return;
}
################################################################################