#!/usr/bin/perl -w

BEGIN {
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);

}
use Storable;
use CGI qw(:standard);
use strict;
use lib '/home/rothstei/perl5/lib/perl5';
use Modules::ScreenAnalysis qw(:asset);
my $q=new CGI;
print $q->header(); # the "magic line" that tells the WWW that we are an HTML document
my $asset_prefix = &static_asset_path();
#	Define variables
my ($genes);
# define stored data objects
# sgd_orfs.dat == hash with keys = ORF ids, values = array where index 0 = gene name, 1 = alias, 2 = description
my $orf_file ="../../data/key_file_data/sgd_all.dat";
# sgd_genes.dat == hash with gene names as keys and ORFS as values, if an ORF does not have a gene name then it does not exist in this hash
my $gene_file ="../../data/key_file_data/sgd_genes.dat";
# sgd_aliases.dat == hash with gene aliases as keys and ORFs as values.
my $alias_file ="../../data/key_file_data/sgd_aliases.dat";
# If a ORF has several aliases they are listed separately.
# If an ORF does not have an alias then it does not exist in this hash
my $orf_pattern='^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$';
#	enough variables already

# opendir(DIR, "../tools/../data/key_file_data");
# my @files = readdir(DIR);
# closedir(DIR);
#
# foreach my $file (@files) {
#    warn "$file\n";
# }
print '<br/><br/><fieldset><legend>Conversion Results</legend>';
my $maintainOrder = 0;
if($q->param('maintainOrder') && $q->param('maintainOrder') =~ /^yes$/i){	$maintainOrder=1;}
if($q->param('ids')){	$genes = &loadmydata($q->param('ids'),$maintainOrder);}# subroutine to load up reference file}
else{
	# show error message, exit
	print '<div id="error">ERROR! NO DATA ENTERED!!!!</div>';
}
# load up SGD data files
my %sgd_orfs= eval{%{retrieve("$orf_file")}};
if($@){
	print '<div id="error">Error accessing sytematic ORF name information from SGD</div>';
	die "Serious error from Storable with $orf_file: $@";
}
my %sgd_genes= eval{%{retrieve("$gene_file")}};
if($@){
	print '<div id="error">Error accessing gene name information from SGD</div>';
	die "Serious error from Storable with $gene_file: $@";
}
my %sgd_aliases= eval{%{retrieve("$alias_file")}};
if($@){
	print '<div id="error">Error accessing information alias information SGD</div>';
	die "Serious error from Storable with $alias_file: $@";
}

# subroutine to search for matches
my ($list, $rejects) = &search($genes, \%sgd_orfs, \%sgd_genes, \%sgd_aliases);
my $count = scalar(@{$list});
if ( scalar(@{$rejects}) > 0 ) {
	print "<h2>The following IDs could not be identified:</h2><ul>";
	foreach(@{$rejects}){
		print "<li>$_</li>";
	}
	print "</ul>";
}

