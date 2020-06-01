#!/usr/bin/perl -w

BEGIN {
	# this code will print errors to a log file
	my $log;
	use CGI::Carp qw(carpout);
	open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}

use strict;
use CGI qw(:standard); # web stuff
my $q=new CGI; # initialize new cgi object
print $q->header(); # the "magic line" that tells the WWW that we are an HTML document

# Checking up on the status of the upload.
my $sessid = $q->param("sessionID");
# Exists?

my $session_file = "../temp/$sessid.session";

if (-f $session_file && $sessid !~ /\W/g) {
	# Read it.
	open (READ, "<$session_file");
	flock(READ, 2);
	my @data = <READ>;
	close (READ);
	my $data = join("\r",@data);
	$data =~ s/\:([0-9]+$)//;
	my $pid = $1 ? $1 : '';
	my $status = `ps -f -p $pid`;
	# warn "data = '$data', pid = '$pid', status = $status";
	# warn $data;
	if($data eq 'finished!' || $data =~/^printToBrowserExit/){
		# warn "printing data -- $data";
		print $data;
		unlink($session_file);
	}
	elsif($pid && $pid =~/[0-9]+/ && $status !~ /$pid/){
		unlink($session_file);
		print "0:printGenericError";
		exit(0);
	}
	else{
		print $data;
		my @data = split(":",$data);
		if($data[1] && $data[1] eq 'combos'){unlink($session_file);}
	}
}
elsif($q->param("killIt") && $q->param("killIt") eq 'true'){
	# delete html files
	unlink(<../temp/*.html>);
}
# file does not exist
else {print "0:";}

exit(0);