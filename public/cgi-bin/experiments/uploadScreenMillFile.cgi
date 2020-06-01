#!/usr/bin/perl -w

BEGIN {
	$|=1;
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
	use CGI qw/-unique_headers :standard/;
	$CGI::HEADERS_ONCE = 1;
}

use strict;
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use DBI qw(:sql_types);
use Modules::ScreenAnalysis qw(:uploadFiles); # use my module and only load routines in analysis
#use JSON::JSON -support_by_pp; #qw( decode_json encode_json );
#  should use JSON::XS but the server does not have it installed, so we have to use the slower pure pure implimentation
use JSON::PP;
use Date::Calc;
my $q=new CGI;
print $q->header(-type => "application/json", -charset => "utf-8");

{
	# check to make sure that user is valid
	# need to add check to validate that current user is a lab member
	my %variables;
	my $size_limit = 50;
	unless(&initialize($q, $size_limit)){exit(0);}
	unless(&validateUser(\%variables,$q)){exit(0);} # validate user
}

my $limit = 40; # number of records to push at a time
my $dataTable = 'screen_results';

# declare these 2 variables to act as globals incase we hit an error
# they will be set each time we encounter a new query-condition combo.
my $currentQuery = '';
my $currentCondition = '';


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

my $settings;
&processInputData($q);

exit(0);


