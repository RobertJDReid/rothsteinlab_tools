#!/usr/bin/perl -w
# ******************************************************
# search autocomplete tool
# ******************************************************

use strict;
use Modules::ScreenAnalysis qw(:sqlOnly);

BEGIN {
	# this code will print errors to a log file
	my $log;
	use CGI::Carp qw(carpout); 
	open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}
use CGI qw(:standard); # web stuff

my $q=new CGI; # initialize new cgi object
print $q->header(-type => "application/json", -charset => "utf-8");

if(!defined $q->param('term') || !defined $q->param('organism')){print '[{"errorMsg":"Error! Bad data set to server."}]'; exit;}
my $organism = lc($q->param('organism'));
my $term = $q->param('term');
if($term =~ /\W/g || $organism =~ /\W/g  ){
	print '[{"errorMsg":"Error! Bad data set to server."}]'; exit;
}
elsif(length($term) > 10 || ($organism ne 'yeast' && $organism ne 'human' )){
	print '[{"errorMsg":"Error! Bad data set to server."}]'; exit;
}
else{
	my $dbh = &connectToMySQL();
	#my $sth = $dbh->prepare( "SELECT `gene`, `orf` FROM `scerevisiae_genes` WHERE `gene` LIKE ? OR `orf` LIKE ?" );
	my $sth;
	if($organism eq 'yeast'){
		$sth = $dbh->prepare( "SELECT `gene`, `orf` FROM `scerevisiae_genes` WHERE `gene` LIKE ? OR `orf` LIKE ?" );
	}
	else{
		$sth = $dbh->prepare( "SELECT `geneName`, `ensemblID`  FROM `hsapien_ensembl_genes` WHERE `ensemblID` LIKE ? OR `geneName` LIKE ?" );
	}
	$sth->execute( $term . '%', $term . '%');
	my $results='';
	while ( my $row = $sth->fetchrow_arrayref() ) { 
		if($row->[0] && $row->[0] ne ""){
			$results .= "{\"label\": \"$row->[0] ($row->[1])\", \"value\": \"$row->[1]\"}, ";
		}
		else{
			$results .= "{\"label\": \"$row->[1]\", \"value\": \"$row->[1]\"}, ";
		}
		#$results.="\"$row->[0]\", ";
	}
	$sth->finish();
	$dbh->disconnect();
	chop($results);chop($results);
	print "[$results]";
}

1;