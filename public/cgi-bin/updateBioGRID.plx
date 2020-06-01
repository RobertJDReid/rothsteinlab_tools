#!/usr/bin/perl -w

BEGIN {
  my $log;
  use CGI::Carp qw(carpout);
  open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
  carpout($log);
  $|=1;
}

use strict;
use LWP::Simple; # needed to retrieve website
use Storable qw(store retrieve); # to store / retrieve data structures on disk
use Mail::Mailer;
use Modules::ScreenAnalysis qw(:sqlOnly);
use DBI qw(:sql_types);

# ******************* VARIABLE DECLARATIONS ********************
my %sqlTypes = (q
  "SQL_VARCHAR"   => \&SQL_VARCHAR,
  "SQL_DATE"      => \&SQL_DATE,
  "SQL_BLOB"      => \&SQL_BLOB,
  "SQL_TINYINT"   => \&SQL_TINYINT,
  "SQL_DOUBLE"    => \&SQL_DOUBLE,
  "SQL_INTEGER"   => \&SQL_INTEGER,
  "SQL_TEXT"      => \&SQL_CLOB,
  "SQL_TIMESTAMP" => \&SQL_TIMESTAMP,
  "SQL_DATETIME"  => \&SQL_DATETIME,
  "SQL_BIGINT"    => \&SQL_BIGINT,
  "SQL_FLOAT"     => \&SQL_FLOAT,
  "SQL_TIME"      => \&SQL_TIME,
  "SQL_INT"       => \&SQL_INTEGER
);
my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
my $year = 1900 + $yearOffset;
$month++;
my $now = "$year-$month-$dayOfMonth";

# warn "Validate API before proceeding!";
# exit(0);

# if this is true, attempt to pull data from the web api. Otherwise use files.
my $useAPI = 1;

my $version = '';
my ($accessKey, $biogridVersionURL);
if($useAPI){
  $accessKey = '20fa3c16b80d2d78bb8dda61cc2a1087';
  $biogridVersionURL = 'http://webservice.thebiogrid.org/resources/version?accessKey='.$accessKey;
  $version='';
  unless ($version=get($biogridVersionURL)) {
    &exit_program_with_error("Could not get $biogridVersionURL\n");
  }
}
else{
  # manually set version
  $version = '3.2.120';#get($biogridVersionURL);
}

chomp($version);
open(VER, ">interactionData/BioGRID/biogrid_versionNumber.txt") or die "interactionData/BioGRID/biogrid_versionNumber.txt.  $!";
print VER $version;
close VER;

# data returned is tab delimited - the data columns are:
my %bioGRID_colindex = (
    'BioGRID Interaction ID' => 0,
    'Entrez Gene Interactor A' => 1,
    'Entrez Gene Interactor B' => 2,
    'BioGRID ID Interactor A' => 3,
    'BioGRID ID Interactor B' => 4,
    'Systematic Name Interactor A' => 5,
    'Systematic Name Interactor B' => 6,
    'Official Symbol Interactor A' => 7,
    'Official Symbol Interactor B' => 8,
    'Synonymns Interactor A (optional, multiples separated by |)' => 9,
    'Synonymns Interactor B (optional, multiples separated by |)' => 10,
    'Experimental System' => 11, # (e.g. synthetic lethality, Positive Genetic, two-hybrid, FRET)
    'Experimental System Type' => 12, # e.g. Genetic or Physical
    'Author' => 13,
    'Pubmed ID' => 14,
    'Organism Interactor A' => 15,
    'Organism Interactor B' => 16,
    'Throughput' => 17, # eg high or low
    'Score' => 18,
    'Modification' => 19,
    'Phenotypes' => 20,
    'Qualifications' => 21,
    'Tags' => 22,
    'Source Database' => 23
);

my $change_log="";

# keys = filename we will save data to, values = NCBI tax id for the organism
my %dataToUpdate = ();