sub processInputData{
	my $q=shift;

	# get acceptable screen parameters from database
	$settings = &setupScreenSettings();
	$settings->{insertTable} = $dataTable;
	my $counter = 1;

	$settings->{rowNum} = $q->param("rowNum[$counter]");
	if(!&is_numeric($settings->{rowNum})){	&exitProgram("Bad row number?");	}

	# if this changes also be sure to change the bind order!!!!
	my @dataOrder = ('experiment_id', 'plate', 'row', 'column', 'p_value', 'z_score', 'ratio', 'exp_colony_size_mean', 'comparer_colony_size_mean', 'ORF', 'number_of_considered_exp_replicates', 'exp_colony_circularity_mean', 'exp_colony_circularity_variance', 'exp_colony_size_variance', 'problem_flag');

	while(defined $q->param("allData[$counter]")){

		# need to verify this data against database and then what is passed in '$data->{"query"}' and
		# $q->param("queryGene") && $q->param("queryPromoter") && $q->param("querySelection")
		# $settings->{queryGene} = &trimErroneousCharactersAtEnds($q->param("queryGene[$counter]"));
		# $settings->{queryPromoter} = &trimErroneousCharactersAtEnds($q->param("queryPromoter[$counter]"));
		# $settings->{querySelection} = &trimErroneousCharactersAtEnds($q->param("querySelection[$counter]"));
		$settings->{query} = &trimErroneousCharactersAtEnds($q->param("queryPWJ[$counter]"));
		# don't need to validate condition data?
		$settings->{condition}=&trimErroneousCharactersAtEnds($q->param("condition[$counter]"));
		$settings->{condition} = defined $settings->{condition} ? $settings->{condition} : '';
		$currentQuery = $settings->{query};
		$currentCondition = $settings->{condition};

		&validatePlasmid($settings, 'query', $settings->{'dbh'});
		$settings->{comparer} = &trimErroneousCharactersAtEnds($q->param("comparerPWJ[$counter]"));
		# $settings->{comparerPromoter} = &trimErroneousCharactersAtEnds($q->param("comparerPromoter"));
		# $settings->{comparerSelection} = &trimErroneousCharactersAtEnds($q->param("comparerSelection"));
		&validatePlasmid($settings, 'comparer', $settings->{'dbh'});

		my $data = decode_json($q->param("allData[$counter]"));
		# keys of data are
		#				"extraCols" --> column order of other data
		#				"fileName" --> out-all filename
		#				"query"	--> the query for this screen
		#				"condition" --> the condition for this screen
		#				and "plates" --> contains plate ids which themselves have 2 keys
		# 			"plates" --> plate id (hash) -> "counter" === # colonies on the plate (density / reps)
		#				"plates" --> plate id (hash) -> "rows" -> row (hash) -> col (array) -> all other data (array)


		# setup hash lookup for the extra columns
		# @colindexExtraCols{@{$data->{extraCols}}} = (0..$#{$data->{extraCols}});
		# using the following function instead
		# check to make sure that each column label is only defined once in the header
		$settings->{colindexExtraCols} = &generateColindex($data->{'extraCols'});


		# need to sanitize fileName
		$settings->{fileName} = &trimErroneousCharactersAtEnds($data->{"fileName"});
		if(length($settings->{fileName}) > 255){
			&exitProgram("Filename ($settings->{fileName}) to long. Filename must be less than 255 characters.");
		}
		elsif($settings->{fileName} =~ /[\*|\$|\`|\:]/ ){
			&exitProgram("Filename ($settings->{fileName}) contains illegal characters. Filenames cannot contain the following characters: '*', '\$', '`' or ':'.");
		}
		# we are not going to store the files themselves, so can skip this step.
		# $settings{screenFileID} = &insertScreenFileData($settings->{fileName},$settings->{'dbh'}, $db, "$dir/$fileName", 'screen_files');

		$settings->{date} = &trimErroneousCharactersAtEnds($q->param("batch_date[$counter]"));
		$settings->{date} = (defined $settings->{date}) ? $settings->{date} : substr($settings->{fileName}, 0, 10);

		$settings->{screenedBy} = &trimErroneousCharactersAtEnds($q->param("screenedBy[$counter]"));
		&validateScreenedBy($settings);

		$settings->{screenType} = 'SDL'; #&trimErroneousCharactersAtEnds($q->param("screenType"));
		$settings->{libraryScreened} = &trimErroneousCharactersAtEnds($q->param("library[$counter]"));
		if(!defined $settings->{libraryPossibilities}->{$settings->{libraryScreened}}){
			&exitProgram( "$settings->{libraryScreened} is an unacceptable strain library.");
		}
		$settings->{donorStrain} = &trimErroneousCharactersAtEnds($q->param("donor[$counter]"));
		if(!defined $settings->{donorPossibilities}->{$settings->{donorStrain}}){
			&exitProgram( "$settings->{donorStrain} is an unacceptable donor strain.");
		}

		# check to make sure the number of replicates is okay
		$settings->{numberReplicates} = &trimErroneousCharactersAtEnds($q->param("replicates[$counter]"));
		if(!defined $settings->{repPossibilities}->{$settings->{numberReplicates}}){
			&exitProgram( "$settings->{numberReplicates} is an unacceptable number of replicates for a screen.");
		}
		{
			my $numberReplicates=0;
			foreach my $colLabel(keys %{$settings->{colindexExtraCols}}){	if($colLabel =~ /normalized colony size/i){$numberReplicates++;	}}
			if($numberReplicates != $settings->{numberReplicates}){
				&exitProgram( "The nuumber of colums with a label like 'normalized colony size' ($numberReplicates) does not match the # of replicates calculated on the previous page ($settings->{numberReplicates}.");
			}
		}

		# check to make sure the density value is okay
		$settings->{density} = &trimErroneousCharactersAtEnds($q->param("density[$counter]"));
		if(!defined $settings->{densityPossibilities}->{$settings->{density}}){
			&exitProgram( "$settings->{densityPossibilities} is an unacceptable density value for a screen.");
		}
		{
			my $numberColonies = $settings->{density} / $settings->{numberReplicates};
			no warnings 'numeric'; # turn off warnings about numbers (important for sort in next line)
			# sort numeric then by alpha ie 1,2,3,a,b,c
			foreach my $plate(sort {$a cmp $b || $a <=> $b } keys %{$data->{'plates'}}){
				if($data->{'plates'}->{$plate}->{'counter'} != $numberColonies){
					&exitProgram( "The number of colonies ($data->{'plates'}->{$plate}->{'counter'}) on plate '$plate' does not match the number of acceptable colonies calculated ($numberColonies) based on the determined density ($settings->{density}) and replicate ($settings->{numberReplicates}) values.");
				}

				# upcase plate and remove preceeding and trailing brackets, if present
				my $tempPlate = uc($plate);
				$tempPlate =~ s/^\[{1}//;
				$tempPlate =~ s/\]{1}$//;
				if($tempPlate ne $plate){
					$data->{'plates'}->{$tempPlate} = $data->{'plates'}->{$plate};
					delete $data->{'plates'}->{$plate};
				}

			}
		}

		$settings->{comments} = $q->param("comments[$counter]");

		$settings->{screen_purpose} = &trimErroneousCharactersAtEnds($q->param("screen_purpose[$counter]"));
		if(!defined $settings->{screenPurposePossibilities}->{$settings->{screen_purpose}}){
			&exitProgram( "$settings->{screen_purpose} is an unacceptable purpose for a screen.");
		}

		$settings->{incubation_temperature} = &trimErroneousCharactersAtEnds($q->param("incubation_temperature[$counter]"));
		if(!&is_numeric($settings->{incubation_temperature}) || $settings->{incubation_temperature} < 18 || $settings->{incubation_temperature} > 45){
			&exitProgram( "Incubation temperature ($settings->{incubation_temperature}) must be an integer between 18 and 45.");
		}



		# setup missing data message, only display it if data is indeed missing
		my $missingData='';

		# check to make sure id column is defined
		if(!defined $settings->{colindexExtraCols}->{'id column'}){	$missingData.="ID Column\n";	}

		# check if the calculated log ratio column was found
		$settings->{colindexExtraCols}->{'logRatio'}=undef;
		if(defined $settings->{colindexExtraCols}->{'log growth ratio'}){
			$settings->{colindexExtraCols}->{'logRatio'} = $settings->{colindexExtraCols}->{'log growth ratio'};
			delete $settings->{colindexExtraCols}->{'log growth ratio'};
		}
		elsif(defined $settings->{colindexExtraCols}->{'calculated log ratio (comparer::exp)'}){
			$settings->{colindexExtraCols}->{'logRatio'} = $settings->{colindexExtraCols}->{'calculated log ratio (comparer::exp)'};
			delete $settings->{colindexExtraCols}->{'calculated log ratio (comparer::exp)'};
		}
		elsif(defined $settings->{colindexExtraCols}->{'calculated log ratio (control::exp)'}){
			$settings->{colindexExtraCols}->{'logRatio'} = $settings->{colindexExtraCols}->{'calculated log ratio (control::exp)'};
			delete $settings->{colindexExtraCols}->{'calculated log ratio (control::exp)'};
		}
		if(!defined $settings->{colindexExtraCols}->{'logRatio'}){
			$settings->{colindexExtraCols}->{'logRatio'} = undef;
			$missingData.="Log Growth Ratio\n";
		}

		# check if the growth ratio column was found
		$settings->{colindexExtraCols}->{'growthRatio'} = undef;
		if(defined $settings->{colindexExtraCols}->{'growth ratio (comparer / exp)'}){
			$settings->{colindexExtraCols}->{'growthRatio'} = $settings->{colindexExtraCols}->{'growth ratio (comparer / exp)'};
			delete $settings->{colindexExtraCols}->{'growth ratio (comparer / exp)'};
		}
		elsif(defined $settings->{colindexExtraCols}->{'ratio'}){
			$settings->{colindexExtraCols}->{'growthRatio'} = $settings->{colindexExtraCols}->{'ratio'};
			delete $settings->{colindexExtraCols}->{'ratio'};
		}
		if(! defined $settings->{colindexExtraCols}->{'growthRatio'} || ($settings->{colindexExtraCols}->{'growthRatio'} == $settings->{colindexExtraCols}->{'logRatio'}) ){
			$missingData.="Growth Ratio (Comparer / Exp)\n";
		}

		# check if the the normalized growth ratio column  (i.e. comparer mean :: exp mean ) was found
		$settings->{colindexExtraCols}->{'normalGrowthRatio'} = undef;
		if(defined $settings->{colindexExtraCols}->{'normalized growth ratio (comparer::exp)'}){
			$settings->{colindexExtraCols}->{'normalGrowthRatio'} = $settings->{colindexExtraCols}->{'normalized growth ratio (comparer::exp)'};
			delete $settings->{colindexExtraCols}->{'normalized growth ratio (comparer::exp)'};
		}
		elsif(defined $settings->{colindexExtraCols}->{'normalized ratio (comparer::exp)'}){
			$settings->{colindexExtraCols}->{'normalGrowthRatio'} = $settings->{colindexExtraCols}->{'normalized ratio (comparer::exp)'};
			delete $settings->{colindexExtraCols}->{'normalized ratio (comparer::exp)'};
		}
		elsif(defined $settings->{colindexExtraCols}->{'normalized ratio (control::exp)'}){
			$settings->{colindexExtraCols}->{'normalGrowthRatio'} = $settings->{colindexExtraCols}->{'normalized ratio (control::exp)'};
			delete $settings->{colindexExtraCols}->{'normalized ratio (control::exp)'};
		}
		if(!defined $settings->{colindexExtraCols}->{'normalGrowthRatio'} || $settings->{colindexExtraCols}->{'normalGrowthRatio'} < 0){
			$missingData.="Normalized Growth Ratio (Comparer::Exp)\n";
		}

		# check if the pvalue column was found, don't delete mann or t-test columns (as we did with the other checks above)
		# becuase they may be required for the z-score check, which is next
		if(defined $settings->{colindexExtraCols}->{'p-value'}){} # cool --> do nothing
		elsif(defined $settings->{colindexExtraCols}->{'t-test p-value'}){
			$settings->{colindexExtraCols}->{'p-value'} = $settings->{colindexExtraCols}->{'t-test p-value'};
		}
		elsif(defined $settings->{colindexExtraCols}->{'mann-whitney probability'}){
			$settings->{colindexExtraCols}->{'p-value'} = $settings->{colindexExtraCols}->{'mann-whitney probability'};
		}
		else{
			$settings->{colindexExtraCols}->{'p-value'}=undef;
			$missingData.="P-Value, T-Test P-Value or Mann-Whitney Probability\n";
		}

		# check if the zscore column was found
		$settings->{colindexExtraCols}->{'z-score'} = defined $settings->{colindexExtraCols}->{'z-score'} ? $settings->{colindexExtraCols}->{'z-score'} : undef;
		if(!defined $settings->{colindexExtraCols}->{'z-score'} || $settings->{colindexExtraCols}->{'z-score'} < 0){
			# we only care if the z-score is missing for datasets that have p-value column defined (ie normal dist used)
			if(!defined $settings->{colindexExtraCols}->{'t-test p-value'} && !defined $settings->{colindexExtraCols}->{'mann-whitney probability'}){	$missingData.="Z-Score\n";}
			else{$settings->{colindexExtraCols}->{'z-score'} = scalar(keys %{$settings->{colindexExtraCols}})*2;} # else set to a colindex that is pretty much guaranteed to not contain ANY data
		}
		# display warning message about missing data, if needed
		if($missingData ne ''){# && !$variables->{'dontDorryAboutMissingValues'} ){
			$missingData = "Could not find the following column(s) in your ScreenMillStats-all.txt file:\n$missingData";
			$missingData.="\n";
			&exitProgram( "$missingData");
		}

		$settings->{number_of_plates} = scalar(keys %{$data->{'plates'}});
		if(!&is_numeric($settings->{number_of_plates}) || $settings->{number_of_plates} < 1){
			&exitProgram( "Number of plates ($settings->{number_of_plates}) is not numeric or is less than 1.");
		}

		$settings->{expID} = &createNewExperiment($settings);
		if($settings->{expID} > 0){&insertExperimentalData($settings, $data, \@dataOrder);}
		#warn Dumper $data;
		$counter++;
	}


	$settings->{'dbh'}->commit();
	$settings->{'dbh'}->disconnect();

	print '{"success":"success!", "rowNum": "'.$settings->{rowNum}.'"}';
}

sub insertExperimentalData {
	my ($settings, $allData, $dataOrder) = @_;
	my $bindPlaceHolder=0;
	my $counter=0;
	my $iterator=0;

	# setup mysql insert statement
	$settings->{'sth'} = &setupScreenResultsInsert($settings->{'dbh'}, $dataTable, $dataOrder, $limit);

	# keys of data are
	#				"extraCols" --> column order of other data
	#				"fileName" --> out-all filename
	#				"query"	--> the query for this screen
	#				"condition" --> the condition for this screen
	#				and "plates" --> contains plate ids which themselves have 2 keys
	# 			"plates" --> plate id (hash) -> "counter" === # colonies on the plate (density / reps)
	#				"plates" --> plate id (hash) -> "rows" -> row (hash) -> col (array) -> all other data (array)


	# 'experiment_id', 'plate', 'row', 'column', 'p_value', 'z_score', 'ratio', 'exp_colony_size_mean',
	# 'comparer_colony_size_mean', 'ORF', 'number_of_considered_exp_replicates', 'exp_colony_cirularity_mean',
	#	'exp_colony_circularity_variance', 'exp_colony_size_variance', 'problem_flag');
	{
		no warnings 'numeric'; # turn off warnings about numbers (important for sort in next line)

		# sort numeric then by alpha ie 1,2,3,a,b,c
		foreach my $plate(sort {$a cmp $b || $a <=> $b } keys %{$allData->{'plates'}}){
			foreach my $row(keys %{$allData->{'plates'}->{$plate}->{'rows'}}){
				foreach my $col(keys %{$allData->{'plates'}->{$plate}->{'rows'}->{$row}}){
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $settings->{expID});$bindPlaceHolder++;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $plate);$bindPlaceHolder++;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), uc($row));$bindPlaceHolder++; # convert row letters to uppercase
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $col);$bindPlaceHolder++;

					# define line just to shrink the variable name a bit.
					my $line = $allData->{'plates'}->{$plate}->{'rows'}->{$row}->{$col};

					my $pval = (defined $line->[$settings->{colindexExtraCols}->{'p-value'}] && &is_numeric($line->[$settings->{colindexExtraCols}->{'p-value'}])) ? $line->[$settings->{colindexExtraCols}->{'p-value'}] : undef ;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $pval);$bindPlaceHolder++;
					my $zScore = (defined $line->[$settings->{colindexExtraCols}->{'z-score'}] && &is_numeric($line->[$settings->{colindexExtraCols}->{'z-score'}])) ? $line->[$settings->{colindexExtraCols}->{'z-score'}] : undef;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $zScore);$bindPlaceHolder++;
					my $gRatio = (defined $line->[$settings->{colindexExtraCols}->{'growthRatio'}] && &is_numeric($line->[$settings->{colindexExtraCols}->{'growthRatio'}])) ? $line->[$settings->{colindexExtraCols}->{'growthRatio'}] : undef;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $gRatio);$bindPlaceHolder++;

					# calculate experimental colony circularity mean and variance
					# calculate experimental colony area mean and variance
					my ($sizeVar,$sizeMean,$circVar,$circMean,$numValid, $psuedoCircVar, $pseudoSizeVar, $oldSizeMean, $oldCircMean) = (0,0,0,0,0,0,0,0,0);
					for(my $i=1; $i<=$settings->{numberReplicates}; $i++){
						$oldSizeMean = $sizeMean;
						$oldCircMean = $circMean;
						if(defined $line->[$settings->{colindexExtraCols}->{"normalized colony size $i"}]){
							# check if this plate has not been excluded -->
							# actually do not need to do this check as all excluded colonies on excluded plates are marked with '*'
							# so just check for that...
							if($line->[$settings->{colindexExtraCols}->{"normalized colony size $i"}] !~ /\*/  && $line->[$settings->{colindexExtraCols}->{"normalized colony size $i"}] !~ /\^/ && $line->[$settings->{colindexExtraCols}->{"normalized colony size $i"}] !~ /plate excluded/i){
								$numValid++; # determine # of experimental colonies actually considered
								$sizeMean += ($line->[$settings->{colindexExtraCols}->{"normalized colony size $i"}] - $oldSizeMean) / $numValid;
								$pseudoSizeVar += ($line->[$settings->{colindexExtraCols}->{"normalized colony size $i"}] - $oldSizeMean) * ($line->[$settings->{colindexExtraCols}->{"normalized colony size $i"}] - $sizeMean);

								if(defined $settings->{colindexExtraCols}->{"colony circularity $i"}){
									$circMean += ($line->[$settings->{colindexExtraCols}->{"colony circularity $i"}] - $oldCircMean) / $numValid;
									$psuedoCircVar += ($line->[$settings->{colindexExtraCols}->{"colony circularity $i"}] - $oldCircMean) * ($line->[$settings->{colindexExtraCols}->{"colony circularity $i"}] - $circMean);
								}
							}
						}
						else{	&exitProgram( "Could not find $i colony size or circ.\n");}
					}

					if ($numValid > 1) {
						# variance
						$sizeVar = $pseudoSizeVar / ( $numValid - 1);
						$circVar = $psuedoCircVar / ( $numValid - 1);
						# sample variance
						#$sizeVar = $pseudoSizeVar / $numValid;
					}

					# derive comparer size mean & determine if this set of colonies was excluded, blank, or dead (ie determine problemFlag status)
					my $problemFlag='';
					my $comparerSizeMean='';
					if(defined $line->[$settings->{colindexExtraCols}->{'normalGrowthRatio'}] ){
						if($line->[$settings->{colindexExtraCols}->{'normalGrowthRatio'}]=~/^(\D+)|\D+$/){$problemFlag=$1; $problemFlag =~ s/\-//g; $line->[$settings->{colindexExtraCols}->{'normalGrowthRatio'}]=~s/^\D+|\D+$//ig;}
						$line->[$settings->{colindexExtraCols}->{'normalGrowthRatio'}] =~ /^(.*)::/;
						$comparerSizeMean = $1;
					}

					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $sizeMean);$bindPlaceHolder++;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $comparerSizeMean);$bindPlaceHolder++;
					my $orf = '';
					if($line->[$settings->{colindexExtraCols}->{'normalGrowthRatio'}]=~/blank/i){	$orf="blank";	}
					else{$orf = &getOrf($line->[$settings->{colindexExtraCols}->{'id column'}],$plate,$row,$col, $settings->{'dbh'});}

					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $orf);$bindPlaceHolder++;

					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $numValid);$bindPlaceHolder++;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $circMean);$bindPlaceHolder++;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $circVar);$bindPlaceHolder++;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $sizeVar);$bindPlaceHolder++;
					$settings->{'sth'}->bind_param(($bindPlaceHolder+1), $problemFlag);$bindPlaceHolder++;

					$iterator++;
					if($iterator >= $limit){
						$settings->{'sth'}->execute();
						$bindPlaceHolder=0;
						$iterator=0;
					}
					$counter++;
				}
			}
		}
	}
	if($iterator > 0){
		while($iterator < $limit){
			foreach(my $j=0;$j<@{$dataOrder};$j++){
				$settings->{'sth'}->bind_param(($bindPlaceHolder+1),undef);
				$bindPlaceHolder++;
			}
			$iterator++;
		}
		$settings->{'sth'}->execute() || die "cannot update $DBI::errstr";
		# execute inserting / updating final records
	}
	$settings->{'sth'}->finish();

	# delete null rows from table
	my $deleteMySQLsth = $settings->{'dbh'}->prepare("DELETE FROM `$dataTable` WHERE `experiment_id` is null") or die "Can't prepare statement: $DBI::errstr"; # Prepare the statement
	$deleteMySQLsth->execute();
	#warn $deleteMySQLsth->rows()." row successfully deleted from MySQL table $table\n\n";
	$deleteMySQLsth->finish();

	$settings->{'dbh'}->commit();

	#warn "DONE! $counter rows processed for this query / condition ($settings{query} / $settings{condition}).\n\n\n";
	return 1;
}

