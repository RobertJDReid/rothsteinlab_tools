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
use Modules::ScreenAnalysis qw(:sqlOnly);
my $asset_prefix = &static_asset_path();
use Storable qw(store retrieve); # to store / retreive data structures on disk
my $size_limit = 10;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 10 MB limit
my $q=new CGI; # initialize new cgi object
if ($q->cgi_error()) {
	print $q->cgi_error();
	print '<p>The file you are attempting to upload exceeds the maximum allowable file size.</p>';
	print '<p>Please refer to your system administrator.</p>';
	print $q->hr, $q->end_html;
	exit 0;
}
print $q->header(); # the "magic line" that tells the WWW that we are an HTML document


my $rootDir = '../temp/pullORFsDir';
my $fileName = 'newKeyFile.tab';


# the following line retrieve data needed to properly define ORFs
# define stored data objects
# sgd_orfs.dat == hash with keys = ORF ids, values = array where index 0 = gene name, 1 = alias, 2 = description
my $orf_file = "../../data/key_file_data/sgd_all.dat";
# sgd_genes.dat == hash with gene names as keys and ORFS as values, if an ORF does not have a gene name then it does not exist in this hash
my $gene_file = "../../data/key_file_data/sgd_genes.dat";
# sgd_aliases.dat == hash with gene aliases as keys and ORFs as values.
my $alias_file = "../../data/key_file_data/sgd_aliases.dat";
# load up SGD data files
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

# invoke loadmydata subroutine to load query array
my ($myORFs) = &loadMyData( $q, $orf_pattern, $sgd_orfs, $sgd_genes, $sgd_aliases );
my $saveDir = &setuptOutputDirectory($rootDir,$q);

my $data =<<HTL;
	<head>
	<link href='$asset_prefix->{'javascripts'}/public/tags.css' media='screen' rel='Stylesheet' type='text/css' />
	<script src='$asset_prefix->{'stylesheets'}/jquery.min.js' type='text/javascript'></script>
	</head><body>
HTL
print $data;

my $numberAdded = &generateNewKeyfile($myORFs, "$saveDir/$fileName", $q);

my $outputDir = $saveDir;
$outputDir =~ s/^\.\.\//$asset_prefix->{'base'}\//;
&printFileDownload($outputDir, $fileName, $numberAdded);

