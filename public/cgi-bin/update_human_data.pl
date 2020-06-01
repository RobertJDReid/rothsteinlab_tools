#!/usr/bin/perl -w

# this script pulls data from ensembl and updates the ensembl id table and the human yeast ortholog table
# 


use strict;
use LWP::UserAgent;
use Mail::Mailer;
use Data::Dumper;
use Modules::ScreenAnalysis qw(:sqlOnly); # use my module and only load routines in analysis
use DateTime;
&updateHumanGenesWithEnsemblData();
&checkEnsemblVersionVsMySQL_db();
&updateHumanAndYeastOrthologs();
exit;
&send_result("Successfully updated Ensembl data and Ensembl yeast orthologs!","Successfully updated Ensembl data and Ensembl yeast orthologs!");


sub parseOldData{
	my $fileName = shift;
	my $in;
	if (-e "$fileName") {
		open ($in, '<', $fileName) or die "Cannot open file ($fileName): $!\n";	
		$/ = line_break_check( \*$in );
		my %allData;
		while(<$in>){
			chomp;
			my @line = split("\t");
			$allData{$line[0]}=$_
		}
		return \%allData;
	}
	return {};
}

sub getHumanProteinsWithYeastOrthologs{
# below is the XML need to pull all human gene names / ids / descriptions and there yeast orthologs (orfs), if they exist
	 my $xml = (<<XXML);
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "0" count = "" datasetConfigVersion = "0.8" >
	<Dataset name = "hsapiens_gene_ensembl" interface = "default" >
		<Filter name = "biotype" value = "protein_coding"/>
		<Attribute name = "ensembl_gene_id" />
		<Attribute name = "external_gene_id" />
		<Attribute name = "scerevisiae_homolog_ensembl_gene" />
		<Attribute name = "scerevisiae_homolog_perc_id" />
		<Attribute name = "scerevisiae_homolog_perc_id_r1" />
		<Attribute name = "scerevisiae_homolog_orthology_type" />
		<Attribute name = "scerevisiae_inter_paralog_ensembl_gene" />
		<Attribute name = "scerevisiae_inter_paralog_orthology_type" />
		<Attribute name = "scerevisiae_inter_paralog_perc_id" />
		<Attribute name = "scerevisiae_inter_paralog_perc_id_r1" />
	</Dataset>
</Query>
XXML
return &runBioMartAPI_request($xml);
}

sub getAllHumanGenes{
	my $fileName = shift;
	my $xml = (<<XXML);
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Query>
<Query  virtualSchemaName = "default" formatter = "TSV" header = "0" uniqueRows = "0" count = "" datasetConfigVersion = "0.8" >
	<Dataset name = "hsapiens_gene_ensembl" interface = "default" >
		<Attribute name = "ensembl_gene_id" />
		<Attribute name = "gene_biotype" />
		<Attribute name = "external_gene_id" />
		<Attribute name = "description" />
		<Attribute name = "transcript_count" />
	</Dataset>
</Query>
XXML
return &runBioMartAPI_request($xml,$fileName);
}

sub runBioMartAPI_request{
	my ($xml, $fileName)=@_;
	my $path="http://useast.ensembl.org/biomart/martservice?";
	my $request = HTTP::Request->new("POST",$path,HTTP::Headers->new(),'query='.$xml."\n");
	my $ua = LWP::UserAgent->new;
	my $allData='';
	if($fileName){	open (OUT, '>', $fileName) or die "Cannot open file ($fileName): $!\n";	}
	$ua->request($request,
		sub{
			my($data, $response) = @_;
			if ($response->is_success) {	
				$allData.=$data;
				print OUT $data if($fileName);
			}
			else {	
				warn ("Problems with the web server: ".$response->status_line);	
				&send_result("Problems with the web server: ".$response->status_line);
				exit;
			}
		},1000);
	if($fileName){	close OUT;	}
	my @data = split("\n", $allData);
	return (\@data, scalar(@data));
}

