#!/usr/bin/perl -wT

BEGIN {
	my $log;
	use CGI::Carp qw(carpout);
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}
use strict;
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use CGI;
use Storable qw(store retrieve); # to store / retrieve data structures on disk
use Modules::ScreenAnalysis qw(:asset);
my $asset_prefix = &static_asset_path();
my $size_limit = 10;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 10 MB limit
my $q=new CGI; # initialize new cgi object
if ($q->cgi_error()) {
	print $q->cgi_error();
print <<'EOT';
    <p>
    The file you are attempting to upload exceeds the maximum allowable file size.
    <p>
    Please refer to your system administrator
EOT
	print $q->hr, $q->end_html;
	exit 0;
}
print $q->header(); # the "magic line" that tells the WWW that we are an HTML document

#This script compares a list of query ORFs, with a series of ORF lists from
#other screens, (array0.tab, array1.tab etc etc.)
#It produces an array called 'results' That contains the numbers of ORFs in each list and the
#number overlapping the query ORF set.
#The script then uses John's nchoosek routine to calculate if one set is an over- or
#under-represented of the other and returns a p-value (we will call this a rankScore since we assume
# many things about the data and therefore the p-value return may not exactly be accurate).
#The results sorted by rank scores and a table is printed with the results

#some dumbass variables for John's subroutines - don't even think about moving them!
my %nk;
my %LNfact;
my $pi = atan2(1,1)*4; # value needed for Stirling's approximation of factorials
my @fact = (0,0,0.693147180559945,1.791759469228055,3.178053830347946,4.787491742782046,6.579251212010101,8.525161361065415,
							 10.60460290274525,12.80182748008147,15.10441257307552,17.50230784587389,19.98721449566188,22.55216385312342,
							 25.19122118273868,27.89927138384089,30.6718743941422, 33.5050860689909, 36.3954564338402, 39.3398942384233, 42.335625512472, 45.3801470926379); # A list of factorial values of their respective reference nu

# the following line retrieve data needed to properly define ORFs
# define stored data objects
# sgd_orfs.dat == hash with keys = ORF ids, values = array where index 0 = gene name, 1 = alias, 2 = description
my $orf_file ="../../../data/key_file_data/sgd_all.dat";
# sgd_genes.dat == hash with gene names as keys and ORFS as values, if an ORF does not have a gene name then it does not exist in this hash
my $gene_file ="../../../data/key_file_data/sgd_genes.dat";
# sgd_aliases.dat == hash with gene aliases as keys and ORFs as values.
my $alias_file ="../../../data/key_file_data/sgd_aliases.dat";
# load up SGD data files
my $sgd_orfs= eval{retrieve("$orf_file")};
if($@){
	print '<div id="error">Error accessing systematic ORF name information from SGD.</div>';
	die "Serious error from Storable with $orf_file: $@";
}
my $sgd_genes= eval{retrieve("$gene_file")};
if($@){
	print '<div id="error">Error accessing gene name information from SGD.</div>';
	die "Serious error from Storable with $gene_file: $@";
}
my $sgd_aliases= eval{retrieve("$alias_file")};
if($@){
	print '<div id="error">Error accessing information alias information from SGD.</div>';
	die "Serious error from Storable with $alias_file: $@";
}

my $orf_pattern='^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$';

my $myScreenName = $q->param('id1') ? $q->param('id1') : '' ;
my $includeCompetition = (defined $q->param('includeComp') && $q->param('includeComp') eq 'yes') ? $q->param('includeComp') : undef ;
my $includeCostanzo = (defined $q->param('includeCostanzo') && $q->param('includeCostanzo') eq 'yes') ? $q->param('includeCostanzo') : undef ;

#	some of peter's dumbass variables variables
my $pmid_pattern='[0-9]{?}?$';
my $id2 = "Your Screen";

# invoke loadmydata subroutine to load query array
my ($myORFs) = &loadMyData( $q, $myScreenName, $orf_pattern, $sgd_orfs, $sgd_genes, $sgd_aliases );


