#!/usr/bin/perl -w

BEGIN {
	my $log;
	use CGI::Carp qw(carpout);
	open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}
use strict;
use LWP::Simple; # needed to retrieve website
use Storable qw(store retrieve); # to store / retrieve data structures on disk
use Mail::Mailer;
use File::Find;
use File::Copy;
use Compress::Zlib ;
use Modules::ScreenAnalysis qw(:sqlOnly); # use my module and only load routines in analysis
use DBI qw(:sql_types);
# ******************* VARIABLE DECLARATIONS ********************
my $asset_prefix = &static_asset_path();

my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
$month++;
my $now = "$year-$month-$dayOfMonth";

my $sgd_features = 'http://downloads.yeastgenome.org/curation/chromosomal_feature/SGD_features.tab';
my $sgd_short='SGD_features.tab';
# Columns within SGD_features.tab:
# 1.   Primary SGDID (mandatory)
# 2.   Feature type (mandatory) --> ORF, CDS, ARS, intron, ect.
# 3.   Feature qualifier (optional)
# 4.   Feature name (optional) ---> i.e. ORF!!!
# 5.   Standard gene name (optional)
# 6.   Alias (optional, multiples separated by |)
# 7.   Parent feature name (optional)
# 8.   Secondary SGDID (optional, multiples separated by |)
# 9.   Chromosome (optional)
# 10.  Start_coordinate (optional)
# 11.  Stop_coordinate (optional)
# 12.  Strand (optional)
# 13.  Genetic position (optional)
# 14.  Coordinate version (optional)
# 15.  Sequence version (optional)
# 16.  Description (optional)
# as of 02/17/08 the columns of data in SGD_features had the indices listed below
my $sgd_orf_index=3;
my $description_index=15;
my $alias_index=5;
my $gene_name_index=4;


#
#
# term descriptions are located here:
# ftp://genome-ftp.stanford.edu/pub/yeast/data_download/literature_curation/go_terms.tab
my $go_slim = 'http://downloads.yeastgenome.org/curation/literature/go_slim_mapping.tab';
my $go_short = 'go_slim_mapping.tab';
# go_slim_mapping columns (as of 05/01/2008):
# 1) ORF (mandatory) 		- Systematic name of the gene
# 2) Gene (optional) 		- Gene name, if one exists
# 3) SGDID (mandatory) 		- the SGDID, unique database identifier for the gene
# 4) GO_Aspect (mandatory) 	- which ontology: P=Process, F=Function, C=Component
# 5) GO Slim term (mandatory) 	- the name of the GO term that was selected as a GO-Slim term
# 6) GOID (optional) 		- the unique numerical identifier of the GO term
# 7) Feature type (mandatory) 	- a description of the sequence feature, such as ORF or tRNA
my $go_orf_index=0;
my $aspect_index=3;
my $term_index=4;
my $feature_index=6;

my $orf_pattern='^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?';
my $orf_exact_pattern='^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$';
my $feature_pattern='^ORF{1}\|(Dubious|Verified|Uncharacterized|Merged|Deleted){1}';
my $change_log="";
my $error_log="";

my (@f_lines,@go_lines); # holds the lines of SGD_features.tab and go_slim_mapping.tab

my @data;
my (%gene_name,%alias,%description); # hashes to hold select information from SGD_features.tab with ORF names as keys
my (%bio_process, %mol_function, %cell_component); # hashes to hold select info from go_slim_mapping.tab

# directory where key files are located
my $dat_key_dir="../../data/key_file_data";
my $key_dir="../key_files";
# filenames of guys to update
my @file_names = (
	"dampLibKey.tab", # DamP library keyfile
	"rothstein_deletion_alpha.tab",  # MAT alpha - 96 strains / plate
	"MATa_names.tab", # MAT a - 96 strains / plate
	"HB_alpha.tab", # MAT alpha - 384 strains / plate
	"curie_deletion_alpha.tab", # MAT alpha - 96 strains / plate
	"Lisby_mat_a.tab", # mat a - 384 strains / plate
	"BoonYeastDeletionMATa.tab",
	"MATaKEY.tab", # MAT a - 384 strains / plate
	"Hetero_essential_r1.tab", # diploids - 96 strains / plate
	"HieterMATa.tab", # MAT a - 1536 strains / plate
	"DPI_array.tab",
	"tsMATaKeyFile.tab",
	"GFPlib384.txt"
);
#my @file_names = ("HB_alpha.tab");
#my @file_names = ("HieterMATa.tab");
my %changes=();

# the below variables are uses to process individual key files
my (%colindex, $head, @headers, $resthead, @before_head);

my @dat_files; # stores the names for .dat files in the key file directory
my %keyinfo; # used in recreation of .dat files

# get files and store locally...useful for testing
#getstore($sgd_features, $sgd_short);
#getstore($go_slim, $go_short);
#my $file;
#open($file, "<$sgd_short") || die "Could not upen $sgd_short.";
#@f_lines=<$file>;
#close $file;
#open($file, "<$go_short") || die "Could not upen $go_short.";
#@go_lines=<$file>;

@f_lines=split("\n",&getFile($sgd_features, $sgd_short, "die"));
@go_lines=split("\n",&getFile($go_slim, $go_short, "continue"));

# get the first line that contains a feature that is defined as an ORF, confirmed or dubious...
# if 1000 lines are iterated over without finding a feature that is an ORF assume that the file is messed up...
&checkFile(\@f_lines, $sgd_short, '\tORF\t', $orf_pattern, 'orf',  $sgd_orf_index, 'die');
&checkFile(\@go_lines, $go_short, $orf_pattern, $feature_pattern, 'Feature type', $feature_index, 'continue');



my @SGD_indices=($gene_name_index, $alias_index, $description_index);
my @SGD_features=(\%gene_name, \%alias, \%description);
&initializeData(\@f_lines, $sgd_short, $orf_pattern, $sgd_orf_index, \@SGD_indices, \@SGD_features, 'SGD' );
$error_log.=&freezeDownSGD_features(\@SGD_features, $dat_key_dir, $error_log);

my @go_indices=($term_index,$aspect_index);
my @go_features=(\%bio_process, \%mol_function, \%cell_component);
my %go_cat_size; my $go_cat_log="";
&initializeData(\@go_lines, $go_short, $orf_pattern, $go_orf_index, \@go_indices, \@go_features, 'GO' );
$bio_process{"GO TERM INFORMATION"}='P';
$mol_function{"GO TERM INFORMATION"}='F';
$cell_component{"GO TERM INFORMATION"}='C';

