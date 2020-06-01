#!/usr/bin/perl -w
# ******************************************************
# Orthology search tool
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
my $limit = 500;
my $q=new CGI; # initialize new cgi object
print $q->header(-type => "application/json", -charset => "utf-8");
my @output = ();
if(!defined $q->param('genes')){print '{"error":"Error! Bad data set to server."}'; exit(0);}
my ($genesArray,$genesHash) = &loadMyData($q->param('genes'), \@output);
if(@{$genesArray} > $limit){print '{"error":"Error! No more than '.$limit.' gene names may be entered at a time."}'; exit(0);}
elsif(@{$genesArray} < 1){print '{"error":"Error! You must enter at least one gene name."}'; exit(0);}
my $dbh = &connectToMySQL();
 # $dbh->{TraceLevel} = 2;

my $sqlFront = "SELECT `humanEnsemblID`, `humanGeneName`, `scerevisiae_genes`.`gene` as 'yeastGene', `yeastOrf`, `percentIdentityWithRespectToQueryGene`, `percentIdentityWithRespectToYeastGene`, ";
$sqlFront .= "`homologyType`, `source` FROM `scerevisiae_hsapien_orthologs` ";
$sqlFront .="INNER JOIN `scerevisiae_genes` ON `scerevisiae_genes`.orf = `scerevisiae_hsapien_orthologs`.yeastOrf ";
$sqlFront .= "WHERE `approved` = 1 AND ";
my $sth = $dbh->prepare( "$sqlFront `humanEnsemblID` IN (". join(', ', ('?') x @{$genesArray}) . ")");
$sth->execute( @{$genesArray});
#warn $sth->rows(); # number of orthologs returned
my $results='<h2>Orthologs Found:</h2><table id=\'orthologs\'><thead><th>Human Ensembl ID</th><th>Human Gene</th><th>Yeast Gene</th><th>Yeast ORF</th><th>% identity to query</th><th>% identify to yeast</th><th>';
$results.="Homology</th><th>Source</th></thead><tbody>";
my $goodCount=0;
# foundCombos yeast == hash whose keys == "human gene name-yeast gene name"
# will use this to avoid duplicates in the final output.
my %foundCombos;
while ( my $row = $sth->fetchrow_arrayref() ) { 
	delete($genesHash->{$row->[0]}) if defined $genesHash->{$row->[0]};
	$foundCombos{"$row->[1]-$row->[3]"}=1;
	$goodCount++;
	$results.="<tr><td>".join("</td><td>", map { defined() ? $_ : "" } @{$row})."</td></tr>";
	# delete from hash here
}

my @leftOvers = keys %{$genesHash};

if(scalar(@leftOvers) > 0){
	$sth = $dbh->prepare( "$sqlFront `yeastOrf` IN (". join(', ', ('?') x  keys %{$genesHash}). ")");
	$sth->execute( keys %{$genesHash});
	while ( my $row = $sth->fetchrow_arrayref() ) { 
		delete($genesHash->{$row->[3]}) if defined $genesHash->{$row->[3]};
		if(!defined$foundCombos{"$row->[1]-$row->[3]"}){
			$foundCombos{"$row->[1]-$row->[3]"}=1;
			$goodCount++;
			$results.="<tr><td>".join("</td><td>", map { defined() ? $_ : "" } @{$row})."</td></tr>";
		}
	}

	@leftOvers = keys %{$genesHash};
	if(@leftOvers > 0){
		$sth = $dbh->prepare( "$sqlFront `humanGeneName` IN (". join(', ', ('?') x  @leftOvers) . ")");
		$sth->execute( @leftOvers);
		while ( my $row = $sth->fetchrow_arrayref() ) { 
			delete($genesHash->{$row->[1]}) if defined $genesHash->{$row->[1]};
			if(!defined$foundCombos{"$row->[1]-$row->[3]"}){
				$foundCombos{"$row->[1]-$row->[3]"}=1;
				$goodCount++;
				$results.="<tr><td>".join("</td><td>", map { defined() ? $_ : "" } @{$row})."</td></tr>";
			}
		}

		# find yeast ORFs of genes
		$sth = $dbh->prepare(  "SELECT `gene`, `orf` FROM `scerevisiae_genes` WHERE `gene` IN (". join(', ', ('?') x @leftOvers) . ")");
		$sth->execute( @leftOvers);
		my %orfs = ();
		while ( my $row = $sth->fetchrow_arrayref() ) {	$orfs{$row->[1]}=$row->[0];}
		if(keys %orfs>0){
			$sth = $dbh->prepare( "$sqlFront `yeastOrf` IN (". join(', ', ('?') x  keys %orfs) . ")");
			$sth->execute( keys %orfs);
			while ( my $row = $sth->fetchrow_arrayref() ) { 
				delete($genesHash->{$orfs{$row->[3]}}) if defined $genesHash->{$orfs{$row->[3]}};
				if(!defined$foundCombos{"$row->[1]-$row->[3]"}){
					$foundCombos{"$row->[1]-$row->[3]"}=1;
					$goodCount++;
					$results.="<tr><td>".join("</td><td>", map { defined() ? $_ : "" } @{$row})."</td></tr>";
				}
			}
		}
	}
}
$sth->finish();
$dbh->disconnect();
$results.="</tbody></table>";
push(@output, '"results":"'.$results.'"');
if(keys %{$genesHash} > 0){
	push(@output, '"badGenes":"<br/><b>Could not find orthologs for the following inputs:</b><br/>'.join(", ",keys %{$genesHash}).'<br/><br/>"');
}
push(@output, '"goodCount":"'.$goodCount.'"');
$results = "{".join(',',@output)."}";
print $results;
exit(0);




####################################################################################
###								SUBROUTINES										####
#						LOADMYDATA open input from webpage
sub loadMyData{
	my $dupList='';
	my %genes;
	my @genes;
	my ($list,$output) = @_;
	my $position = 1;
	my %dups;
	# put orf list into array, covert to uppercase, iterate over list
	GUY:foreach my $guy((split(/\r|\015\012|\012|\n|,\s+|\s+/ , "\U$list"))) {
		chomp($guy);
		$guy=&trimErroneousCharacters($guy);						# invoke trim subroutine
		if(!$guy){next GUY;}
		if($genes{$guy}){$dups{$guy}=1;} # if this gene is a duplicate, make a note of it
		$genes{$guy} = $position;# create hash %genes of mydata key=gene/orf, value=1
		push(@genes,$guy);
		$position++;
	}
	if(scalar keys %dups > 0) {
		$dupList = join(", ",sort keys %dups);
		push(@{$output}, '"msg":"<br/><b>Note the following items appear more than once in your gene list:</b><ul><li>'.$dupList.'</li></ul>"');
	}
	return (\@genes,\%genes);
	
}


####################################################################################
#								TRIM
# subroutine to trim off the white space, carriage returns, pipes, and commas from both ends of each string or array
sub trimErroneousCharacters {
	my $guy = shift;
	my $type = (ref(\$guy) eq 'REF') ? ref($guy) : ref(\$guy);
	if ( $type eq 'ARRAY') { # Reference to an array
		foreach(@{$guy}) {  #for each element in @{$guy}
			s/^\s+|\s+|\|+|\r+|\015\012+|\012+|\n+|,+$//g;  #replace one or more spaces at the end of it with nothing (deleting them)
		}
	}
	elsif ( $type eq 'SCALAR' ) { # Reference to a scalar
		$guy=~ s/^\s+|\s+$//g;
	}
	return $guy;
}

1;