if($q->param('iFrame')){
	my $data =<<HTL;
	<head>
	<link href='$asset_prefix->{'stylesheets'}/public/tags.css' media='screen' rel='Stylesheet' type='text/css' />
	<link href='$asset_prefix->{'stylesheets'}/screenTroll.css' media='screen' rel='Stylesheet' type='text/css' />
	<script src='$asset_prefix->{'javascripts'}/jquery.min.js' type='text/javascript'></script>
	<script src='$asset_prefix->{'javascripts'}/screenTroll.js' type='text/javascript'></script>
	</head><body>
HTL
	print $data;
}
print  '<br/><fieldset class="screenTrollResults"><legend>ScreenTroll Results</legend>';

print "<h2><span onclick=\"submitScreenTrollAjax( 'downloadOutput','spinner1');\" style=\"color:#1C2089;cursor:pointer;float:left;padding:5px;\">";
print "Click here to download your results as an Excel file </span>";
print '<img src="'.$asset_prefix->{"images"}.'/spinner-big.gif" alt="spinner1" id="spinner1" name="spinner1" style="display:none;" class="loading" />';
print '<div class="ajaxy" id="downloadOutput" style="clear:both;"></div><br style="clear:left" /></h2>';

my $filler = $q->param('id1') ? ": \"".$q->param('id1')."\"" : '';
print '<div id="output">There are '.scalar(keys %{$myORFs}).' ORFs in your dataset',$filler,'.<br />';

my ($overLaps) = &compareScreens($myORFs, $includeCompetition, $includeCostanzo);	#invoke screen subroutine to compare myORFs with database arrays
&generateStats($overLaps, scalar(keys %{$myORFs})); # invoke compare subroutine

print '<strong>The lower the rank score the more significant the representation</strong><br/>';
#print 'Only screens with a rank score <= 0.5 are displayed.<br />';

#	PRINT SORTED TABLE


# overlaps = array of arrays, each array contains:
# name = 0
# authors = 1
# pmid = 2
# # of orfs in stored screen = 3,
# number of common orfs (overlap) between this screen and the ORFs the user entered (actually an array containing the overlapping orf names) = 4
# pvalue, aka rank score, = 5
# over or under represented, aka enrichment, = 6
my $resultTable='';
my $resultSummary='';
my $underRepFlag=0;
my $counter=1;
foreach(@{$overLaps})	{
	# only print results if overlap > 1 or rank score < 0.5
	my $overlap = scalar(@{$_->[4]});
	my $extraClass = '';
	my $underRep='';
	if($_->[5] <= 0.5){
		if($_->[6] =~ /under\-represented/ig){$extraClass='class="underRep"'; $underRepFlag=1;$underRep='*';}
		$resultTable.= "<tr $extraClass><td>$counter</td><td $extraClass>$_->[0]</td><td $extraClass>$_->[3]</td><td $extraClass>$overlap</td><td $extraClass>$_->[5]$underRep</td></tr>";

		$resultSummary.= "<strong>$counter</strong><br/>There are $_->[3] ORFs in the $_->[0] screen.<br />";
		if ($_->[2] =~/$pmid_pattern/) {		# check if there is a pubmid link
			$resultSummary.=  "<a class='ext_link' onclick=\"return popup(this, 'PubMed');\" href=\"http://www.ncbi.nlm.nih.gov/pubmed/$_->[2]\">$_->[1]</a><br />";
		}
		else {$resultSummary.=  "$_->[1]<br />";}
		if($overlap == 1) {$resultSummary.=  "$overlap ORF overlapped with your dataset$filler:<br/>";}
		else {$resultSummary.=  "$overlap ORFs overlapped with your dataset$filler:<br/>";}
		my $orfInfo='';
		foreach my $orf(@{$_->[4]}){
			if($sgd_orfs->{$orf}){
				$orfInfo.= "$orf ($sgd_orfs->{$orf}->[0]), \t";
			}
			else{
				$orfInfo.= "$orf, \t";
			}
		}
		chop($orfInfo);chop($orfInfo);chop($orfInfo);
		$resultSummary.=  "$orfInfo<br/><br/>";
		$counter++;
	}

}
if($resultTable){
	print '<table class="display" border="1" cellspacing="0">';			#print out the data in an html TABLE
	print '<tr><th>#</th><th>Screen</th><th>ORFs in screen</th><th># common hits</th><th>Rank Score</th></tr>';
	print $resultTable;
	print '</table>';

	print '<p><small>A note about the rank score: These values show the probability that the overlap (between your
	set of ORFs and those of a given screen) has occurred by chance. The smaller the rank score the less likely that
	the overlap was coincidence. However, you should bear in mind that some screens include essential genes
	which may not be present in your analysis, or vice versa. Other variables may increase or decrease the
	significance of the overlap.<br/>';
	if($underRepFlag){
		print '<span class="underRep">Rank scores in blue indicate and with an * that there was less overlap between your set of ORFs and those of a given screen than would be expected at random </span>';
	}
	print '</small></p>';
	print "<br><h2>OVERLAP SUMMARY</h2> Gene names in parenthesis, if they exist.<br/><br/>$resultSummary</div>";
}
else{
	print "<div class='notice'>No enrichment!</div>";
}