my @all_features=@SGD_features;
push(@all_features,@go_features);

my @changeColumns  = ('gene', 'alias', 'description','go biological process','go molecular function','go cellular component');
my @header_order   = ('plate #','row','column','orf','gene','alias','description','go biological process',	'go molecular function',	'go cellular component');
my @p_header_order = ('Plate #','Row','Column','ORF','Gene','Alias','Description','GO Biological Process',	'GO Molecular Function',	'GO Cellular Component');
# data is now appropriately loaded into data structures, now update key files with this info....
# iterate over each key file
foreach my $file(@file_names){
	($changes{$file},$go_cat_size{$file})=&updateKeyFiles($key_dir, $file, \@changeColumns, \@all_features, \@header_order, \@p_header_order, $aspect_index , 9);
}

if (-e "$dat_key_dir/go_cats.go") {
	eval{unlink "$dat_key_dir/go_cats.go" || die "Could not delete $dat_key_dir/go_cats.go. $!.";};
	if($@){$go_cat_log.="\nERROR!!!  Could not delete $dat_key_dir/go_cats.go.  See error log for more details.\n\n";}
}
eval {store(\%go_cat_size, "$dat_key_dir/go_cats.go")};
if($@){ $go_cat_log.= 'Serious error from Storable, storing %go_cat_size: '.$@.'<br/>';}