sub generateNewKeyfile {
	my ($myORFS, $fileNameAndPath, $q) = @_;
	# if($q->param('numBlanks') !~ /^\d+$/){
	# 	&printError("Invalid valid for 'Number of blanks': $q->param('numBlanks'). This value must be a positive integer.");
	# }
	if(!defined $q->param('keyFile')){
		&printError("You must select a key file source.");
	}
	my $libs = &pullAcceptableLibraries();
	if(!defined ($libs->{$q->param('keyFile')})){
		&printError($q->param('keyFile')." is an invalid key file source choice.");
	}
	my $keyFileSource = $libs->{$q->param('keyFile')}->{'location'};
	$libs = undef;
	$keyFileSource =~ s/^http\:\/\/www\.rothsteinlab\.com\/tools//;
	$keyFileSource = '../../public/'.$keyFileSource;
	open my $KEY, $keyFileSource || die "Cound not open key file source: '$keyFileSource' $!";
	$/ = &line_break_check( $KEY );
	my (%colindex, $resthead, $totalCols, @colNums);
	{
		# header should be on the third line
		my $head = <$KEY>;
		$head = <$KEY>;
		$head = <$KEY>;
		chomp($head) if $head;
		my @oHeaders = split /\t/, $head;
		$totalCols = scalar(@oHeaders);
		$resthead=""; # this string will store the info in the key file that is not associated with the "plate", "row", or "column" columns. This will be use to print out the header of the output files
		my $count = 0;
		foreach $head(@oHeaders){
			$colindex{lc($head)}=$count;
			if($head !~ /^plate #$/i && $head !~ /^row$/i && $head !~ /^column$/i){
				$resthead.="$head\t";
				push(@colNums, $count);
			}
			$count++;
		}
	}
	if(!defined $colindex{'plate #'} || !defined $colindex{'row'} || !defined $colindex{'column'}){
		&printError("Could not find 'plate #', 'row', or 'column' column in source key file.");
	}
	if(!defined $colindex{'orf'}){
		&printError("Could not find ORF column in source key file.");
	}

	my $firstIndex = $colindex{'gene'};
	my $secondIndex = $colindex{'orf'};
	my ($firstSpacer, $secondSpacer) = ("", "\t");
	{
		if($firstIndex > $secondIndex){
			my $temp = $firstIndex;
			$firstIndex = $secondIndex;
			$secondIndex = $temp;
		}
		my $count = 3;
		while($count < $firstIndex){
			$firstSpacer .= "\t";
			$count++;
		}
		while($count < $secondIndex){
			$secondSpacer .= "";
			$count++;
		}
	}

	my %keyInfo = ();
	while(<$KEY>){
		chomp;
		my @kdata=split /\t/;
		# if (defined $myORFs->{'hash'}->{uc($kdata[$colindex{'orf'}])}) {
		$keyInfo{uc($kdata[$colindex{'orf'}])}=\@kdata;
		# }
	}
	my %orfsNotFound = ();
	my %output = ();
	my $counter = 0;
	foreach my $orf(@{$myORFs->{'array'}}){
		if(defined $keyInfo{uc($orf)}){

			$orf = uc($orf);
			my $output = "$keyInfo{$orf}->[$colindex{'plate #'}]\t$keyInfo{$orf}->[$colindex{'row'}]\t$keyInfo{$orf}->[$colindex{'column'}]\t";
			foreach my $col(@colNums){
				$keyInfo{$orf}->[$col] = '-' if !defined $keyInfo{$orf}->[$col];
				$output.= "$keyInfo{$orf}->[$col]\t";
			}
			$output{$keyInfo{$orf}->[$colindex{'plate #'}]}->{$keyInfo{$orf}->[$colindex{'row'}]}->{$keyInfo{$orf}->[$colindex{'column'}]} = $output;
			$counter++;
		}
		else{	$orfsNotFound{$orf}=1;	}
	}
	%keyInfo=();
	$myORFs=undef;

	my $counterForFullPlate=0;

	if($counter > 0){
		my @rows = ("A".."Z");
		my $currentRow=0;
		my $currentCol=1;
		my $plate = 1;
		my $totalRows=0;
		open (my $OUT, ">$fileNameAndPath") || die "couldn't open the file $!";

		my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime;
		$year += 1900;
		$mon++;
		$mon = "0$mon" if $mon < 10;
		$mday = "0$mday" if $mday < 10;
		my $date = "$year-$mon-$mday";
		my $amPM = 'AM';
		if($hour > 12){
			$hour -= 12;
			$amPM = 'PM'
		}

		print $OUT "File generated: $date at $hour\:$min $amPM\n";
		print $OUT "Excel format for zebra striped = '=MOD(ROW(),2)'\n";
		print $OUT "Plate #\tRow\tColumn\tSource Plate\tSource Row\tSource Column\t$resthead\n";
		foreach my $sourcePlate(sort {$a<=>$b} keys %output){
			foreach my $row(sort keys %{$output{$sourcePlate}}){
				foreach my $col(sort {$a<=>$b} keys %{$output{$sourcePlate}->{$row}}){
					($currentCol, $currentRow, $plate) = &checkIfResetNeeded($currentCol, $currentRow, $OUT, $plate, $totalRows, $firstSpacer, $secondSpacer);
					# check for control positions
					if(($currentRow == 0 && $currentCol == 1) || # top left
							($currentRow == 0 && $currentCol == 12) || # top right
								($currentRow == 7 && $currentCol == 12) || # bottom right
									($currentRow == 7 && $currentCol == 1) || # bottom left
										($currentRow == 0 && $currentCol == 5) ||
											($currentRow > 0 && $currentRow < 5 && $currentCol == ($currentRow+$currentRow+1)) || #
												($currentRow == 5 && $currentCol == 3) ||
													($currentRow == 6 && $currentCol == 5) ||
														($currentRow == 7 && $currentCol == 7)
						){
						print $OUT "$plate\t$rows[$currentRow]\t$currentCol\t\t\t\t$firstSpacer\ POSITIVE CONTROL$secondSpacer\ POSITIVE CONTROL\n";
						$totalRows++;
						$currentCol++;
						#  reset
						($currentCol, $currentRow, $plate, $totalRows) = &checkIfResetNeeded($currentCol, $currentRow, $OUT, $plate, $totalRows, $firstSpacer, $secondSpacer);
					}
					print $OUT "$plate\t$rows[$currentRow]\t$currentCol\t";
					print $OUT $output{$sourcePlate}->{$row}->{$col}."\n";
					$currentCol++;
					$totalRows++;
				}
			}
		}

		# print out one more control...
		if($totalRows % 96 != 0){
			print $OUT "$plate\t$rows[$currentRow]\t$currentCol\t\t\t\t$firstSpacer\ POSITIVE CONTROL$secondSpacer\ POSITIVE CONTROL\n";
			$totalRows++;
			$currentCol++;
		}

		while($totalRows % 96 != 0){
			if($currentCol >12){
				$currentCol = 1;
				$currentRow++;
			}
			print $OUT "$plate\t$rows[$currentRow]\t$currentCol\t\t\t\t$firstSpacer\ BLANK$secondSpacer\ BLANK\n";

			unless(($currentRow == 0 && $currentCol == 1) || # top left
					($currentRow == 0 && $currentCol == 12) || # top right
						($currentRow == 7 && $currentCol == 12) || # bottom right
							($currentRow == 7 && $currentCol == 1) || # bottom left
								($currentRow == 0 && $currentCol == 5) ||
									($currentRow > 0 && $currentRow < 5 && $currentCol == ($currentRow+$currentRow+1)) || #
										($currentRow == 5 && $currentCol == 3) ||
											($currentRow == 6 && $currentCol == 5) ||
												($currentRow == 7 && $currentCol == 7)
				){ $counterForFullPlate++;}

			$currentCol++;
			$totalRows++;
		}
		close $OUT;
	}

	if(%orfsNotFound){
		print "Could not find the following ORFs in the selected source key:<br /><ul><li>";
		print join("</li><li>", keys %orfsNotFound);
		print "</li></ul><br/>";
	}
	if($counter > 0 && $counterForFullPlate > 0){
		print "<strong>Number of ORFs needed for full plate: $counterForFullPlate</strong><br/><br/>";
	}

	return $counter;
}