print '</fieldset><br/></br>';
if($q->param('iFrame')){print "</body>";}
						# save data??
#open(comparison_results, ">comparison_results.tab") or die "comparison_results file cannot be opened. $!";
#print comparison_results "@comparison";

#open(orfhits, ">orfhits.tab") or die "orfhits file cannot be opened. $!";
#print orfhits "@allcommon";

#	This is the end, beautiful friend!

################################# SUBROUTINES ########################################

#	Loads the screen data from the input web page
sub loadMyData {
	my($data, $myScreenName, $orf_pattern, $orfs, $geneNames, $aliases)= @_;
	my @myData=();
	if($q->param('orfsFile')){
		my $DATA = $q->param('orfsFile');
		my $inputFileName = $q->param('orfsFile');
		my $ext = ($inputFileName =~ m/([^.]+)$/)[0];
		if($ext !~ /^txt$/i){
			print "Error! The file you upload must be a .txt file.</br>";
			exit;
		}
		$/ = undef;
		my $data = <$DATA>;
		close $DATA;
		@myData=(split(/\||\r|\015\012|\012|\n|,\s+|,|\s+/ , "\U$data"));
	}
	else{
		my $data =$q->param('orfs');
		@myData=(split(/\||\r|\015\012|\012|\n|,\s+|,|\s+/ , "\U$data"));		# covert everything to uppercase & place the orf list into mydata
	}
	my %myORFs;
	ORF:foreach my $orf(@myData) {				# iterate over @mydata
		$orf = &trimErroneousCharacters($orf);						# invoke trimErroneousCharacters subroutine
		if(!$orf){next ORF;}
		if ($orf =~/$orf_pattern/ && $orfs->{$orf}) {		# check each value is a yeast ORF
			$myORFs{$orf} = $myScreenName;			# create %myORFs of @mydata key=ORF value=id1 (aka name of your query)
		}
		# maybe we have a gene name?
		elsif($geneNames->{$orf}){$myORFs{$geneNames->{$orf}}=$myScreenName;}
		# maybe we have an alias
		elsif($aliases->{$orf}){$myORFs{$aliases->{$orf}}=$myScreenName;}
		else{
			print "Caution \"",$orf,"\" could not be identified as a systematic ORF identifier, gene name or alias and therefore was not included in this analysis.<br />";
		}
		# if ($orf eq "YOR202W") {
		# 	print "<p><strong>Caution: Did you really pick up HIS3 (YOR202W),
		# 	or was this part of the His border? If part of HIS border you should remove it from this list and try again</strong></p>";
		# }

	}
	return (\%myORFs);
}

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
# SCREEN
#	subroutine screen for matches