if($useAPI){
  %dataToUpdate = ( 'Scerevisiae' => {'primary' => 559292, 'alternates' => {} }, #4932,
                    'Hsapien'     => {'primary' => 9606,   'alternates' => {} },
                    'Spombe'      => {'primary' => 4896,   'alternates' => {284812 => 1} }
                     # 'Dmelanogaster' => 7227,
                     # 'Mmusculus' => 10090,
                     # 'Celegans' => 6239,
                     # 'Athaliana' => 3702
                    );
}
else{
  # keys = filename we will save data to, values = NCBI tax id for the organism
  %dataToUpdate = (  'Scerevisiae' => {'primary' => 'BIOGRID-ORGANISM-Saccharomyces_cerevisiae-3.2.120.tab2.txt'},
                     'Hsapien'     => {'primary' => 'BIOGRID-ORGANISM-Homo_sapiens-3.2.120.tab2.txt'},
                     'Spombe'      => {'primary' => 'BIOGRID-ORGANISM-Schizosaccharomyces_pombe-3.2.120.tab2.txt'}
                     # 'Dmelanogaster' => 7227,
                     # 'Mmusculus' => 10090,
                     # 'Celegans' => 6239,
                     # 'Athaliana' => 3702
                    );
}

foreach my $fileName(keys %dataToUpdate){
  my $taxID = $dataToUpdate{$fileName}->{'primary'};

  if($fileName =~ /Hsapien/i){
    $bioGRID_colindex{'Systematic Name Interactor A'} = $bioGRID_colindex{'Official Symbol Interactor A'},
    $bioGRID_colindex{'Systematic Name Interactor B'} = $bioGRID_colindex{'Official Symbol Interactor B'},
  }
  else{
    $bioGRID_colindex{'Systematic Name Interactor A'} = 5;
    $bioGRID_colindex{'Systematic Name Interactor B'} = 6;
  }

  my $tableName = lc($fileName)."_bioGrid_interactions";
  my $mySQLconnection = &connectToMySQL();
  if(!$mySQLconnection){
    &exit_program_with_error("Error connecting to mySQL when analyzing  $tableName\n",$mySQLconnection);
  }

  my $limit = 40;
  my ($insertStatement,$mySQLcolNames) = &prepInsertStatement($mySQLconnection,$tableName, $limit);

  my (%counted_interactions, %interactions, %sources, %systems) = ((),(),(),());
  # warn "getting $tableName -- 1st call";

  my $interactionsProcessed=0;
  if($useAPI){
    $interactionsProcessed+=&processDataUsingAPI($dataToUpdate{$fileName}, $accessKey, $insertStatement,$mySQLconnection,$mySQLcolNames,$limit,\%bioGRID_colindex,\%counted_interactions, \%interactions, \%sources, \%systems);
  }
  else{
    # taxID is really the filename when processing data from file
    $interactionsProcessed+=&processDataFromFile($taxID, $insertStatement,$mySQLconnection,$mySQLcolNames,$limit,\%bioGRID_colindex, \%counted_interactions, \%interactions, \%sources, \%systems);
  }

  $insertStatement->execute() || warn "cannot update $DBI::errstr";
  $insertStatement->finish();
  $mySQLconnection->commit();
  $mySQLconnection->disconnect();

  if($interactionsProcessed == 0 ){
    # file could not be retrieved from FTP address...
    my $msg = "Error processing $taxID - no interactions processed. $!\n$change_log";
    &exit_program_with_error($msg,$mySQLconnection);
  }

  open(ITYPES, ">interactionData/BioGRID/$fileName\_interactionTypes.txt") or die "interactionData/BioGRID/$fileName\_interactionTypes.txt.  $!";
  foreach my $expSystemType(sort keys %systems){
    foreach my $system(sort keys %{$systems{$expSystemType}}){
      print ITYPES "$expSystemType:$system\n";
    }
  }
  close ITYPES;
  $change_log.="$fileName ($taxID) BioGRID (v $version) data downloaded successfully (# interactions = $interactionsProcessed)!!!\n\n";
  &saveStructures(\%counted_interactions, \%interactions, \%sources, \%systems, $fileName);
  # warn "done with $fileName";

  &updateVersion($fileName,$version);
}
print "Success";
# send results via email...
my $from_address = 'web_tools@rothsteinlab.com';
my $to_address   = 'jcd2133@columbia.edu';
my $subject      = "biogrid file update status";
my $body         ="CHANGE LOG:\n$change_log\n\n\n";
&send_result($body,$from_address,$subject,$to_address);