sub getOrf {
	my ($id,$plate,$row,$col,$dbh) = @_;
	$id = &trimErroneousCharactersAtEnds($id);
	if(! defined $id || $id eq ''){$id="BLANK";}
	# if(!defined $id || $id eq ''){
	# 	&exitProgram( "No ORF identifier found at: $plate-$row$col. Every position must have a valid ORF or be labeled with 'BLANK', 'POSITIVE CONTROL' or 'IGNORE'.");
	# }
	# verify id is an ORF!
	elsif($id !~/^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$/ && $id !~ /^blank$/i && $id !~ /^Positive Control$/i && $id !~ /^ignore$/i){
		if($id eq 'Replaced 11/08/00 by consortium and new one added at end' && $plate eq '12' && $row eq 'H' && $col eq '14'){
			$id = 'YLR455W';
		}
		elsif($id eq 'Replaced 11/08/00 by consortium and new one added at end' && $plate eq '12' && $row eq 'J' && $col eq '2'){
			$id = 'YMR119W';
		}
		elsif($id eq 'Replaced 11/08/00 by consortium and new one added at end' && $plate eq '12' && $row eq 'J' && $col eq '10'){
			$id = 'YOL125W';
		}
		elsif($id eq 'Switched with 5787. cs mixed a and alpha. 08/16/00' && $plate eq '10' && $row eq 'K' && $col eq '10'){
			$id = 'YIL018W';
		}
		else{
			#  mabye this is a gene name? look it up!
			my $sth = $dbh->prepare( "SELECT `orf` FROM `yeast_genes` WHERE `gene` LIKE ?" );
			$sth->execute($id);
			my $numRows = $sth->rows;
			if($numRows == 1){
				while ( my $row = $sth->fetchrow_arrayref() ) {
					if($row->[0] && $row->[0] ne ""){
						$sth->finish();
						return $row->[0];
					}
					else{	$sth->finish(); &exitProgram( "$plate\t$row\t$col\tinvalid ORF: '$id'\n");}
				}
			}
			$sth->finish();
			if($numRows > 1){	&exitProgram( "Invalid ORF, '$id', found at: $plate-$row$col. More than 1 gene with an identifier like '$id' exists.");	}
			else{	&exitProgram( "Invalid ORF, '$id', found at: $plate-$row$col. Could not find the identifier '$id' in the gene database.");	}
		}
	}

	return $id;
}