sub compareScreens{
	my ($myORFs, $ic, $iCos) = @_;	# $ic exisits if the user wants to include competition data, $iCos exists if user wants to include costanzo data
	my $DATA;
	my @overLaps;
	# load up an external files, called "array0.tab", "array1.tab" etc
	my $dir = 'screens';
	opendir D, $dir or die $!;
	my @files = grep {/\.tab$/} readdir D;			# count the array files
	close D;
	if($ic){
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
	}
	if($iCos){
		$dir = 'screens/costanzo';
		opendir D, $dir or die $!;
		$dir = '/costanzo';
		my $file;
		my @cFiles = ();
		while(defined ($file=readdir(D))){
			next unless $file =~ /\.tab$/;			# count the array files
			push(@cFiles, "$dir/$file");
		}
		close D;
		push(@files, @cFiles);
	}
	my $i = scalar(@files);
	if ($i == 0) {
		print '<div id="error">No screens stored on server to compare yours to!</div>';
		die 'I cannot find any screen files in the directory, they should be called "array0.tab" "array1.tab" etc';
	}
 #	warn "$ic";
	my $numberOfScreens=0;
	$dir = 'screens';
	my(@array,@common, $index, %common);
	SFILE:foreach my $screen(@files){					# loop for each file in the database
		@array = ();						# temporary array for the data
		@common = ();					# temporary array for common hits
		%common = ();
		open($DATA, "<$dir/$screen") or die "Data file ($dir/$screen) cannot be opened. $!";
		$/ = &line_break_check( $DATA );	# replace linebreaks, see subroutine
		chomp($array[0]=<$DATA>);
		chomp($array[1]=<$DATA>);
		chomp($array[2]=<$DATA>);
		$numberOfScreens++;
		$index=0;
		my $numberOfOrfs=0;
		while(<$DATA>){						# loop to pull data from each array
			chomp;
			$_ =~ s/^\s+|\s+$//; # get rid of surrounding spaces
			$numberOfOrfs++;
			# search for common genes, if common orf is found (overlap) push into @common
			#warn "\U$_\n";
			if(defined $myORFs->{"\U$_"}){ $common{"\U$_"}=1;	}
		}
		# name = 0, authors = 1, pmid = 2,
		push (@overLaps, [$array[0], $array[1], $array[2], $numberOfOrfs, [keys %common]]);			# push results from these comparisons into results array
	}
	print "These were compared with $numberOfScreens screens on file.<br /><br />";
	return(\@overLaps);
}

###########################################################################
# subroutine to compare the data
sub generateStats{
	# overlaps is an array of arrays each array contains:
	# name = 0, authors = 1, pmid = 2, # of orfs in stored screen = 3,
	# number of common orfs (overlap) between this screen and the ORFs the user entered = 4
	my $overLaps=shift;
	my $num_my_ORFs=shift;
	my ($temp, $name, $num_orf_in_stored_screen, $overlap, $enrichment, @comparison, $result) ;
	for(my $i=0; $i<@{$overLaps}; $i++) {
		$name = $overLaps->[$i]->[0];			# define variables for each line of results
		$num_orf_in_stored_screen = $overLaps->[$i]->[3];
		$overlap = scalar(@{$overLaps->[$i]->[4]});
		($result, $enrichment) = &cum_hyperg_pval_info($overlap,$num_orf_in_stored_screen,$num_my_ORFs,4800);
		# use scientific notation / round score to 5 decimal places
		$result = ($result < 0.001) ? sprintf('%.2e',$result) : sprintf("%.3f",$result);
		# push hypergeometric stats into array (pvalue, aka rank score, = 5, over or under represented, aka enrichment, = 6)
		push(@{$overLaps->[$i]}, ($result, $enrichment));
	}
	@{$overLaps}=sort {	$a->[5] <=> $b->[5] } @{$overLaps}
}


#################################################################
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

################ John's subroutines for n-choose-k ###########################

# &cum_hyperg_pval_info(a,d-c,b,d);
# ...a = good picked, b = total picked, c = total bad, d = total
# steps
# get number of ORFS in each GO category
# get number of significant orfs in each category
# get number of categories

#  (g-a)(a)
#  (b-i)(i)
#  --------
#	   (g)
#	   (b)
#  (  total bad )( total good  )
#  ( bad picked )( good picked )
#  -----------------------------
#	   			(    total   )
#	   			(total picked)
# a =  the number of genes with the GO designation of interest = total number of good guys
# i = the number of genes within our sample having the GO designation of interest= number of good guys we got
# g = g is the total # of genes tested (total number of strains in library) = total number of guys to possibly select
# b = the number of genes in our sample (however many genes are significant) = number of guys drawn
# g-a = total number of bad guys
# b-i = bad guys drawn
# Thus, g and b are constant, while a and i will vary for each GO category.