sub updateVersion {
  my($organism,$version) = @_;
  my $SQL = "update `supported_organisms` set biogrid_version = '$version' where `organism`='$organism'";
  my $dbh = &connectToMySQL();
  $dbh->do($SQL);
  $dbh->commit();
  $dbh->disconnect()
}

# save data structures to disk
sub saveStructures{
  my ($counted_interactions, $interactions, $sources, $systems, $shortName)=@_;

  my $base = 'interactionData/savedStructures';
  eval{mkdir($base, 0755) || die "Could not create directory $base: $!";};
  $base .= '/BioGRID';
  eval{mkdir($base, 0755) || die "Could not create directory $base: $!";};

  eval{store($counted_interactions, "$base/$shortName"."_counted_interactions.dat")};
  if($@){die "Serious error from Storable storing $shortName"."_counted_interactions.dat: $@";}
  eval{store($interactions, "$base/$shortName"."_interactions.dat")};
  if($@){die "Serious error from Storable storing $shortName"."_interactions.dat: $@";}
  eval{store($sources, "$base/$shortName"."_sources.dat")};
  if($@){die "Serious error from Storable storing $shortName"."_all_sources.dat: $@";}
  eval{store($systems, "$base/$shortName"."_systems.dat")};
  if($@){die "Serious error from Storable storing $shortName"."_all_systems.dat: $@";}
  return 1;
}

sub buildURL{
  my ($taxID, $start, $numberToRetreive, $accessKey) = @_;
  return "http://webservice.thebiogrid.org/resources/interactions/?taxId=$taxID&start=$start&max=$numberToRetreive&interSpeciesExcluded=true&includeEvidence=true&format=tab2&accessKey=$accessKey";
}

sub exit_program_with_error {
  my($msg,$dbh) = @_;
  if($dbh){
    $dbh->rollback();
    $dbh->disconnect();
  }
  &send_result($msg);
  die $msg;
}

sub send_result{
  my ($body,$from_address,$subject,$to_address)=@_;
  $from_address = 'web_tools@rothsteinlab.com' if(! defined $from_address);
  $to_address   = 'jcd2133@columbia.edu' if(! defined $to_address);
  $subject      = "update biogrid ERROR!" if(! defined $subject);
  eval{
    my $mailer = Mail::Mailer->new("sendmail");
    $mailer->open({ From    => $from_address,
                    To      => $to_address,
                    Subject => $subject,
                  })
        or die "Can't open: $!\n";
    print $mailer $body;
    $mailer ->close();
  };
  if($@) { print "Could not send email. $@\n"; }
  return 1;
}

# takes a table name and returns an array ref containing all of that table's column labels
# if it returns 0 it means that a table does not exist OR that we do not have permission to access it.
sub getColumnNamesAndTypes {
  my ($dbh, $table) = @_;
  my $sth;
  my $db = $dbh->selectrow_array("select DATABASE()");
  eval{ $sth = $dbh->column_info( undef, $db, "$table", '%' );  };
  if ($sth->err) {$sth->finish(); return 0;}
  my $ref = $sth->fetchall_arrayref;
  # build a hash with column labels as keys and column types as values
  my $i = 0;
  my %temp;
  # 2 = table name, 3 = column name, 4 = ? 5 = data type, 6 = size
  foreach(@{$ref}){ $temp{uc($_->[3])} = uc("SQL_$_->[5]"); $i++;}
  $sth->finish();
  if($i < 1){die "Could not find columns for table: $table";}
  return \%temp;
}