sub checkIfResetNeeded{
	my($currentCol,$currentRow, $out, $plate, $totalRows, $firstSpacer, $secondSpacer) = @_;
	#  reset
	if((($currentRow+1) * $currentCol) > 96){
		$totalRows++;
		$plate++;
		$currentRow=0;
		print $out "$plate\tA\t1\t\t\t\t$firstSpacer\ POSITIVE CONTROL$secondSpacer\ POSITIVE CONTROL\n";
		$currentCol=2;
	}
	elsif($currentCol >12){
		$currentCol = 1;
		$currentRow++;
	}
	return ($currentCol,$currentRow, $plate, $totalRows);
}

sub pullAcceptableLibraries{
	my %libs;
	my $dbh = &connectToMySQL();
	# $dbh->{TraceLevel} = 2;
	# fetch library possibilities
	my $sth = $dbh->prepare("SELECT `key_file_location`,`name`, `id` FROM `strain_libraries`");
	$sth->execute() or die $DBI::errstr;
	if ($sth->rows < 0) {	&printError( "Sorry, query failed when asking for strain libraries");	}
	while (my $results = $sth->fetchrow_hashref) {
		$libs{$results->{id}}->{'name'} = $results->{'name'};
		$libs{$results->{id}}->{'location'} =$results->{key_file_location};
	}
	$sth->finish();
	$dbh->disconnect();
	return \%libs;
}