sub ln_n_choose_k { # Returns the natural log of n choose k
	my ($n, $k) = @_;
	if($nk{"$n-$k"}){return $nk{"$n-$k"};}
	die "improper k: $k, n: $n\n" if $k > $n or $k < 0;
	$k = ($n - $k) if ($n - $k) < $k;
	$LNfact{$n} = &LNfact($n) unless $LNfact{$n};
	$LNfact{$k} = &LNfact($k) unless $LNfact{$k};
	$LNfact{$n-$k} = &LNfact($n-$k) unless $LNfact{$n-$k};
	my $result = $LNfact{$n}-$LNfact{$k}-$LNfact{$n-$k};
	$nk{"$n-$k"}=$result;
	return $result;
}

sub LNfact { # Returns the natural log of the factorial of the value passed to it.  Uses Stirling's approximation for large factorials
	my ($z) = @_;
	my $GoStirling = @fact;
	my $result;
	if ($z >= $GoStirling) {$result = &LNstirling($z); }# print "approx of z ($z) = $result<br />";
	elsif ($z < $GoStirling) {$result = $fact[$z]}
	return $result;
}

sub LNhypergeometric { # Returns the p-value for a particular overlap
	my ($gp, $tg, $tp, $t) = @_;
	#print "2nd -> ($gp, $tg, $tp, $t)<br />";
	return 0 if $t - $tg < $tp - $gp;
	return &ln_n_choose_k($tg, $gp) + &ln_n_choose_k($t - $tg, $tp - $gp) - &ln_n_choose_k($t, $tp);
}

sub LNstirling { # For large values of n, (n/e)n square root(2n pi) < n! < (n/e)n(1 + 1/(12n-1)) square root(2n pi): Stirling's Formula.
	my ($x) = @_;
	my $S = 0.5*(log (2*$pi)) + 0.5*(log $x) + $x*(log $x) - $x;
	my $upadd = log(1 + (1/(12*$x - 1)));
	my $approx = $S + $upadd; # using the upper bound gives more conservative (and accurate) p-values.
	return $approx;
}

sub cum_hyperg_pval_info {
	my ($gp, $tg, $tp, $t) = @_;
#	print "-> $gp, $tg, $tp, $t<br />";
#	die "ERROR: improper input values for hypergeometric distribution.\n" if $gp<0 or $gp>$tg or $gp>$tp or $tg<0 or $tg>$t or $tp<0 or $tp>$t or $t<0;
	if ($tg < $tp){ # setting B to the smaller of the two counts optimizes the p-value calculation
		my $temp = $tp;
		$tp = $tg;
		$tg = $temp;
	}
	#print "1st -> ($gp, $tg, $tp, $t)<br />";
	my ($resultR,$resultL);
	for (my $i = $gp; $i<=$tp; $i++){ # sum from AB to right in distribution
		# exp = e ^ x (inverse of ln)
		$resultR += exp (&LNhypergeometric($i,$tg,$tp,$t));
	}
	for (my $i = 0; $i<=$gp; $i++){ # sum from left to AB in distribution
		$resultL += exp (&LNhypergeometric($i,$tg,$tp,$t));
	}
	# pick the smaller of the two sections of the distribution as it is the one that is in the tail instead of around the mean and a tail...meaning that
	# which ever is smaller tells us if we are over or under represented....
	if ($resultR < $resultL){return ($resultR, "over-represented")}
	else{return ($resultL, "under-represented")}
}