# this sub is using the actual ensembl rest service
sub getCurrentEnsemblVersion{
	use JSON;
	my $server = 'http://beta.rest.ensembl.org';
	my $ext = '/info/software?';
	my $ua = LWP::UserAgent->new;
	my $response = $ua->get($server.$ext, 'Content-type' => 'application/json' );
	unless ($response->is_success){	
		warn ("Problems with REST server: ".$response->status_line);
		&send_result("Problems with rest server pulling Ensembl version #: ".$response->status_line);
		exit;
	}
	
	if(length $response->content) {	return decode_json($response->content);	}
	else{
		warn ("Problems with REST server: ".$response->status_line);	
		&send_result("Problems with rest server pulling Ensembl version # (no content)");
		exit;
	}
}

sub send_result{
	my ($body,$subject,$from_address,$to_address)=@_;
	$from_address = 'web_tools@rothsteinlab.com' if(! defined $from_address);
 	$to_address = 'jcd2133@columbia.edu' if(! defined $to_address);
	$subject = "ENSEMBL data sync ERROR" if(! defined $subject);
	
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

sub prepSqlStatement{
	my ($fields, $tn, $limit) = @_;

	my $mySQLst = "INSERT INTO `$tn` (`".join('`, `',@{$fields})."`) VALUES ";
	my @placeHolders = ('?') x scalar(@{$fields});
	my $placeHolders = join(',',@placeHolders);
	$mySQLst .= "($placeHolders), " x $limit;
	$mySQLst =~ s/, $//; # remove trailing comma and space
	$mySQLst.=" ON DUPLICATE KEY UPDATE ";
	if($tn =~ /scerevisiae_hsapien_orthologs/i){
		foreach my $field(@{$fields}){
			# only update homologyType if 
			if($field eq 'homologyType'){
				$mySQLst.= "`$field` = IF( INSTR(`$field`,VALUES(`$field`) ) > 0, `$field`,CONCAT(`$field`,'|',VALUES(`$field`))), ";
			}
			elsif($field eq 'source'){
				$mySQLst.= "`$field` = IF( INSTR(`$field`,VALUES(`$field`) ) > 0, `$field`,CONCAT(`$field`,'|',VALUES(`$field`))), ";
			}
			else{$mySQLst.= "`$field`=VALUES(`$field`), ";}
		}
	}
	else{
		foreach my $field(@{$fields}){$mySQLst.= "`$field`=VALUES(`$field`), ";}
	}
	$mySQLst =~ s/, $//; # remove trailing comma and space
	return $mySQLst;
}

sub checkEnsemblVersionVsMySQL_db{
	my $currentVersion = &getCurrentEnsemblVersion();
	warn "Current Release = $currentVersion->{release}";
	my $dbh = &connectToMySQL();
	my $sth = $dbh->prepare('SELECT * FROM `ensembl_version` WHERE `id`=1');
	$sth->execute();
	my $result = $sth->fetchrow_hashref();
	warn "\nValue returned: $result->{syncedVersionNumber}\n";

	#if($result->{syncedVersionNumber} eq $currentVersion->{release}){
		$sth->finish();
		
	  my $now = DateTime->now->datetime;
	  $now =~ y/T/ /;
		my $SQL= "update `ensembl_version` set dateLastSynced = '$now' where `id`=1";
		$dbh->do($SQL);
		$SQL= "update `ensembl_version` set syncedVersionNumber = '$currentVersion->{release}' where `id`=1";
		$dbh->do($SQL);
		$dbh->commit();
		if($dbh){$dbh->disconnect() || warn "Disconnection error: $DBI::errstr\n";}
	# }
	# else{
	# 	if($dbh){$dbh->disconnect() || warn "Disconnection error: $DBI::errstr\n";}
	# 	warn "crap!";
	# 	warn ("MySQL ensembl version differs from current version!");	
	# 	&send_result("ERROR! MySQL ensembl version differs from current version! What to do???");
	# 	exit;
	# }
}


sub updateHumanGenesWithEnsemblData{
	my $dbh = &connectToMySQL();

	my $allDataFile = 'ensembl/allHumanGenes_ensembl.txt';
	my $oldEnsemblData = &parseOldData($allDataFile);
	my ($humanGenes, $humanGeneCount) = &getAllHumanGenes($allDataFile);
	my $now = DateTime->now->datetime;
	$now =~ y/T/ /;
	my $limit = 40;
	# setup statement to insert $limit records at a time
	my @fields = qw(ensemblID geneBioType geneName description numberOfTranscripts updated_at created_at);
	my $tableName = 'hsapien_ensembl_genes';
	my $mySQLst = &prepSqlStatement(\@fields, $tableName, $limit);
	# prepare MySQL insert statement
	my $insertMySQLsth = $dbh->prepare( $mySQLst ) || die "Can't prepare a statement: $DBI::errstr";

	my $iterator=0;
	my $placeHolder=1;
	my $diffCount=0;
	for(my $i=0;$i<$humanGeneCount;$i++){
		chomp($humanGenes->[$i]);

		my @line = split(/\t/,$humanGenes->[$i]);
		&trimErroneousCharacters(\@line);

		if($oldEnsemblData && defined $oldEnsemblData->{$line[0]}){	if($humanGenes->[$i] ne $oldEnsemblData->{$line[0]}){$diffCount++;}	}
		else{$diffCount++;}

		# within @line the indices are...
		# 0 --> human ensembl_gene_id (ensembl id)
		# 1 --> Gene BioType (e.g. protein encoding, mRNA, snoRNA)
		# 2 --> human external_gene_id (ie human gene name)
		# 3 --> human gene description (if available)
		# 4 --> transcript count -- number of different transcripts associated with this gene
		if(defined $line[0]){	$insertMySQLsth->bind_param($placeHolder++, $line[0]);	}
		else{$insertMySQLsth->bind_param($placeHolder++, "");}
		if(length($line[1])>25){warn "$line[1], length = ".length($line[1]);}
		if(defined $line[1]){	$insertMySQLsth->bind_param($placeHolder++, $line[1]);	}
		else{$insertMySQLsth->bind_param($placeHolder++, "");}
		if(defined $line[2]){	$insertMySQLsth->bind_param($placeHolder++, $line[2]);	}
		else{$insertMySQLsth->bind_param($placeHolder++, "");}
		if(defined $line[3]){	$insertMySQLsth->bind_param($placeHolder++, $line[3]);	}
		else{$insertMySQLsth->bind_param($placeHolder++, "");}
		if(defined $line[4]){	$insertMySQLsth->bind_param($placeHolder++, $line[4]);	}
		else{$insertMySQLsth->bind_param($placeHolder++, "");}

		$insertMySQLsth->bind_param($placeHolder++, $now);
		$insertMySQLsth->bind_param($placeHolder++, $now);

		$iterator++;
		if($iterator >= $limit){
			$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
			$placeHolder=1;
			$iterator=0;
			$dbh->commit();
		}
	}
	$insertMySQLsth->execute() || die "cannot update $DBI::errstr";
	$insertMySQLsth->finish();
	$dbh->do("ALTER TABLE `$tableName` AUTO_INCREMENT = 1");
	$dbh->commit();
	if($dbh){$dbh->disconnect() || warn "Disconnection error: $DBI::errstr\n";}
	warn "diffCount = $diffCount";
}

sub updateHumanAndYeastOrthologs{

	my $currentVersion = &getCurrentEnsemblVersion();
	my $dbh = &connectToMySQL();
	#$dbh->{TraceLevel} = 2;
	my ($orthologData, $rowCount) = &getHumanProteinsWithYeastOrthologs();

	my $now = DateTime->now->datetime;
	$now =~ y/T/ /;

	my $limit = 40;
	# setup statement to insert $limit records at a time
	my @fields = qw(humanEnsemblID humanGeneName yeastOrf percentIdentityWithRespectToQueryGene percentIdentityWithRespectToYeastGene homologyType source updated_at created_at created_by updated_by approved);
	my $tableName = 'scerevisiae_hsapien_orthologs';
	my $mySQLst = &prepSqlStatement(\@fields, $tableName, $limit);
	# prepare MySQL insert statement
	my $insertMySQLsth = $dbh->prepare( $mySQLst ) || die "Can't prepare a statement: $DBI::errstr";

	my $iterator=0;
	my $placeHolder=1;
	my $diffCount=0;

	for(my $i=0;$i<$rowCount;$i++){
		chomp($orthologData->[$i]);
		my @line = split(/\t/,$orthologData->[$i]);
		&trimErroneousCharacters(\@line);
		# Possible orthologues are homologues between species where the common ancestor is a weakly supported duplication event. 
		# Although they should be called paralogues according to the Compara rules, the low confidence on the duplication node might suggest an error in the phylogenetic reconstruction.
		# We list these cases here as they might be real orthologues, especially in cases where no better orthologue is found.
		# within @line the indices are...
		# 0 --> human ensembl_gene_id (ensembl id)
		# 1 --> human external_gene_id (ie human gene name)
		# 2 --> yeast orf (if there is an ortholog)
		# 3 --> % Identity with respect to query gene
		# 4 --> % Identity with respect to Yeast gene
		# 5 --> scerevisiae_homolog_orthology_type (i.e. 1-to-1 orthologues: only one copy is found in each species, 1-to-many orthologues: one gene in one species is orthologous to multiple genes in another species, Many-to-many orthologues: multiple orthologues are found in both species)
		# 6 --> scerevisiae_inter_paralog_ensembl_gene == possible ortholog
		# 7 -->  scerevisiae_inter_paralog_orthology_type == possible ortholog
		# 8 --> % Identity with respect to query gene == possible ortholog
		# 9 --> % Identity with respect to Yeast gene == possible ortholog

		my ($yGene, $hType, $percentToQuery, $percentToYeast) = (undef,'','','');
		# first check if there is a direct yeast ortholog
		if(defined $line[2] && $line[2] ne ''){
			$yGene = $line[2];
			$percentToQuery = (defined $line[3]) ? $line[3] : '';
			$percentToYeast = (defined $line[4]) ? $line[4] : '';
			$hType = (defined $line[5]) ? $line[5] : '';
		}
		# else check if there is a possible ortholog
		elsif(defined $line[6] && $line[6] ne ''){
			$yGene = $line[6];
			$percentToQuery = (defined $line[8]) ? $line[8] : '';
			$percentToYeast = (defined $line[9]) ? $line[9] : '';
			$hType = (defined $line[7]) ? $line[7] : '';
		}
		if($yGene){
			#	human ensembl_gene_id (ensembl id)
			if(defined $line[0]){	$insertMySQLsth->bind_param($placeHolder++, $line[0]);	}
			else{$insertMySQLsth->bind_param($placeHolder++, "");}

			# human external_gene_id (ie human gene name)
			if(defined $line[1]){	$insertMySQLsth->bind_param($placeHolder++, $line[1]);	}
			else{$insertMySQLsth->bind_param($placeHolder++, "");}

			$insertMySQLsth->bind_param($placeHolder++, $yGene);
			$insertMySQLsth->bind_param($placeHolder++, $percentToQuery);
			$insertMySQLsth->bind_param($placeHolder++, $percentToYeast);
			$insertMySQLsth->bind_param($placeHolder++, $hType);
			$insertMySQLsth->bind_param($placeHolder++, "Ensembl V$currentVersion->{release}");
			$insertMySQLsth->bind_param($placeHolder++, $now);
			$insertMySQLsth->bind_param($placeHolder++, $now);
			$insertMySQLsth->bind_param($placeHolder++, 'script');
			$insertMySQLsth->bind_param($placeHolder++, 'script');
			$insertMySQLsth->bind_param($placeHolder++, 1);
			
			$iterator++;
			if($iterator >= $limit){
				$insertMySQLsth->execute() || warn "cannot update $DBI::errstr";
				$placeHolder=1;
				$iterator=0;
				$dbh->commit();
			}
		}
	}
	$insertMySQLsth->execute() || die "cannot update $DBI::errstr";
	$insertMySQLsth->finish();
	$dbh->do("ALTER TABLE `$tableName` AUTO_INCREMENT = 1");
	$dbh->commit();
	if($dbh){$dbh->disconnect() || warn "Disconnection error: $DBI::errstr\n";}
}



#################################################################
# subroutine to trim off the white space, carriage returns, pipes, and commas from both ends of each string or array
sub trimErroneousCharacters {
	my $guy = shift;
	my $type = (ref(\$guy) eq 'REF') ? ref($guy) : ref(\$guy);
	if ( $type eq 'ARRAY') { # Reference to an array
		foreach(@{$guy}) {  #for each element in @{$guy}
			s/^\s+|\s+|\|+|\r+|\015\012+|\012+|\n+|,+$//;  #replace one or more spaces at the end of it with nothing (deleting them)
		}
	}
	elsif ( $type eq 'SCALAR' ) { # Reference to a scalar
		$guy=~ s/^\s+|\s+$//g;
	}
	return $guy;
}