sub setuptOutputDirectory{
	my ($dir, $q) = @_;
	# check if directory exists for this user
	if(! -d $dir){
		eval{mkdir($dir, 0750) || die "Could not create directory $dir: $!";};
		if($@){
			&printError("Error generating output0.");
		}
	}
	&bookkeeper($dir);
	my $count = 0;
	if(-d $dir){
		# find out what we can name this new directory (by figure out what is already there, or not there)
		opendir(DIR, $dir);
		my @files = readdir(DIR);
		$count = scalar(@files);
		while(-e "$dir/$count"){	$count++;	}
		eval{mkdir("$dir/$count", 0755) || die "Could not create directory $dir/$count: $!";};
		if($@){&printError($@);}
		$dir = "$dir/$count";
	}
	else{&printError("Error generating output.");}
	return $dir;
}

sub printFileDownload{
	my ($dir, $fileName, $numberAdded) = @_;
	$dir =~ s/^(\.\.\/)+//;
	if($numberAdded > 0){
		print "<h3>$numberAdded ORFs added to your key file</h3><br/>";
		print "<h2><a href='$dir/$fileName' id='downloadLink' style='padding-left:10px'>";
		print 'Right click here and select "Save as" to download.</a></h2>';
	}
	else{	print "<h2>No valid ORFs found - key file not generated.</h2>";}
}

sub printError{
	my $dieMsg = shift;
	print "<div class='alert'>Error generating output! $dieMsg</div>";
	die $dieMsg;
}

sub bookkeeper {
	# Delete out old sessions that have been abandoned (ie have not been modified) for greater then 1 day
	my $dir=shift;
	if(-d $dir){ # ignore subversion repos
		opendir (DH,"$dir");
		my $file;
		while ($file = readdir DH) {
			# the next if line below will allow us to only consider files with extensions
			next if ($file eq '.' || $file eq '..');
			if (-M "$dir/$file" > 1){
				if(-d "$dir/$file"){rmdir("$dir/$file") if $dir =~ /\.\.\/tools\/temp\/screenTrollOutput/i;} # rmdir will remove any empty directories
				else{unlink "$dir/$file";}
			}
		}
	}
}

#	Loads the screen data from the input web page
sub loadMyData {
	my($data, $orf_pattern, $orfs, $geneNames, $aliases)= @_;
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
	my  %myORFs;
	ORF:foreach my $orf(@myData) {				# iterate over @mydata
		$orf = &trimErroneousCharacters($orf);						# invoke trimErroneousCharacters subroutine
		if(!$orf){next ORF;}
		if ($orf =~/$orf_pattern/) {		# check each value is a yeast ORF
			$myORFs{'hash'}->{$orf} = 1;			# create %myORFs{'hash'}-> of @mydata key=ORF value=id1 (aka name of your query)
			push(@{$myORFs{'array'}}, $orf);
		}
		# maybe we have a gene name?
		elsif($geneNames->{$orf}){
			$myORFs{'hash'}->{$geneNames->{$orf}}=1;
			push(@{$myORFs{'array'}}, $geneNames->{$orf});
		}
		# maybe we have an alias
		elsif($aliases->{$orf}){
			$myORFs{'hash'}->{$aliases->{$orf}}=1;
			push(@{$myORFs{'array'}}, $aliases->{$orf});
		}
		else{
			print $orf," could not be identified as a systematic ORF identifier, gene name or alias and therefore was not included in this analysis.<br />";
		}
	}
	print "<br/>";
	return \%myORFs;
}

# line_break_check receives a file handle as its input and returns the new line character used in the file handle
sub line_break_check{
	my $file = shift;
	local $/ = \1000; # read first 1000 bytes
	local $_ = <$file>; # read
	my ($newline) = /(\015\012?)/ ? $1 : "\012"; # Default to unix.
	seek $file,0,0; # rewind to start of file
 	return $newline;
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