#sub outputResults{#
# # =**************************************
# # = Name: HTML to Excel conversion
# # = Description:Script to convert HTML to Excel spreadsheet, without ever touching Excel. Requires modules HTML::Parser and Spreadsheet::WriteExcel (*updated*)
# # = By: BigCalm
# # =
# # =This code is copyrighted and has= limited warranties.Please see http://www.Planet-Source-Code.com/vb/scripts/ShowCode.asp?txtCodeId=398&lngWId=6=for details.
# # =**************************************
# # Converts a HTML file into Excel format. (badly)
# # Author: Jonathan Daniel
# # Version: 1.0
# # Date: 30/08/02
# # Description:
# #Takes a html file, and converts it into an excel file.
# #	Designed for where I have good control over the html file being produced,
# #	and if your data is not organised into tables (or the tables are nested)
# #	then it'll produce rather unsatisfactory results.
# #
# # Version 1.1, 07/05/03
# # "use strict".
# # Occasionally HTML::Parser would decide it was only going to spit out half
# # of the detail between <td> tags, so I've had to buffer to prevent data loss.
# # Now recognises the th tag, and handles hr better.
# # Space stripping on number columns improved.
# #
# # Version 1.2,
# # Auto-fit of columns attempted with reasonable success.
# #
# # Version 1.3, 20/11/03
# # Improvement of buffering options when not in table. Dates now properly
# # converted, assuming non-US date format. To change to US-dates changes this
# # line: xl_parse_date_init("TZ=GMT","DateFormat=non-US");
# 	use HTML::Parser 3.26 ();
# 	use Spreadsheet::WriteExcel;
# 	use Spreadsheet::WriteExcel::Utility;
# 	# define variables:
# 	my %inside;
# 	my @colarray;
# 	@colarray = (0) x 30;
# 	my $inputfile = "";
# 	my $outputfile = "";
# 	my $maxcol = 0;
# 	$inputfile = $ARGV[0];
# 	$outputfile = $ARGV[0];
#
# 	# Setup spreadsheet
# 	my $workbook = Spreadsheet::WriteExcel->new($outputfile);
# 	my $prevtext = "";
# 	my $buffertext = "";
# 	my $worksheet = $workbook->addworksheet();
# 	$worksheet->hide_gridlines(2);
# 	# Format1 = Bold text
# 	my $format1 = $workbook->addformat();
# 	$format1->set_bold(1);
# 	$format1->set_color('black');
# 	# Format2 = Title Text
# 	my $format2 = $workbook->addformat();
# 	$format2->set_bold(1);
# 	$format2->set_underline;
# 	$format2->set_color('blue');
# 	$format2->set_size(16);
# 	# Format3 = Title Text
# 	my $format3 = $workbook->addformat();
# 	$format3->set_bold(1);
# 	$format3->set_color('blue');
# 	$format3->set_size(14);
# 	# Format4 = Background colour of green
# 	#$format4 = $workbook->addformat();
# 	#$format4->set_color('black');
# 	#$format4->set_fg_color(42);
# 	#$format4->set_pattern(1);
# 	# Format 5 = Integer format
# 	my $format5 = $workbook->addformat();
# 	$format5->set_color('black');
# 	$format5->set_num_format('0');
# 	# Format 6 = Float format
# 	my $format6 = $workbook->addformat();
# 	$format6->set_color('black');
# 	$format6->set_num_format('0.00');
# 	# Format 7 = Date Format
# 	my $format7 = $workbook->addformat();
# 	$format7->set_color('black');
# 	$format7->set_num_format('dd/mm/yy');
# 	# Format 8 = Bold Integers
# 	my $format8 = $workbook->addformat();
# 	$format8->set_color('black');
# 	$format8->set_bold(1);
# 	$format8->set_num_format('0');
# 	# Format 9 = Bold Float format
# 	my $format9 = $workbook->addformat();
# 	$format9->set_color('black');
# 	$format9->set_bold(1);
# 	$format9->set_num_format('0.00');
# 	# Format 10 = Bold Date Format;
# 	my $format10 = $workbook->addformat();
# 	$format10->set_color('black');
# 	$format10->set_bold(1);
# 	$format10->set_num_format('dd/mm/yy');
# 	# Format 11 - for horizontal lines
# 	my $format11 = $workbook->addformat();
# 	$format11->set_color('black');
# 	$format11->set_bottom();
# 	$format11->set_bottom_color('black');
# 	# Format 12 = Date Format
# 	my $format12 = $workbook->addformat();
# 	$format12->set_color('black');
# 	$format12->set_num_format('dd/mm/yyyy');
# 	xl_parse_date_init("TZ=GMT","DateFormat=non-US");
# 	my $intable = 0;
# 	my $row = 0;
# 	my $col = 0;
# 	my $tdcheck = 1;
# 	my $fieldtype = 0;
# 	HTML::Parser->new(api_version => 3,
# 			 handlers=> [start => [\&tag, "tagname,'+1',attr"],
# 					 end=> [\&tag, "tagname, '-1'"],
# 					 text => [\&text, "dtext"],
# 					 ],
# 			 marked_sections => 1,
# 		)->parse_file($inputfile) || die "Can't open file: $!\n";;
# 	# Attempt to auto-fit
# 	my $i = 0;
# 	my $j = 0;
# 	for ($i = 0;$i<$maxcol;$i++)
# 	{
# 		$j += $colarray[$i];
# 		$worksheet->set_column($i,$i,$colarray[$i]);
# 	}
# 	if($j > 100)
# 	{
# 		$worksheet->set_landscape();
# 	}
# 	else
# 	{
# 		$worksheet->set_portrait();
# 	}
# 	$worksheet->set_paper(9);
# 	$worksheet->fit_to_pages(1, 0);
# 	sub tag
# 	{
# 	my($tag, $num, $attr) = @_;
# 	$inside{$tag} += $num;
# 	if(@_ eq "table")
# 	{
# 	$intable++;
# 	}
# 	if(@_ eq "/table")
# 	{
# 	$intable--;
# 	}
# 	if($intable == 0)
# 	{
# 	 $buffertext="";
# 	}
# 	if($tag eq "td")
# 	{
# 		if($tdcheck == 0)
# 		{
# 			$col++;
# 			if( $col > $maxcol)
# 			{
# 				$maxcol = $col;
# 			}
# 			$tdcheck++;
# 		}
# 		else
# 		{
# 			$tdcheck--;
# 		}
# 	}
# 	if($tag eq "br")
# 	{
# 		$row++;
# 	$col=0;
# 	}
# 	if($tag eq "h1" && $num == -1 )
# 	{
# 		$row+=2;
# 	$col=0;
# 	}
# 	if($tag eq "h2" && $num == -1 )
# 	{
# 		$row+=2;
# 	$col=0;
# 	}
# 	if($tag eq "h3" && $num == -1 )
# 	{
# 		$row+=2;
# 	$col=0;
# 	}
# 	if($tag eq "h4" && $num == -1 )
# 	{
# 		$row+=2;
# 	$col=0;
# 	}
# 	if($tag eq "tr")
# 	{
# 		if($col >= 1)
# 		{
# 			$row++;
# 			$col = 0;
# 		}
# 	}
# 	if($tag eq "th")
# 	{
# 		if($col >= 1)
# 		{
# 			$row++;
# 			$col = 0;
# 		}
# 	}
# 	if($tag eq "hr")
# 	{
# 		$row++;
# 	$col = 0;
# 	# apply changes to column using format11
# 		$worksheet->set_row($row, undef, $format11);
# 	$row++;
# 	}
# 	if($tag eq "b")
# 	{
# 		return;
# 	}
# 	if($tag eq "td")
# 	{
# 		$prevtext = "";
# 		if($attr){
# 			 $fieldtype = 0;
# 			 if(exists($attr->{style}))
# 			 {
# 				 if($attr->{style} eq "vnd.ms-excel.numberformat:@")
# 				 {
# 					$fieldtype = 1;
# 				 }
# 				 if($attr->{style} eq "vnd.ms-excel.numberformat:0")
# 				 {
# 					$fieldtype = 2;
# 				 }
# 				 if($attr->{style} eq "vnd.ms-excel.numberformat:0.00")
# 				 {
# 					$fieldtype = 3;
# 				 }
# 				 if($attr->{style} eq "vnd.ms-excel.numberformat:dd/mm/yy")
# 				 {
# 					$fieldtype = 4;
# 				 }
# 				 if($attr->{style} eq "vnd.ms-excel.numberformat:dd/mm/yyyy")
# 				 {
# 					$fieldtype = 5;
# 				 }
# 			 }
# 		}
# 		}
# 	}
# 	sub text
# 	{
# 	return if(substr($_[0],0,9) eq "<!DOCTYPE");
# 	return if $inside{script} || $inside{style} || $inside{title};
# 		return if ($_[0] !~ /\S/);
# 		my $subs = "";
# 		my $test = 0;
# 		my $test2 = 0;
# 	my $date1 = 0;
# 	if ( $inside{table} )
# 	{
# 		$prevtext = $prevtext . $_[0];
# 			if( $inside{b} )
# 			{
# 				if($fieldtype == 0)
# 				{
# 					$worksheet->write($row,$col,$prevtext, $format1);
# 				}
# 				if($fieldtype == 1)
# 				{
# 					$worksheet->write($row,$col,$prevtext, $format1);
# 				}
# 				if($fieldtype == 2)
# 				{
# 					$prevtext =~ s/ //g;
# 					$worksheet->write($row,$col,$prevtext, $format8);
# 				}
# 				if($fieldtype == 3)
# 				{
# 					$prevtext =~ s/ //g;
# 					$worksheet->write($row,$col,$prevtext,$format9);
# 				}
# 				if($fieldtype == 4)
# 				{
# 					$date1 = xl_parse_date($prevtext);
# 					$worksheet->write($row,$col,$date1,$format10);
# 				}
# 				if($fieldtype == 5)
# 				{
# 					$date1 = xl_parse_date($prevtext);
# 					$worksheet->write($row,$col,$date1,$format12);
# 				}
# 				if ($colarray[$col] < length($prevtext))
# 				{
# 					$colarray[$col] = length($prevtext);
# 				}
# 			}
# 			else
# 			{
# 			if($fieldtype == 1)
# 			{
# 					$test = $worksheet->write_string($row,$col,$prevtext);
# 					if($test == -3)
# 					{
# 						print "string too long - ";
# 						$test = $worksheet->write($row,$col,long_string($prevtext));
# 						print $test . " " . long_string($prevtext);
# 					}
# 			}
# 				if($fieldtype == 0)
# 			{
# 					$worksheet->write($row,$col,$prevtext);
# 				}
# 			if($fieldtype == 2)
# 				{
# 					$prevtext =~ s/ //g;
# 					$worksheet->write($row,$col,$prevtext,$format5);
# 				}
# 			if($fieldtype == 3)
# 				{
# 					$prevtext =~ s/ //g;
# 					$worksheet->write($row,$col,$prevtext,$format6);
# 				}
# 			if($fieldtype == 4)
# 				{
# 					$prevtext =~ s/ //g;
# 					$date1 = xl_parse_date($prevtext);
# 					$worksheet->write($row,$col,$date1,$format7);
# 				}
# 			if($fieldtype == 5)
# 				{
# 					$prevtext =~ s/ //g;
# 					$date1 = xl_parse_date($prevtext);
# 					$worksheet->write($row,$col,$date1,$format12);
# 				}
# 				if ($colarray[$col] < length($prevtext))
# 				{
# 					$colarray[$col] = length($prevtext);
# 				}
# 			}
# 	}
# 	else
# 	{
# 			$buffertext = $buffertext . $_[0];
# 			$buffertext =~ s/\n//g;
# 			$subs = $buffertext;
# 			if( $inside{h1} || $inside{h2} || $inside{h3} || $inside{h4} )
# 			{
# 				if( $inside{h1} )
# 				{
# 					$col = 0;
# 					$worksheet->write($row,$col,$subs, $format2);
# 					#$row+=2;
# 				}
# 				if( $inside{h2} )
# 				{
# 					$col=0;
# 					$worksheet->write($row,$col,$subs, $format3);
# 					#$row+=2;
# 				}
# 				if( $inside{h3} || $inside{h4} )
# 				{
# 					$col=0;
# 					$worksheet->write($row,$col,$subs);
# 					#$row+=2;
# 				}
# 			}
# 			else
# 			{
# 				$col = 0;
# 				$worksheet->write($row,$col,$subs);
# 				#$row++;
# 			}
# 	}
# 	}
# 	######################################################################
# 	#
# 	# long_string($str)
# 	#
# 	# Converts long strings into an Excel string concatenation formula.
# 	# The concatenation is inserted between words to improve legibility.
# 	#
# 	# returns: An Excel formula if string is longer than 255 chars.
# 	# The unmodified string otherwise.
# 	#
# 	sub long_string {
# 	my $str= shift;
# 	my $limit = 255;
# 	# Return short strings
# 	return $str if length $str <= $limit;
# 	# Split the line at word boundaries where possible
# 	my @segments = $str =~ m[.{1,$limit}$|.{1,$limit}\b|.{1,$limit}]sog;
# 	# Join the string back together with quotes and Excel concatenation
# 	$str = join '"&"', @segments;
# 	# Add formatting to convert the string to a formula string
# 	return $str = qq(="$str");
# 	}
# }