#	PRINT TABLE
my $orfs='';
print '<div style="clear:left;float:left;"><table class="display" border="1" cellspacing="0">';
print '<tr><th>#</th><th>Input</th><th>Systematic name</th><th>Gene Name</th><th>Description</th></tr>';
my $i=1;
foreach(@{$list}){
	$orfs.="$_->[1]|";
	print "<tr><td>$i</td><td>$_->[0]</td><td>$_->[1]</td><td>$_->[2]</td><td class='left'>$_->[3]</td></tr>";
	$i++;
}
print '</table>';
chop($orfs);
print <<OUTPUT;
	<h4>Asterisks indicates an alias was used to derive the systematic name.</h4><br/><br/><hr/><br/><br/>
	<h3>Push this data into <em>ScreenTroll</em>?</h3>
	</div>
	<form id='comparison' name='comparison' action='' style="clear:left;float:left;">
	<input type="hidden" name="orfs" id="orfs" value="$orfs" />
		<div style="clear:left;float:left">
	 	<label for="id1"><i>Optional:</i> Enter a name for this set of data (e.g. Kryptonite Sensitive Mutants)</label>
		<input type="text" name="id1" id="id1" class="formInputText" />
		</div>
		<div style="float:left;clear:left;margin-left:5px;">
			<input type="checkbox" style="display:inline;margin-bottom:10px;" id="includeComp" name="includeComp" value="yes" />
			<label  for="includeComp" style="padding-left:5px;margin-top:-5px;display:inline;color:black;">Check this box to include competition based screens.</label>
			<br/>
			<input type="checkbox" style="display:inline;margin-bottom:10px;" id="includeCostanzo" name="includeCostanzo" value="yes" />
			<label for="includeCostanzo" style="padding-left:5px;margin-top:-5px;display:inline;color:black;">Check this box to include data from Costanzo et. al. Science. 2010. SGA screens.</label>
		</div>
		<div style="clear:left;float:left;">
		<p><input type="button" style="margin-left:0px;float:left;" value="&raquo; Submit &laquo;" class="commit" id='pushtoST' onclick='validate_form("comparison");' /></p>
		</div>
		<div id="loading1" class="loading" style="display:none;">
			<img src="$asset_prefix->{'images'}/spinner-big.gif" alt="spinner" id="spinner1" name="spinner" /><div style="padding:5px;float
			:left;">Loading...</div>
		</div>
		<br stlye="clear:left;" />
	</form>
</fieldset><br/><br/>
OUTPUT

####################################################################################
###								SUBROUTINES										####
#						LOADMYDATA open input from webpage
sub loadmydata{
	my $dupList='';
	my %genes;
	my @genes;
	my ($list, $maintainOrder) = @_;
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
		print "<h3>Note that there were duplicates in your input. If 'maintain input order' was checked, these were NOT removed from the output below.</h3><ul><li>$dupList</li></ul>";
	}
	if($maintainOrder){	return \@genes;	}
	@genes = sort keys %genes;
	return \@genes;
}

#	SEARCH for matches in the SGD data structures
sub search{
	my $genes=shift; # ref to hash
	my $sgd_orfs=shift; # ref to hash
	my $sgd_genes=shift; # ref to hash
	my $sgd_aliases=shift; # ref to hash
	my (@temp, $temp_gene,$temp_desc, @rejects, @list);
	#	search for names
	$count = 0;
	foreach my $identifier(@{$genes}){ # search for common genes
		$count++;
		if($sgd_orfs->{$identifier}){
			push (@list, [$identifier, $identifier, $sgd_orfs->{$identifier}->[0], $sgd_orfs->{$identifier}->[2]]);		# if ORF is already systematic push it to @list array
		}
		elsif($sgd_genes->{$identifier}) {	# else if it is a gene name, push it to list
			push (@list, [$identifier, $sgd_genes->{$identifier}, $identifier, $sgd_orfs->{$sgd_genes->{$identifier}}->[2]]);
		}
		elsif($sgd_aliases->{$identifier}) { # else if it is a alias of a name, push it to list
			@temp = split /\|/, $sgd_aliases->{$identifier};
			if(scalar(@temp)>1){
				($temp_gene, $temp_desc)=('<ul>', '<ul>');
				foreach my $orf(@temp){
					$temp_gene.="<li>$sgd_orfs->{$orf}->[0]</li>";
					$temp_desc.="<li>$sgd_orfs->{$orf}->[2]<li>";
				}
				$temp_gene.='</ul>';
				$temp_desc.='</ul>';
				push (@list, ["$identifier*", "<ul><li>".join('</li><li>',@temp)."</li></ul>", $temp_gene, $temp_desc]);
			}
			else{
				push (@list, ["$identifier*", $sgd_aliases->{$identifier}, $sgd_orfs->{$sgd_aliases->{$identifier}}->[0], $sgd_orfs->{$sgd_aliases->{$identifier}}->[2]]);
			}
		}
		else{
			push (@list, ["<span style='font-color:red;'>$identifier</span>", "n/a", "n/a", "n/a"]);
			push (@rejects, "$identifier ($count)\n");
		}
	}
	return(\@list, \@rejects);
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
