#!/usr/bin/perl -w

BEGIN {
	# this code will print errors to a log file
	my $log;
	use CGI::Carp qw(carpout); 
	open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log); 
}

use strict;
use Statistics::Hypergeometric qw(cum_hyperg_pval_info); # customized 
use CGI qw(:standard); # web stuff 
my $q=new CGI;
print $q->header(); # the "magic line" that tells the WWW that we are an HTML document

# $gp = good picked
# $tg = total good
# $tp = total picked
# $t = total
my ($gp, $tg, $tp, $t);

if($q->param('gp')){$gp=$q->param('gp');}
else{returnError("Error! Must input a value for 'successes in sample'.");}
# warn &is_numeric($gp);
if(!&is_numeric($gp)){returnError("Error! Must input a number for 'successes in sample'.");}
if($gp < 0){returnError("Error! 'Successes in sample' must be > 0.");}

if($q->param('tg')){$tg=$q->param('tg');}
else{returnError("Error! Must input a value for 'successes in population'.");}
if(!&is_numeric($tg)){returnError("Error! Must input a number for 'successes in population'.");}
if($tg < 0){returnError("Error! 'Successes in population' must be > 0.");}

if($q->param('tp')){$tp=$q->param('tp');}
else{returnError("Error! Must input a value for 'sample size'.");}
if(!&is_numeric($tp)){returnError("Error! Must input a number for 'Sample size'.");}
if($tp < 0){returnError("Error! 'Sample Size' must be > 0.");}

if($q->param('t')){$t=$q->param('t');}
else{returnError("Error! Must input a value for 'total population'.");}
if(!&is_numeric($t)){returnError("Error! Must input a number for 'population size'.");}
if($t < 0){returnError("Error! 'Total population' must be > 0.");}

if($gp>$tg){returnError("Error! 'Successes in population' must be > 'successes in sample'.");}
if($gp>$tp){returnError("Error! 'Sample size' must be >= 'successes in sample'.");}
if($gp>$t){returnError("Error! 'Population size' must be > 'successes in sample'.");}
if($tg>$t){returnError("Error! 'Population size' must be > 'successes in population'.");}
if($tp>$t){returnError("Error! 'Population size' must be > 'sample size'.");}


my ($HD_pval, $resultStr) = &cum_hyperg_pval_info($gp, $tg, $tp, $t);
$HD_pval=&prettyPrintNumber($HD_pval);
print "<table class='borders'><tr><th>P-value</th><th>Under / Over Represented</th></tr><tr><td>$HD_pval</td><td>$resultStr</td></tr></table>";

sub is_numeric{
	no warnings;
	use warnings FATAL => 'numeric';
	return defined eval { $_[ 0] == 0 };
}

sub returnError{
	my ($msg) = @_;
	print '<div id="error">'.$msg.'</div>';
	exit;
}

sub prettyPrintNumber{
	my $number = shift;
	if(!defined $number){return 0;}
	$number = ($number < 0.001 || $number == 0) ? sprintf('%.2e',$number) : sprintf("%.3f",$number);
	return $number;
}