# this function will generate the colindex and check for duplicate columns
sub generateColindex {
	my $headers = shift;
	my @dupColHeads = ();
	my %colindex=();
	for(my $j=0; $j<@{$headers}; $j++){
		if($headers->[$j] ne '' ){
			if(defined($colindex{$headers->[$j]})){	push(@dupColHeads, $headers->[$j]);}
			else{	$colindex{$headers->[$j]} = $j;}
		}
	}
	if(scalar(@dupColHeads) > 0){
		#&update_error('Your ScreenMillStats-All data file contains duplicate column header(s). Each column header must be unique. Please edit your ScreenMillStats-All data file to fix this problem<br/>Note that the only required column headers are: \'Plate #\', \'Row\', \'Column\', \'ID Column\', \'Condition\' and \'Query\'.<br/><br/>The following column header(s) appear more then once in your file:<br/>'.join(", ",@dupColHeads).'<br/><br/>'.&contact_admin(), $q);
		&exitProgram( "Duplicate column headers found in ScreenMillStats-All data file. This cannot be. Dup heads = ".join(', ',@dupColHeads));
	}
	return \%colindex;
}

sub validatePlasmid {
	# $qORc == either 'query' or 'comparer'
	my ($settings, $qORc, $mySQLdbh) = @_;

	if($settings->{$qORc} =~ /^pwj[0-9]{3,9}$/i){
		$settings->{'sth'} = $mySQLdbh->prepare("SELECT * FROM `pwj_plasmids` WHERE `number` = ?");
		$settings->{'sth'}->execute($settings->{$qORc}) or die $DBI::errstr;
		if($settings->{'sth'}->rows > 0){
			my (%plasmidNums, @plasmidGenes);
			while (my $results = $settings->{'sth'}->fetchrow_hashref) {	push (@plasmidGenes, "$results->{promoter}-$results->{gene}, $results->{yeast_selection} -  ($results->{number}) - $results->{comments}");	$plasmidNums{$results->{number}}=$results;}
			if(scalar(@plasmidGenes) == 1){
				# if($qORc eq 'query'){
				# 	if($plasmidNums{$settings->{$qORc}}->{promoter} ne $settings->{$qORc.'Promoter'} || $plasmidNums{$settings->{$qORc}}->{yeast_selection} ne $settings->{$qORc.'Selection'}){
				# 		&exitProgram( "Query plasmid info does not match data in database.\nEntered info: #: $settings->{$qORc}, Gene: ".$settings->{$qORc.'Gene'}.", Promoter: ".$settings->{$qORc.'Promoter'}.", Selection: ".$settings->{$qORc.'Selection'}.".\nIn database: #: $plasmidNums{$settings->{$qORc}}->{number}, Gene: $plasmidNums{$settings->{$qORc}}->{gene}, Promoter: $plasmidNums{$settings->{$qORc}}->{promoter}, Selection: $plasmidNums{$settings->{$qORc}}->{selection}.");
				# 	}
				# 	elsif($plasmidNums{$settings->{$qORc}}->{gene} ne $settings->{$qORc.'Gene'}){
				# 		&exitProgram( "Query plasmid info does not match data in database.\nEntered info: #: $settings->{$qORc}, Gene: ".$settings->{$qORc.'Gene'}.", Promoter: ".$settings->{$qORc.'Promoter'}.", Selection: ".$settings->{$qORc.'Selection'}.".\nIn database: #: $plasmidNums{$settings->{$qORc}}->{number}, Gene: $plasmidNums{$settings->{$qORc}}->{gene}, Promoter: $plasmidNums{$settings->{$qORc}}->{promoter}, Selection: $plasmidNums{$settings->{$qORc}}->{selection}.");
				# 	}
				# }
				#else{
					$settings->{'sth'}->finish(); return $settings->{query};
				#}
			}
			else{
				&exitProgram( "ERROR! Too many $qORc plasmids found - the following plasmids were found for '$settings->{$qORc}':\n".join("\n",@plasmidGenes));
			}
		}
		else{
			&exitProgram( "ERROR! Could not find $qORc plasmid '$settings->{$qORc}' in the database.");
		}
	}
	else{
		&exitProgram( "ERROR! Invalid $qORc pwj stucture ($settings->{$qORc}). Pwj plasmids must be structured as 'pwj[0-9]{3,9}' where '[0-9]{3,9}' indicates 3-9 integers.");
	}
}