sub processLine {
  my ($line, $bioGRID_colindex, $mySQLconnection, $insertStatement, $mySQLcolNames, $interactionsProcessed, $limit, $i, $iterator, $counted_interactions, $interactions, $sources, $systems, $taxID, $alternates) = @_;
  chomp ($line);
  # capitalize everything except for experimental system
  my @data=split /\t/, $line;
  my $expSystem = $data[$bioGRID_colindex->{'Experimental System'}];
  @data = map { uc $_ } @data; # uppercase all the data
  # check to make sure it is a valid interaction
  if (
        $taxID > 0 &&
        ($data[$bioGRID_colindex->{'Organism Interactor A'}] ne $taxID || $data[$bioGRID_colindex->{'Organism Interactor B'}] ne $taxID) &&
        (!defined($alternates->{$data[$bioGRID_colindex->{'Organism Interactor A'}]}) || !defined($alternates->{$data[$bioGRID_colindex->{'Organism Interactor B'}]}) )
     ) {
    my $msg = "Error! tax Id does not match. Looking for $taxID, found $data[$bioGRID_colindex->{'Organism Interactor A'}] (Organism Interactor A) & $data[$bioGRID_colindex->{'Organism Interactor B'}] (Organism Interactor B)";
    &exit_program_with_error($msg,$mySQLconnection);
  }
  elsif($data[$bioGRID_colindex->{'Systematic Name Interactor A'}]              # if A and B both exist and are not '' and both A & B are in dataset then add to data structure
     && $data[$bioGRID_colindex->{'Systematic Name Interactor A'}] ne ''
     && $data[$bioGRID_colindex->{'Systematic Name Interactor B'}]
     && $data[$bioGRID_colindex->{'Systematic Name Interactor B'}] ne '' ){
      $data[$bioGRID_colindex->{'Systematic Name Interactor A'}] =~ s/^Dmel_//i;
      $data[$bioGRID_colindex->{'Systematic Name Interactor B'}] =~ s/^Dmel_//i;
      $interactions->{$data[$bioGRID_colindex->{'Systematic Name Interactor A'}]}->{$data[$bioGRID_colindex->{'Systematic Name Interactor B'}]}->{$data[$bioGRID_colindex->{'Throughput'}]}->{$data[$bioGRID_colindex->{'Experimental System Type'}]}->{$data[$bioGRID_colindex->{'Experimental System'}]}->{$data[$bioGRID_colindex->{'Pubmed ID'}]}++;
      $sources->{$data[$bioGRID_colindex->{'Pubmed ID'}]}++;
      $systems->{$data[$bioGRID_colindex->{'Experimental System Type'}]}->{$expSystem}++;
      $counted_interactions->{[$bioGRID_colindex->{'Systematic Name Interactor A'}]}->{[$bioGRID_colindex->{'Systematic Name Interactor B'}]}++;
      $insertStatement->bind_param( (++$i),  $data[$bioGRID_colindex->{'Systematic Name Interactor A'}], $sqlTypes{$mySQLcolNames->{'INTA'}}->() );
      $insertStatement->bind_param((++$i),  $data[$bioGRID_colindex->{'Systematic Name Interactor B'}], $sqlTypes{$mySQLcolNames->{'INTB'}}->());
      $insertStatement->bind_param((++$i),  $data[$bioGRID_colindex->{'Throughput'}], $sqlTypes{$mySQLcolNames->{'THROUGHPUT'}}->());
      $insertStatement->bind_param((++$i),  $data[$bioGRID_colindex->{'Experimental System Type'}], $sqlTypes{$mySQLcolNames->{'EXPSYSTEMTYPE'}}->());
      $insertStatement->bind_param((++$i),  $expSystem, $sqlTypes{$mySQLcolNames->{'EXPSYSTEM'}}->());
      $insertStatement->bind_param((++$i),  $data[$bioGRID_colindex->{'Pubmed ID'}], $sqlTypes{$mySQLcolNames->{'PUBMEDID'}}->());
      $iterator++;
      if($iterator >= $limit){
        $insertStatement->execute() || warn "cannot update $DBI::errstr";
        $i=0;
        $iterator=0;
      }
      $interactionsProcessed++;
      return ($interactionsProcessed,$iterator,$i);
  }#  end if
  return ($interactionsProcessed,$iterator,$i);
}


sub prepInsertStatement {
  my ($mySQLconnection, $tableName, $limit) = @_;
  my $mySQLcolNames = &getColumnNamesAndTypes($mySQLconnection, $tableName);
  my @dataOrder = ('`intA`','`intB`','`throughput`', '`expSystemType`', '`expSystem`', '`pubmedID`');
  my $inserts = '('.join(', ', ('?') x  @dataOrder ). '),';
  my $insertStatement = "INSERT INTO `$tableName` (".join(", ", @dataOrder).") VALUES ";
  $insertStatement .=  $inserts x $limit;
  $insertStatement =~ s/,\s*$//; # remove trailing comma and space
  my $onDupKeySyntax='';
  for (my $i = 0; $i < @dataOrder; $i++) {  $onDupKeySyntax.="$dataOrder[$i]=VALUES($dataOrder[$i]), "; }
  $onDupKeySyntax =~ s/,*\s*$//;
  $insertStatement .= " ON DUPLICATE KEY UPDATE $onDupKeySyntax";
  $insertStatement = $mySQLconnection->prepare( $insertStatement );
  return ($insertStatement,$mySQLcolNames);
}