my $old_dir = "$dat_key_dir/old";
if(! -d $old_dir){	eval{mkdir($old_dir, 0755) || die "Could not create directory $old_dir: $!";};}
open(OUT, ">>$old_dir/$now-changelog.log") or die "Cannot open changelog file: $dat_key_dir/old/$now-changelog.log.  $!";
foreach my $file(@file_names){
	$change_log.= "$file = ".($#{$changes{$file}}+1)." changes.\n";
	foreach my $change(@{$changes{$file}}){
		print OUT gmtime()."\t$file\t$change\n";
	}
}
close OUT;


&updateMySQL(\@SGD_features);


# &complexDataMySQL('benschop');
# &complexDataMySQL('baryshnikova');


# delete the .dat files == data structures stored via storable that were derived from the original key files...
&deleteDAT($dat_key_dir);
# begin using updated key files, start by....
&moveOldRenameUpdated($key_dir, \@file_names, $now);
# delete key files older then 6 months
bookkeeper("$dat_key_dir/old", 180);
bookkeeper("$key_dir/old", 180);
# recreate .dat files so other programs run faster...
&createDAT($key_dir, $dat_key_dir, \@file_names);


&go_fullMySQL();

$change_log.="\nSee the log file in $dat_key_dir for more details.\n";
$change_log.= "The End\n";


# send results via email...
my $from_address = 'web_tools@rothsteinlab.com';
my $to_address = 'jcd2133@columbia.edu';
my $subject = "key file update status";
my $body ="CHANGE LOG:\n$change_log\n\n\n";
unless($go_cat_log eq "" || !$go_cat_log){$body.="GO CATEGORY LOG:\n$go_cat_log\n\n\n";}
unless($error_log eq "" || !$error_log){$body.="ERROR LOG:\n$error_log\n";}
&send_result($body,$from_address,$subject,$to_address);



sub loadComplexData{
	my ($dataFrom) = @_;
	my %complexData;
	if($dataFrom eq 'benschop'){
		open (my $COMPLEXES, "<interactionData/BenschopProteinComplexStandard.txt") || return {'error' => "Couldn't open Benschop Protein Complex data.\n"};
		$/ = line_break_check( $COMPLEXES );
		my $header = <$COMPLEXES>;
		foreach(<$COMPLEXES>){
			chomp;
			my @data=split /\t/;
			my @orfs = split /\; /, $data[2];
			my @genes = split /\; /, $data[3];
			my $complex = $data[0];
			for (my $i = 0; $i < @orfs; $i++) {
				$complexData{'ids'}->{$orfs[$i]}->{'complex'}->{$complex}=1;
				$complexData{'ids'}->{$orfs[$i]}->{'gene'}=$genes[$i];
				if(!defined $complexData{'counts'}->{$complex})	{$complexData{'counts'}->{$complex} = 0;}
				else{$complexData{'counts'}->{$complex}++;}
			}
		}
		close $COMPLEXES;
		# save complex data
		eval{store(\%complexData, "interactionData/savedStructures/BenschopProteinComplexStandard.dat")};
		if($@){warn "Serious error from Storable storing BenschopProteinComplexStandard.dat: $@";}
	}
	else{
		open (my $COMPLEXES, "<interactionData/BaryshnikovaProteinComplexStandard.txt") || warn "Could not load Baryshnikova data.";
		$/ = line_break_check( $COMPLEXES );
		foreach(<$COMPLEXES>){
			chomp;
			my @data=split /\t/;
			# data 0 = orf
			# 1 = gene
			# 2 = complex name
			$complexData{'ids'}->{$data[0]}->{'complex'}->{$data[2]}=1;
			$complexData{'ids'}->{$data[0]}->{'gene'}=$data[1];
			if(!defined $complexData{'counts'}->{$data[2]})	{$complexData{'counts'}->{$data[2]} = 1;}
			else{$complexData{'counts'}->{$data[2]}++;}
		}
		close $COMPLEXES;
	}
	return \%complexData;
}

sub complexDataMySQL{
	my $type = shift;
	my $complexData = &loadComplexData($type);

	my $sqlTypes = &getSQLTypes();
	my $dbh = &connectToMySQL();
	my $table_name = 'scerevisiae_'.$type.'_complex_data';
	my $mysqlDB = &get_db_name();
	my $mySQLcolNames =	&getColumnNamesAndTypes($dbh, $table_name, $mysqlDB);
	#	$dbh->{TraceLevel} = 3;
	my $limit = 40;
	# setup statement to insert $limit records at a time
	my @cols = ('orf', 'gene', 'complex');
	my $mySQLst = &setupMySQLinsert($table_name, \@cols, $limit);
	# prepare MySQL insert statement
	my $insertMySQLsth = $dbh->prepare( $mySQLst ) || die "Can't prepare a statement: $DBI::errstr";
	my $i=0;
	my $iterator=0;
	my $count=0;
	foreach my $orf(keys %{$complexData->{'ids'}}){
		foreach my $complex(keys %{$complexData->{'ids'}->{$orf}->{'complex'}}){
			$insertMySQLsth->bind_param( (++$i),  $orf ,$sqlTypes->{$mySQLcolNames->{'ORF'}}->() );
			$insertMySQLsth->bind_param( (++$i),  $complexData->{'ids'}->{$orf}->{'gene'}, $sqlTypes->{$mySQLcolNames->{'GENE'}}->() );
			$insertMySQLsth->bind_param( (++$i),  $complex, $sqlTypes->{$mySQLcolNames->{'COMPLEX'}}->() );
			$iterator++;
			if($iterator >= $limit){
				$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
				$i=0;
				$iterator=0;
			}
			$count++;
		}
	}
	$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
	$insertMySQLsth->finish();

	$i=0;
	$iterator=0;
	$count = 0;
	$table_name = 'scerevisiae_complex_terms';
	$mySQLcolNames =	&getColumnNamesAndTypes($dbh, $table_name, $mysqlDB);
	@cols = ('complex', 'numberOfMembers', 'source');
	$mySQLst = &setupMySQLinsert($table_name, \@cols, $limit);
	my $insertMySQLsth2 = $dbh->prepare( $mySQLst ) || die "Can't prepare a statement: $DBI::errstr";
	foreach my $complex(keys %{$complexData->{'counts'}}){
		$insertMySQLsth2->bind_param( (++$i),  $complex ,$sqlTypes->{$mySQLcolNames->{'COMPLEX'}}->() );
		$insertMySQLsth2->bind_param( (++$i),  $complexData->{'counts'}->{$complex}, $sqlTypes->{$mySQLcolNames->{'NUMBEROFMEMBERS'}}->() );
		$insertMySQLsth2->bind_param( (++$i),  $type, $sqlTypes->{$mySQLcolNames->{'SOURCE'}}->() );
		$iterator++;
		if($iterator >= $limit){
			$insertMySQLsth2->execute() || warn "cannot update $DBI::errstr";
			$i=0;
			$iterator=0;
		}
		$count++;

	}
	$insertMySQLsth2->execute() || warn "cannot update $DBI::errstr";
	$insertMySQLsth2->finish();

	$dbh->commit();
	$dbh->disconnect();
}

sub getSQLTypes {
	my %sqlTypes = (q
	  "SQL_VARCHAR" => \&SQL_VARCHAR,
	  "SQL_DATE" => \&SQL_DATE,
		"SQL_BLOB" => \&SQL_BLOB,
	  "SQL_TINYINT" => \&SQL_TINYINT,
		"SQL_DOUBLE" => \&SQL_DOUBLE,
	  "SQL_INTEGER" => \&SQL_INTEGER,
		"SQL_TEXT" => \&SQL_CLOB,
		"SQL_TIMESTAMP" => \&SQL_TIMESTAMP,
		"SQL_DATETIME" => \&SQL_DATETIME,
		"SQL_BIGINT" => \&SQL_BIGINT,
		"SQL_FLOAT" => \&SQL_FLOAT,
		"SQL_TIME" => \&SQL_TIME,
		"SQL_INT" => \&SQL_INTEGER
	);
	return \%sqlTypes;
}

sub go_fullMySQL{

	my $sqlTypes = &getSQLTypes();

	# get go process term definitions
	# go_terms.tab		This file is TAB delimited and contains the GO terms and their definitions.
	# Columns are:			Contents:
	# 1) GOID (mandatory)		- the unique numerical identifier of the GO term
	# 2) GO_Term (mandatory)		- the name of the GO term
	# 3) GO_Aspect (mandatory)	- which ontology: P=Process, F=Function, C=Component
	# 4) GO_Term_Definition (optional) 		- the full definition of the GO term
	# This file is updated weekly.
	my %goTermData=();
	{
		my $goTerms = 'http://downloads.yeastgenome.org/curation/literature/go_terms.tab';
		my $goTermShort = "go_term_definitions";
		my @goTermData = split("\n",&getFile($goTerms, $goTermShort, "continue"));
		foreach my $row(@goTermData){
			chomp($row);
			my @data = split("\t",$row);
			if($data[2] =~ /P/i){
				my $zerosToPrepend = 7 - length($data[0]);
				if($zerosToPrepend < 0){
					&send_result("update_key_file error!. improper # of zeros for data[0] = $data[0]");
					die "improper # of zeros for data[0] = $data[0]";
				}
				$data[0] = 'GO:'. 0 x $zerosToPrepend . $data[0];
				$goTermData{$data[0]}->{'name'} = $data[1];
				$goTermData{$data[0]}->{'definition'} = $data[3];
				$goTermData{$data[0]}->{'size'} = 0;
			}
		}
	}
	# get full GO process data for storing in database
	my $go_full = 'http://downloads.yeastgenome.org/curation/literature/gene_association.sgd.gz';
	my $go_short = 'go_gene_association';
	my $goDataBuffer = &getFile($go_full, $go_short, "continue");
	$goDataBuffer = Compress::Zlib::memGunzip($goDataBuffer) or die "Cannot uncompress: $gzerrno\n";
	my @go_lines = split("\n",$goDataBuffer);
	$goDataBuffer = undef;

	# GO gene_association.sgd.gz  column definitions.
	#   This file is TAB delimited and contains all GO annotations for yeast genes (protein and RNA)
	#  				1) DB						- database contributing the file (always "SGD" for this file)
	#  				2) DB_Object_ID				- SGDID
	#  3) DB_Object_Symbol				- Gene name (if it exists) otherwise the ORF id
	#  4) NOT 			(optional)	- 'NOT', 'contributes_to', or 'colocalizes_with' qualifier for a GO annotation, when needed
	#  5) GO ID					- unique numeric identifier for the GO term
	#  6) DB:Reference(|DB:Reference)			- the reference associated with the GO annotation
	#  7) Evidence					- the evidence code for the GO annotation
	#  8) With (or) From 		(optional)	- any With or From qualifier for the GO annotation
	#  9) Aspect					- which ontology the GO term belongs in WE ONLY CARE ABOUT PROCESS TERMS! ('P')
	# 10) DB_Object_Name(|Name) 	(optional)	- a name for the gene product in words, e.g. 'acid phosphatase'
	# 11) DB_Object_Synonym(|Synonym) - The Systematic ORF name will be the first name present in Column 11. Any other names (except the Standard Name, which will be in Column 3 if one exists), including Aliases used for the gene will also be present in this column.
	# 12) DB_Object_Type				- type of object annotated, e.g. gene, protein, etc.
	# 13) taxon(|taxon)				- taxonomic identifier of species encoding gene product
	# 14) Date					- date GO annotation was made
	# 15) Assigned_by					- source of the annotation (e.g. SGD, UniProtKB, YeastFunc, bioPIXIE_MEFIT)

	my $feature_pattern = '\t[C|P|F]\t';
	my $feature_index = 8;
	my $go_orf_index=10;
	my @indiciesWeCareAbout = (2,$go_orf_index, 3,4,5,6,7,9,11,13,14);
	my @cols = ('gene', 'orf', 'qualifier', 'go_id', 'dbReference', 'evidence', 'withOrFrom', 'objectName', 'objectType', 'date', 'assignedBy');

	if(&checkFile(\@go_lines, $go_short, $feature_pattern, $orf_pattern, 'orf',  $go_orf_index, 'continue')){

		# get rid of header
		while($go_lines[0]=~/^!/){shift @go_lines;}
		my %goData = ();
		foreach my $line(@go_lines){
			chomp ($line);
			@data=split(/\t/,$line);
			my @orf = split(/\|/,$data[$go_orf_index]);
			# make sure ORF is formatted properly...
			if($orf[0] && $data[$feature_index] && $data[$feature_index] eq 'P'){
				# if this go id exists in goTermData
				if($goTermData{$data[4]} ){
					if(! defined $goData{$data[4]}->{$orf[0]}){
						$goData{$data[4]}->{$orf[0]}->{'gene'} = uc($data[2]);
						$goTermData{$data[4]}->{'size'}++;
					}
					# since we just manually bound the 1st 2 values, start for statement at 2
					for(my $k=2;$k<@indiciesWeCareAbout;$k++){
						if($data[$indiciesWeCareAbout[$k]]){
							$goData{$data[4]}->{$orf[0]}->{$cols[$k]}->{$data[$indiciesWeCareAbout[$k]]}=1;
						}
					}
				}
				else{warn "no $data[4] definition";}
			}


		} # end foreach line in go data
		@go_lines=();

		# now insert this data into the database...
		# this code is copied from initialize data and the mysql function
		my $dbh           = &connectToMySQL();
		my $table_name    = 'scerevisiae_go_process_associations';
		my $mysqlDB       = &get_db_name();
		my $mySQLcolNames =	&getColumnNamesAndTypes($dbh, $table_name, $mysqlDB);

		my $limit = 40;
		# setup statement to insert $limit records at a time

		my $mySQLst = &setupMySQLinsert($table_name, \@cols, $limit);
		# prepare MySQL insert statement
		my $insertMySQLsth = $dbh->prepare( $mySQLst ) || die "Can't prepare a statement: $DBI::errstr";

		my $i=0;
		my $iterator=0;
		my $count=0;

		foreach my $goID(keys %goData){
			foreach my $orf(keys %{$goData{$goID}}){

				$insertMySQLsth->bind_param( (++$i),  $goData{$goID}->{$orf}->{'gene'} ,$sqlTypes->{$mySQLcolNames->{'GENE'}}->() );
				$insertMySQLsth->bind_param( (++$i),  $orf ,$sqlTypes->{$mySQLcolNames->{'ORF'}}->() );
				for(my $k=2;$k<@indiciesWeCareAbout;$k++){
					my $t = '';
					if( $goData{$goID}->{$orf}->{$cols[$k]} ){
						my %copy = %{ $goData{$goID}->{$orf}->{$cols[$k]} };
						if (uc($cols[$k]) eq 'DATE'){ # allow only the latest date
							my @array = sort keys %copy;
							$t = $array[-1];
						}
						else{ $t = join( '|', keys %copy ) };
					}
					$insertMySQLsth->bind_param( (++$i),  $t, $sqlTypes->{$mySQLcolNames->{uc($cols[$k])}}->());
				}

				$iterator++;
				if($iterator >= $limit){
					$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
					$i=0;
					$iterator=0;
				}
				$count++;
			}
		}

		$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
		$insertMySQLsth->finish();
		$dbh->commit();
		$dbh->disconnect();
		$change_log.= "$count records updated in MySQL!\n\n";
		$change_log.= "Data structures from $go_short updated in MySQL!\n\n";

		#  now update the GO Term definitions
		$dbh = &connectToMySQL();
		# $dbh->{TraceLevel} = 3;
		$limit = 40;
		$table_name = 'scerevisiae_go_terms';
		$mySQLcolNames =	&getColumnNamesAndTypes($dbh, $table_name, $mysqlDB);

		# setup statement to insert $limit records at a time
		@cols = ('go_id', 'name', 'size', 'definition');
		$mySQLst = &setupMySQLinsert($table_name, \@cols, $limit);
		# prepare MySQL insert statement
		$insertMySQLsth = $dbh->prepare( $mySQLst ) || die "Can't prepare a statement: $DBI::errstr";
		$i=0;
		$iterator=0;
		$count=0;
		foreach my $goID(keys %goTermData){
			if($goTermData{$goID}->{'size'}>0){
				$insertMySQLsth->bind_param( (++$i),  $goID, $sqlTypes->{$mySQLcolNames->{'GO_ID'}}->() );
				$insertMySQLsth->bind_param( (++$i),  $goTermData{$goID}->{'name'} ,$sqlTypes->{$mySQLcolNames->{'NAME'}}->() );
				$insertMySQLsth->bind_param( (++$i),  $goTermData{$goID}->{'size'},$sqlTypes->{$mySQLcolNames->{'SIZE'}}->() );
				$insertMySQLsth->bind_param( (++$i),  $goTermData{$goID}->{'definition'},$sqlTypes->{$mySQLcolNames->{'DEFINITION'}}->() );
				$iterator++;
				if($iterator >= $limit){
					$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
					$i=0;
					$iterator=0;
				}
				$count++;
			}
		}
		$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
		$insertMySQLsth->finish();
		$dbh->commit();
		$dbh->disconnect();
		$change_log.= "$count go terms updated in MySQL!\n\n";
		$change_log.= "Data structures from go term definitions updated in MySQL!\n\n";


	}
	else{	warn "validation failed";	}

}

sub updateMySQL{
	my $SGD_features=shift;

	my $dbh = &connectToMySQL();
#	$dbh->{TraceLevel} = 3;
	my $limit = 4;
	# setup statement to insert $limit records at a time
	my $mySQLst = "INSERT INTO `scerevisiae_genes` (`orf`, `gene`,`alias`,`description`) VALUES ";
	for(my $j=0; $j < $limit; $j++){	$mySQLst .= "(?,?,?,?), ";	}
	my $onDupKeySyntax.="`orf`=VALUES(`orf`), `gene`=VALUES(`gene`), `alias`=VALUES(`alias`), `description`=VALUES(`description`)";
	$mySQLst =~ s/, $//; # remove trailing comma and space
	$mySQLst .= " ON DUPLICATE KEY UPDATE $onDupKeySyntax";
	# prepare MySQL insert statement
	my $insertMySQLsth = $dbh->prepare( $mySQLst ) || die "Can't prepare a statement: $DBI::errstr";

	my $i=1;
	my $iterator=0;
	foreach my $orf(keys %{$SGD_features->[0]}){
		my @temp=();
		$insertMySQLsth->bind_param($i++, $orf);

		if(defined $SGD_features->[0]->{$orf}){
			$insertMySQLsth->bind_param($i++, join(", ",sort keys %{$SGD_features->[0]->{$orf}}));
		}
		else{$insertMySQLsth->bind_param($i++, "");}

		if(defined $SGD_features->[1]->{$orf}){
			$insertMySQLsth->bind_param($i++, join(", ",sort keys %{$SGD_features->[1]->{$orf}}));
		}
		else{ $insertMySQLsth->bind_param($i++, "");}

		if(defined $SGD_features->[2]->{$orf}){
			$insertMySQLsth->bind_param($i++, join(", ",sort keys %{$SGD_features->[2]->{$orf}}));
		}
		else{$insertMySQLsth->bind_param($i++, "");}

		$iterator++;
		if($iterator >= $limit){
			$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
			$i=1;
			$iterator=0;
			$dbh->commit();
		}
	}
	$insertMySQLsth->execute() || die "cannot update $DBI::errstr";
	$insertMySQLsth->finish();
	$dbh->do("ALTER TABLE `scerevisiae_genes` AUTO_INCREMENT = 1");
	$dbh->commit();
	if($dbh){$dbh->disconnect() || warn "Disconnection error: $DBI::errstr\n";}
}
# 1st argument = key file name we are updating
sub updateKeyFiles{
	my $key_dir        = shift;
	my $file           = shift;
	my $change_indices = shift;
	my $features       = shift;
	my $head_order     = shift; # array containing order of key file header (names)
	my $phead_order    = shift; # array containing order of key file header (names) for print
	my $go_index       = shift;
	my $num_columns    = shift;
	my (@data, $restinfo, $cur_index, $item, $OLD,%go_data, @go_term_aspect, $go_terms);
	my @changes=();
	eval{
		open($OLD, "<$key_dir/$file") or die "Cannot open $file key file: $key_dir/$file.  $!";
		$/ = line_break_check( \*$OLD );
		open(NEW, ">$key_dir/temp-$file") or die "Cannot open $file key file: $key_dir/$file.  $!";
	};
	if($@) {
		# the eval failed
		$error_log.= "\n\n***********Error opening $file.  $file not updated.***********\n\n\n";
	}
	else{
		my $colindex=&processKeyHeader($OLD, $file, $head_order,1, $phead_order); # colindex = hash reference with keys as head names, values = corresponding column number
		my %header_hash;
		my $feature_items="";
		# head_hash is like colindex but it only contains heads in @head_order array, could probably think of a better way to do this or could have
		# just had and array with indie numbers but whatever, this works...
		# if a key does not exist for a particular head then create it and set its value to the size of the colindex hash...
		foreach my $head(@$head_order){
			if(defined $$colindex{"\L$head"}){$header_hash{$head}=$$colindex{"\L$head"};} # have to use define to avoid issues with 0 values
			else{$$colindex{"\L$head"}=keys %$colindex;}
		}
		# iterate over data in key file, compare values to those in hashes constructed from SGD_features.tab.  Update old files if required...
		while(<$OLD>){
			chomp;
			@data=split /\t/;
			$restinfo="";
			$cur_index=0;
			# fill undefined columns with '-'
			for(my $i=@data;$i<$num_columns;$i++){unless($data[$i]){$data[$i]='-';}}
			foreach $item(@data){
				# print out all info not included in the plate, row, and column headings to $restinfo, if $data eq "" skip this
				if(!grep{$_ == $cur_index} values %header_hash){
					# use the following if statement to avoid blank lines while at the same time including blank columns...
					if(($item eq "" && $restinfo ne "") || $item ne ""){$restinfo.="$item\t";}
				}
				$cur_index++;
			}

			# keep track of changes we are making....
			unless($data[$$colindex{'gene'}]=~/BLANK/i || $data[$$colindex{'orf'}]=~/BLANK/i ){ # do not change info for blank positions...
				for(my $i=0;$i<@$change_indices;$i++){ # iterate over name of headers we are interested in,....
					if($$colindex{$$change_indices[$i]}){
						if($features->[$i]->{"GO TERM INFORMATION"}){
							$feature_items="";
							$go_terms='';
							foreach my $guy(keys %{$features->[$go_index]->{$data[$$colindex{'orf'}]}}){
								# push all the GO_categories that exist of this ORF at this plate, row, and column, into data structure....
								@go_term_aspect=split/~/, $guy;
								$go_data{$data[$$colindex{'plate #'}]}->{$data[$$colindex{'row'}]}->{$data[$$colindex{'column'}]}->{$go_term_aspect[1]}->{$go_term_aspect[0]}=1;
								if($features->[$i]->{"GO TERM INFORMATION"} eq $go_term_aspect[1]){$go_terms.="$go_term_aspect[0], ";}
								#print "$$change_indices[$i] --> $i --> $features->[$i]->{'GO TERM INFORMATION'} --> $go_term_aspect[1] -- > $go_term_aspect[0] --> $_ --> $go_index --> \n";
							}
							chop($go_terms);chop($go_terms);
							if(!$go_terms || $go_terms eq ''){$go_terms='-';}
							$feature_items=$go_terms;
						}
						else{
							if($features->[$i]->{ $data[$$colindex{'orf'}] }){
								my %copy = %{ $features->[$i]->{ $data[$$colindex{'orf'}] } };
								$feature_items=join(", ",sort keys %copy);
							}
							#print "before = $feature_items\n";
							if(!$feature_items || $feature_items eq ''){$feature_items='-';}
							#print "after = $feature_items\n\n";
						}
						if(!$data[$$colindex{$$change_indices[$i]}]){$data[$$colindex{$$change_indices[$i]}]='';}
						if($data[$$colindex{$$change_indices[$i]}] eq '' || ($feature_items ne $data[$$colindex{$$change_indices[$i]}])){
							push (@changes,"Changed the $$change_indices[$i] of $data[$$colindex{'orf'}] ($data[$$colindex{$$change_indices[$i]}]) to $feature_items.\n");
							$data[$$colindex{$$change_indices[$i]}]=$feature_items;
						}
					}
				}
			}
			else{ # contains the word BLANK!
				foreach my $head(@$head_order){$data[$$colindex{$head}] = '-' if(!defined($data[$$colindex{$head}]));}
			}
			# wrap plate number in brackets if it contains a dash ('-') in it to prevent Excel from automatically converting it to a date....stupid Excel.
			if($data[$$colindex{'plate #'}]=~/-/){
				$data[$$colindex{'plate #'}]=~ s/\[|\]//g;
				$data[$$colindex{'plate #'}]="[$data[$$colindex{'plate #'}]]";
			}
			#my $temp="";
			foreach my $head(@$head_order){
				print NEW "$data[$$colindex{$head}]\t";}
			#	if(!defined($data[$$colindex{$head}]) || !defined($$colindex{$head}) || !defined($head)){print "$file\nhead = $head --> colindex = $$colindex{$head} --> data = $data[$$colindex{$head}]\n$_\n\n";} }
			#print NEW $temp;
			print NEW "$restinfo\n";
		}
	}
	close NEW;
	close $OLD;
	return (\@changes,\%go_data);
}

# get %colindex setup, determine all lines before header line and store it in before_head array...
sub processKeyHeader{
	my $fh=shift;
	my $file = shift;
	my $head_order=shift;
	my $print_new=shift;
	my $phead_order=shift;
	my $iloop=0;
	my %colindex=();
	my $head="";
	my @headers=();
	my $resthead="";
	my @before_head=();

	while(!(defined $colindex{'plate #'} && defined $colindex{'row'} && defined $colindex{'column'} && defined $colindex{'orf'})){
		$iloop++;
		if($iloop>=100){
			$error_log.= "The key file $file is not formatted properly.\nMake sure that it contains a header with the words plate, row, and column over the appropriate column. This is case sensitive.\n";
			#send_result("CHANGE LOG:\n$change_log\n\n\nERROR LOG:\n$error_log\n");
			die " $file not formatted properly";
		}
		chomp ($head = <$fh>); # get a line
		push (@before_head,"\L$head");
		@headers = split /\t/, "\L$head"; # split by tabs
		@colindex{@headers} = (0..$#headers); # store column header names as the keys of this hash and their index numbers as the values
		$resthead=""; # this string will store the info in the key file that is not associated head_order array. This will be use to print out the header of the output files
		foreach $head(@headers){if(!grep{ $_ eq $head } @$head_order ){$resthead.="$head\t";}}
	}
	%colindex=();
	my @file_heads= split /\t/, pop(@before_head);
	@colindex{@file_heads}=(0..$#headers);
	if($print_new){
		foreach(@before_head){print NEW "$_\n" if($_!~/synced to sgd on/);}
		my $now = gmtime;
		print NEW "Synced to SGD on $now\n";
		print NEW join("\t",@$phead_order)."\t$resthead\n";
		return(\%colindex);
	}
	else{	return(\%colindex, $resthead);}
	#----------------------- END PROCESSING KEY FILE HEADERS --------------------------------
}
# 1st = reference to array containing file data,
# 2nd = short name of file we are analyzing,
# 3rd = pattern we are looking for,
# 4th = index # of ORFs,
# 5th = indices of that data we want to extract from the files we are analyzing
# 6th = reference to array of data structures (hashes references) that we will load with info from files (with ORFs as keys)
sub initializeData{
	my @data;
	my $file = shift;
	my $short = shift;
	my $pattern=shift;
	my $orf_index = shift;
	my $indices = shift; # when analyzing GO data aspect index is 1, term = 0
	my $features=shift;
	my $file_type=shift;
	my $count=0;
	foreach my $line(@$file){
		chomp ($line);
		# only consider ORF listings...
		if($line=~/\torf/i){
			@data=split("\t",$line);
			# make sure ORF is formatted properly...
			if($data[$orf_index]=~/$pattern/){
				for(my $i=0;$i<@$indices;$i++){
					if(!defined $data[$indices->[$i]]){$data[$indices->[$i]] = '';}
					# use hash to prevent dupliplicate entries...
					if($file_type eq 'GO'){
						if($i==0){
							$features->[$i]->{$data[$orf_index]}->{"$data[$indices->[$i]]~$data[$indices->[1]]"}=1;}
					}
					else{$features->[$i]->{$data[$orf_index]}->{$data[$indices->[$i]]}=1;}
				}
			}
		}
		$count++;
	}
	$change_log.= "Data structures from $short initialized.\n";
	$change_log.="**** END VERIFYING INTEGRITY OF $short ****\n\n";
}

# 1st argument should be an array
# 2nd = file name
# 3rd should be what we are looking for to validate file initially
# 4th = what we are looking for after 1st validation
# 5th = name of index we are looking for
# 6th = corresponding index
# 7th = string that tells us if we should kill the program if the file does not validate...
sub checkFile{
	my ($file,$short,$pattern,$second_pattern,$index_name,$index,$should_i_die) = @_;
	my $count = 0;
	$change_log.="**** BEGIN VERIFYING INTEGRITY OF $short ****\n";
	while($count<1000){
		if($file->[$count]=~/$pattern/){last;}
		$count++;
	}
	if($count==1000){
		$error_log.="The file: $short seems to be formatted incorrectly or corrupted.\nCould not find '$pattern' in the first 1000 lines.\nKey files NOT updated with data from this file.";
		if($should_i_die eq "die"){
			send_result("CHANGE LOG:\n$change_log\n\n\nERROR LOG:\n$error_log\n");
			die "The file: $short seems to be formatted incorrectly or corrupted.\nCould not find '$pattern' in the first 1000 lines.\nKey files NOT update. $!\n";
		}
		else{
			warn $error_log;
			return 0;
		}
	}
	else{$change_log.="Found '$pattern' on line #$count\n";}

	my @data=split('\t',$file->[$count]);
	$count=0;
	# check to make sure file is not re-arranged by finding the index that matches the pattern of an ORF name
	# and determining if it matches the index we think it should be at.
	foreach my $item(@data){
		if($item =~ /$second_pattern/){
			if($count != $index){
				$error_log.="The file: $short seems to be rearranged.  The usual $index_name index is ".($index+1).".  It appears to have move to index $count\nKey files NOT update.";
				send_result("CHANGE LOG:\n$change_log\n\n\nERROR LOG:\n$error_log\n");
				die "The file: $short seems to be rearranged.  The usual $index_name index is ".($index+1).".  It appears to have move to index $count\nKey files NOT update. $!\n";
			}
			else{last;}
		}
		$count++;
	}
	$change_log.= "The index of $index_name in $short looks like it is where it should be.\n";
	#warn $change_log;
	return 1;
}

# returns file parsed into an array, 1st argument = file location, 2nd=short file name, 3rd = what to do if file is not found (if this == die, kill program else just set error message)
sub getFile{
	my $url=shift;
	my $short=shift;
	my $should_i_die=shift;
	my ($content);
	# begin retrieving file
	$change_log.="Downloading file from $url...\n";
	unless(defined ($content=get($url))){
		# file could not be retrieved from FTP address...
		if($should_i_die eq "die"){
			send_result("Error retrieving $url\n");
			die "Error retrieving $url. $!\n";
		}
		else{$error_log.="Error retrieving $url --> will not update info from this file.\n";}
		return undef;
	}
	$change_log.="$short downloaded successfully!!!\n\n";
	return($content);
	# could also split here and return reference to resulting array....
}

# sub routine to delete .dat files in $key_dir.  Accepts $key_dir as input, assumes $error_log as already been initialized
sub deleteDAT{
	my $key_dir=shift;
	eval{
		if(! -d $key_dir){	eval{mkdir($key_dir, 0755) || die "Could not create directory $key_dir: $!";};}
		opendir (DIR, "$key_dir") || die "Could not open directory: $key_dir.  $!.";
		my @dat_files = grep(/.dat/,readdir(DIR));
		closedir (DIR);
		foreach my $file(@dat_files){
			if($file !~ /sgd_/){
				unlink("$key_dir/$file") || die "Could not delete the .dat file: $file. $!.";
			}
		}
	};
	if($@){
		# the eval failed
		$error_log.="\nERROR!!!  Failure deleting .dat file(s).  Screen analysis tools will not be able to use the updated key files until these .dat files are deleted.  See error log for more details.\n\n";
	}
}

# move old key files to $key_dir/old, rename new key files so they no longer contain 'temp'
# accepts key_dir (where files are kept) as 1st input and array of file names to act on as second
sub moveOldRenameUpdated{
	my $key_dir=shift;
	my $file_names=shift;
	my $now=shift;
	# see if 'old' directory exists, if not create it
	eval{unless(-d "$key_dir/old"){mkdir("$key_dir/old", 0755) || die "Could not create directory $key_dir/old: $!";}};
	if($@){$error_log.="\nERROR!!! Could not create 'old' key file directory.  Updated key files not renamed and moved.  Key files older then 6 months not deleted.  See error log.\n\n";}

	foreach my $file(@$file_names){

		if(-e "$key_dir/$file"){
			# rename 'old' key files with date stamp
			rename("$key_dir/$file", "$key_dir/$now-$file") || die "Could not rename $key_dir/$file: $!";
			# move old key files to 'old' directory
			copy("$key_dir/$now-$file", "$key_dir/old/$now-$file") or die "copying of $now-$file to 'old' directory failed: $!";
			unlink("$key_dir/$now-$file");
		}
		# rename new files
		rename("$key_dir/temp-$file","$key_dir/$file");
	}
}

sub bookkeeper {
	my $dir=shift;
	my $age=shift;
	my $file;
	# Delete out old sessions that have been abandoned (ie have not been modified) for greater then 180 days
	opendir (DH,"$dir");
	while ($file = readdir DH) {
		# the next if line below will allow us to only consider files with extensions
		#next if ($file =~ /^\./);
		if(-d "$dir/$file"){rmdir("$dir/$file");} # rmdir will remove any empty directories
		if (-M "$dir/$file" > $age) {unlink "$dir/$file";}
	}
}

# re-create data structures
# this process is documented in screen-analysis1-1.cgi
sub createDAT{
	my $key_dir = shift;
	my $dat_key_dir = shift;
	my $file_names=shift;
	my ($iloop, $resthead, $head, @headers, @data, $data, $restinfo, $colindex, %keyinfo);
	my @head_order=('plate #','row','column');
	foreach my $file(@$file_names){
		%keyinfo=();
		my $key;
		#warn $file;
		open($key, "<$key_dir/$file") or die "Cannot open $key_dir/$file.  $!";
		$/ = line_break_check( $key );;
		$file=~ s/\.tab//; # strip out .tab
		# KEY is now a file handle to the key file that the user selected (if nothing went wrong)

		#--------------------------- START PROCESSING KEY FILE HEADERS --------------------------------
		($colindex,$resthead)=&processKeyHeader($key, $file, \@head_order,0); # colindex = hash reference with keys as head names, values = corresponding column number
		ROW:while(<$key>){
			chomp;
			@data=split /\t/;
			$restinfo="";
			if(!$data[$$colindex{'gene'}] || !$$colindex{'gene'}){
				use Data::Dumper;
				warn $file;
				warn Dumper($colindex);
				exit;
			}
			if($data[$$colindex{'column'}] eq '-'){next ROW;}
			unless($data[$$colindex{'gene'}]=~/BLANK/ ){ # do not store info for blank positions...
				foreach $data(@data){
					if($data ne $data[$$colindex{'plate #'}]&& $data ne $data[$$colindex{'row'}]&& $data ne $data[$$colindex{'column'}])
					{if(($data eq "" && $restinfo ne "") || $data ne ""){$restinfo.="$data\t";}}
				}
				$keyinfo{$data[$$colindex{'plate #'}]}->{$data[$$colindex{'row'}]}[$data[$$colindex{'column'}]]=$restinfo;
			}
			else{$keyinfo{$data[$$colindex{'plate #'}]}->{$data[$$colindex{'row'}]}[$data[$$colindex{'column'}]]="BLANK";}
		}
		eval {store(\%keyinfo, "$dat_key_dir/$file.dat")};
		if($@){ $error_log.= 'Serious error from Storable, storing %keyinfo: '.$@.'<br/>';}
		eval {store(\$resthead, "$dat_key_dir/$file-head.dat")};
		if($@){ $error_log.= 'Serious error from Storable, storing $resthead: '.$@.'<br/>';}
		close $key;
	}
}

sub send_result{
	my ($body,$from_address,$subject,$to_address)=@_;
	$from_address = 'web_tools@rothsteinlab.com' if(! defined $from_address);
 	$to_address = 'jcd2133@columbia.edu' if(! defined $to_address);
	$subject = "key file update ERROR" if(! defined $subject);

	eval{
		my $mailer = Mail::Mailer->new("sendmail");
		$mailer->open({	From	 	=> $from_address,
										To			=> $to_address,
										Subject	=> $subject,
									})
				or die "Can't open: $!\n";
		print $mailer $body;
		$mailer ->close();
	};
	if($@) {
		# the eval failed
		print "Could not send email. $@\n";
	}
	else{
		# the eval succeeded
		print "Success.\n";
	}
}

sub line_break_check{
	my $file = shift;
	local $/ = \1000; # read first 1000 bytes
	local $_ = <$file>; # read
	my ($newline) = /(\015\012?)/ ? $1 : "\012"; # Default to unix.
	seek $file,0,0; # rewind to start of file
 	return $newline;
}

sub freezeDownSGD_features{
	use JSON::JSON qw(encode);
	my $features = shift;
	my $key_dir = shift;
	my $error_log=shift;
	my (%sgd_all, %sgd_genes, %sgd_aliases);
	# create new hash that has orf as key and value = array with index 0 == gene name, 1 == alias, 2 == description
	foreach my $feature(@{$features}){
		foreach(keys %{$feature}){
			foreach my $guy(keys %{$feature->{$_}}){
				push(@{$sgd_all{$_}}, $guy);
			}
		}
	}
	foreach(keys %sgd_all){
		if($sgd_all{$_}[0]){
			$sgd_genes{$sgd_all{$_}[0]}=$_;
		}
		if($sgd_all{$_}[1]){
			foreach my $al(split(/\|/,$sgd_all{$_}[1])){
				$sgd_aliases{$al} = ($sgd_aliases{$al}) ? "$sgd_aliases{$al}|$_" : $_;
			}
		}
	}
	foreach(keys %sgd_all){
		if (scalar @{$sgd_all{$_}} != 3){
			$error_log.= 'Serious error from storing ORF '.$_.' in SGD hash: '.Dumper($sgd_all{$_}).'<br/>';
		}
	}


	if (-e "$key_dir/sgd_all.dat") {
		eval{unlink "$key_dir/sgd_all.dat" || die "Could not delete $key_dir/sgd_all.dat. $!.";};
		if($@){$error_log.="\nERROR!!!  Could not delete $key_dir/sgd_all.dat.  See error log for more details.\n\n";}
	}
	eval {store(\%sgd_all, "$key_dir/sgd_all.dat")};
	if($@){ $error_log.= 'Serious error from Storable, storing %sgd_all: '.$@.'<br/>';}

	if (-e "$key_dir/sgd_genes.dat") {
		eval{unlink "$key_dir/sgd_genes.dat" || die "Could not delete $key_dir/sgd_genes.dat. $!.";};
		if($@){$error_log.="\nERROR!!!  Could not delete $key_dir/sgd_genes.dat.  See error log for more details.\n\n";}
	}
	eval {store(\%sgd_genes, "$key_dir/sgd_genes.dat")};
	if($@){ $error_log.= 'Serious error from Storable, storing %sgd_genes: '.$@.'<br/>';}

	if (-e "$key_dir/sgd_aliases.dat") {
		eval{unlink "$key_dir/sgd_aliases.dat" || die "Could not delete $key_dir/sgd_aliases.dat. $!.";};
		if($@){$error_log.="\nERROR!!!  Could not delete $key_dir/sgd_aliases.dat.  See error log for more details.\n\n";}
	}
	eval {store(\%sgd_aliases, "$key_dir/sgd_aliases.dat")};
	if($@){ $error_log.= 'Serious error from Storable, storing %sgd_aliases: '.$@.'<br/>';}

	foreach(keys %sgd_all){pop @{$sgd_all{$_}};pop @{$sgd_all{$_}}; $sgd_all{$_}=	pop @{$sgd_all{$_}};}

	my $yeast_json = '../yeastData';
	if(! -d $yeast_json){	eval{mkdir($yeast_json, 0755) || die "Could not create directory $yeast_json: $!";};}
	$yeast_json .= '/yeastData.jsonp';
	open (my $json, '>', $yeast_json) or die "Cannot open file $yeast_json: $!\n";
	print $json  JSON->new->utf8->encode(\%sgd_all);
	close $json;
	undef %sgd_all; # forget %sgd ever existed
	undef %sgd_genes;
	undef %sgd_aliases;
	return $error_log;
}


# takes a table name and returns an array ref containing all of that table's column labels
# if it returns 0 it means that a table does not exist OR that we do not have permission to access it.
sub getColumnNamesAndTypes {
	my ($dbh, $table, $db) = @_;
	# $dbh->{TraceLevel} = 3;
	my $sth;
	eval{	$sth = $dbh->column_info( undef, $db, "$table", '%' );	};
	if ($sth->err) {$sth->finish(); return 0;}
	my $ref = $sth->fetchall_arrayref;
	# build a hash with column labels as keys and column types as values
	my $i = 0;
	my %temp;
	# 2 = table name, 3 = column name, 4 = ? 5 = data type, 6 = size
	foreach(@{$ref}){	$temp{uc($_->[3])} = uc("SQL_$_->[5]");	$i++;}
	$sth->finish();
	if($i < 1){die "Could not find columns for table: $table";}
	return \%temp;
}

sub setupMySQLinsert{
	my ($table_name, $cols, $limit) = @_;
	my $mySQLst = "INSERT INTO `$table_name` (`".join('`,`', @{$cols})."`) VALUES ";
	my $inserts = '('.join(', ', ('?') x  @{$cols} ). '),';
	$mySQLst .=  $inserts x $limit;
	my $onDupKeySyntax = '';
	for(my $j=0; $j < @{$cols}; $j++){		$onDupKeySyntax.= "`$cols->[$j]`=VALUES(`$cols->[$j]`), ";	}
	$onDupKeySyntax =~ s/,*\s*$//;
	$mySQLst =~ s/,\s*$//; # remove trailing comma and space
	$mySQLst =~ s/, $//; # remove trailing comma and space
	$mySQLst .= " ON DUPLICATE KEY UPDATE $onDupKeySyntax";
	return $mySQLst;
}