sub createNewExperiment{
	my ($settings)=@_;
	$settings->{'sth'} = $settings->{'dbh'}->prepare("INSERT INTO `experiments` (`batch_date`,`density`,`comparer`,`query`,`condition`,`replicates`,`screen_type`,`library_used`,`donor_strain_used`,`comments`,`screen_purpose`,`number_of_plates`, `incubation_temperature`, `created_by`, `updated_by`, `performed_by`, `updated_at`, `created_at`) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,NOW(),NOW())");
	$settings->{'sth'}->bind_param(1, $settings->{date}, $sqlTypes{'SQL_DATE'}->());
	$settings->{'sth'}->bind_param(2, $settings->{density}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(3, $settings->{comparer}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(4, $settings->{query}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(5, $settings->{condition}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(6, $settings->{numberReplicates}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(7, $settings->{screenType}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(8, $settings->{libraryScreened}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(9, $settings->{donorStrain}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(10, $settings->{comments}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(11, $settings->{screen_purpose}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(12, $settings->{number_of_plates}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(13, $settings->{incubation_temperature}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(14, $settings->{screenedBy}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(15, $settings->{screenedBy}, $sqlTypes{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(16, $settings->{screenedBy}, $sqlTypes{'SQL_VARCHAR'}->());
	my $result = $settings->{'sth'}->execute();
	my $id = $settings->{'sth'}->{mysql_insertid};
	$settings->{'sth'}->finish();
	return $id;
}

sub validateScreenedBy{
	my $settings = shift;
	my $sth = $settings->{'dbh'}->prepare("SELECT COUNT(1) FROM `users` WHERE `login` = ?");
	$sth->execute($settings->{screenedBy}) or die $DBI::errstr;
	if($sth->rows > 0){
		$sth->finish();
		return 1;
	}
	else{
		&exitProgram ("Could not verify $settings->{screenedBy} as a user.");
	}
	return 0;
}

sub setupScreenSettings{
	my %settings;

	$settings{'dbh'} = &connectToMySQL();

	# fetch library possibilities
	my $sth = $settings{'dbh'}->prepare("SELECT `id`,`name`, `default` FROM `strain_libraries` ORDER BY `id`");
	$sth->execute() or die $DBI::errstr;
	if ($sth->rows < 0) {	&exitProgram( "Sorry, query failed when asking for strain libraries");	}
	while (my $results = $sth->fetchrow_hashref) {
		$settings{libraryPossibilities}->{$results->{name}}=$results->{id};
	}
	$sth->finish();

	# fetch replicatate possibilities
	$sth = $settings{'dbh'}->prepare("SELECT `id`, `reps` FROM `replicates`");
	$sth->execute() or die $DBI::errstr;
	if ($sth->rows < 0) {	&exitProgram ("Sorry, query failed when asking for replicates");	}
	while (my $results = $sth->fetchrow_hashref) {
		$settings{repPossibilities}->{$results->{reps}}=$results->{id};
	}
	$sth->finish();

	# fetch screen purposes
	$sth = $settings{'dbh'}->prepare("SELECT `id`, `purpose` FROM `screen_purposes`");
	$sth->execute() or die $DBI::errstr;
	if ($sth->rows < 0) {	&exitProgram("Sorry, query failed when asking for screen_purposes");	}
	while (my $results = $sth->fetchrow_hashref) {
		$settings{screenPurposePossibilities}->{$results->{purpose}}=$results->{id};
	}
	$sth->finish();

	# fetch donor possibilities
	$sth = $settings{'dbh'}->prepare("SELECT `wNumber` FROM `donors`");
	$sth->execute() or die $DBI::errstr;
	if ($sth->rows < 0) {	&exitProgram("Sorry, query failed when asking for donors");	}
	while (my $results = $sth->fetchrow_hashref) {
		$settings{donorPossibilities}->{$results->{wNumber}}=1;
	}
	$sth->finish();

	# fetch screen type possibilities
	$sth = $settings{'dbh'}->prepare("SELECT `screen_type` FROM `screen_types`");
	$sth->execute() or die $DBI::errstr;
	if ($sth->rows < 0) {	&exitProgram("Sorry, query failed when asking for screen_types");	}
	while (my $results = $sth->fetchrow_hashref) {
		$settings{screenTypePossibilities}->{$results->{screen_type}}=1;
	}
	$sth->finish();

	# fetch density possibilities
	$sth = $settings{'dbh'}->prepare("SELECT `density` FROM `densities`");
	$sth->execute() or die $DBI::errstr;
	if ($sth->rows < 0) {	&exitProgram("Sorry, query failed when asking for screen_types");	}
	while (my $results = $sth->fetchrow_hashref) {
		$settings{densityPossibilities}->{$results->{density}}=1;
	}
	$sth->finish();

	return \%settings;
}

sub setupScreenResultsInsert{
	my ($mySQLdbh, $table, $dataOrder, $limit) = @_;
	# define the order of the parameters to push to the screenResults table
	my $inserts='';
	# set-up placeholders
	foreach my $i(@{$dataOrder}){	$inserts.='?, ';	}
	$inserts=~s/,\s$//; # delete training comma and extra space
	# iterate over allData - for each query condition combo create a new experiment and then push data into screenResults table.
	# setup statement to insert $limit records at a time
	my $mySQLst = "INSERT INTO `$table` (`".join("`, `", @{$dataOrder})."`) VALUES ";
	for(my $j=0; $j < $limit; $j++){	$mySQLst .= "($inserts), ";	}
	$mySQLst =~ s/, $//; # remove trailing comma and space
	# prepare mysql statement for execution
	$mySQLst = $mySQLdbh->prepare( $mySQLst ) || die "Can't prepare a statement: $DBI::errstr";
	return $mySQLst;
}

sub valid_yyyymmdd {
	my $date = shift;
	if($date){
		chomp($date);
		my @dateParts = (split(/\||\r|\015\012|\012|\n|,\s+|,|\s+|\-|\\|\// , $date));
		if(@dateParts == 3){
			if(Date::Calc::check_date($dateParts[0],$dateParts[1],$dateParts[2])){ # $year, $month, $day format
				# we have a valid date, next check to see if it is in the future....`
				my ($year,$month,$day) = Date::Calc::Today();
				if(Date::Calc::Delta_Days($year,$month,$day, $dateParts[0],$dateParts[1],$dateParts[2]) < 0){
					return 1;
				}
				else{
					&exitProgram("Date must be at least one day in the past to be valid.\n");
				}
			}
		}
	}
	return 0;
}

sub exitProgram{
	my ($error) = @_;
	my %error = ('errorMsg' => $error, 'dataSet'=>"$currentQuery - $currentCondition");
	print encode_json(\%error);
	if(defined $settings->{'sth'}){	eval{$settings->{'sth'}->finish();};	}
	if(defined $settings->{'dbh'}){
		$settings->{'dbh'}->rollback();
		$settings->{'dbh'}->disconnect();
	}
	exit(0);
}