sub processDataUsingAPI {
  my ($taxIDs,$accessKey, $insertStatement,$mySQLconnection,$mySQLcolNames, $limit, $bioGRID_colindex, $counted_interactions, $interactions, $sources, $systems) = @_;

  my $taxID                 = $taxIDs->{'primary'};
  my $numberToRetreive      = 10000;
  my $totalRecords          = 0;
  my $interactionsProcessed = 0;
  my $totalRecordsURL       = "http://webservice.thebiogrid.org/resources/interactions/?taxId=$taxID&format=count&accessKey=$accessKey";
  unless ($totalRecords=get($totalRecordsURL)) {  &exit_program_with_error("Could not get $totalRecordsURL.\n");  }
  chomp($totalRecords);
  # warn 'total records = '.$totalRecords;
  # record start # -- need to paginate over results in order to grab everything
  my ($start, $biogridRESTurl) = (0,'');
  $biogridRESTurl = &buildURL($taxID, $start, $numberToRetreive, $accessKey);
  $change_log.="Downloading data from $biogridRESTurl...\n";
  my $content=get($biogridRESTurl);
  my $totalRecordsPulled=0;
  my ($i, $iterator)=(0,0);
  while(defined $content && $content ne ''){
    my @lines = split /\n/, $content; $content = '';
    foreach my $line(@lines){
      $totalRecordsPulled++;
      $counted_interactions=();
      ($interactionsProcessed,$iterator,$i)=&processLine($line, $bioGRID_colindex, $mySQLconnection, $insertStatement, $mySQLcolNames, $interactionsProcessed, $limit, $i, $iterator, $counted_interactions, $interactions, $sources, $systems, $taxID, $taxIDs->{'alternates'});
    }  # end foreach
    $start += $numberToRetreive;
    $biogridRESTurl = &buildURL($taxID, $start, $numberToRetreive, $accessKey);
    # warn "about to get->$taxID -> $start";

    if($totalRecordsPulled > $totalRecords){
      my $msg = "Too many records pulled. Expected $totalRecords, pulled $totalRecordsPulled (taxID = $taxID).\nLast url = $biogridRESTurl";
      &exit_program_with_error($msg,$mySQLconnection);
    }
    # warn $biogridRESTurl;
    $content=get($biogridRESTurl);
    # warn "$taxID -> $interactionsProcessed interactions processed. [start = $start]";
  }
  return $interactionsProcessed;
}

sub processDataFromFile {
  my ($fileName, $insertStatement,$mySQLconnection, $mySQLcolNames, $limit, $bioGRID_colindex, $counted_interactions, $interactions, $sources, $systems) = @_;
  my $data;
  open($data, "<$fileName") or die "Cannot open $fileName.  $!";
  $/ = line_break_check( $data );

  $change_log.="Downloading data from $fileName...\n";
  my $interactionsProcessed=0;
  my ($i, $iterator)=(0,0);

  my $header=<$data>;
  my $linesProcessed=0;
  while(<$data>){
    my $line = $_;
    $linesProcessed++;
    ($interactionsProcessed,$iterator,$i)=&processLine($line, $bioGRID_colindex, $mySQLconnection, $insertStatement, $mySQLcolNames, $interactionsProcessed, $limit, $i, $iterator, $counted_interactions, $interactions, $sources, $systems,-1, -1);
    if($linesProcessed > 50000){
      # warn "interactions processed = $interactionsProcessed";
      $linesProcessed=0;
      sleep(5); # not sure why this line is here
    }
  }
  return $interactionsProcessed;
}

sub line_break_check{
  my $file = shift;
  local $/ = \1000; # read first 1000 bytes
  local $_ = <$file>; # read
  my ($newline) = /(\015\012?)/ ? $1 : "\012"; # Default to unix.
  seek $file,0,0; # rewind to start of file
  return $newline;
}