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
my $dataTable = 'experiment_colony_data';

# declare these 2 variables to act as globals incase we hit an error
# they will be set each time we encounter a new plasmid-condition combo.
my $currentPlasmid = '';
my $currentCondition = '';

my $sqlTypes = &get_sql_types();

my $settings;
&processInputData($q);

exit(0);


sub processInputData{
	my $q=shift;

	# get acceptable screen parameters from database
	$settings = &setupSettings();
	$settings->{insertTable} = $dataTable;
	my $counter = 1;

	$settings->{rowNum} = $q->param("rowNum[$counter]");
	if(!&is_numeric($settings->{rowNum})){	&exitProgram("Bad row number?");	}

	# if this changes also be sure to change the bind order!!!!
	my @dataOrder = ('experiment_raw_dataset_id', 'plate', 'row', 'column', 'colony_measurement', 'colony_circularity');

	while(defined $q->param("dataset[$counter]")){

		# need to verify this data against database
		$settings->{pwj_plasmid} = &trimErroneousCharactersAtEnds($q->param("pwj_plasmid[$counter]"));
		# don't need to validate condition data?
		$settings->{condition}=&trimErroneousCharactersAtEnds($q->param("condition[$counter]"));
		$settings->{condition} = defined $settings->{condition} ? $settings->{condition} : '';

		$currentPlasmid = $settings->{pwj_plasmid};
		$currentCondition = $settings->{condition};

		&validatePlasmid($settings, 'pwj_plasmid', $settings->{'dbh'});

		my $data = decode_json($q->param("dataset[$counter]"));
		# keys of data are
		#				"circularities" --> an ordered array of all the colony circularities (optional)
		#				"sizes" --> an ordered array of all the colony sizes (required)

		# get the batch date
		$settings->{date} = &trimErroneousCharactersAtEnds($q->param("date[$counter]"));
		$settings->{date} = (defined $settings->{date}) ? $settings->{date} : substr($settings->{fileName}, 0, 10);

		$settings->{uploadedBy} = &trimErroneousCharactersAtEnds($q->param("uploaded_by[$counter]"));
		&validateUploadedBy($settings);

		# check to make sure the density value is okay
		$settings->{density} = &trimErroneousCharactersAtEnds($q->param("density[$counter]"));
		if(!defined $settings->{densityPossibilities}->{$settings->{density}}){
			&exitProgram( "$settings->{densityPossibilities} is an unacceptable density value for a screen.");
		}
		$settings->{density_id}=$settings->{densityPossibilities}->{$settings->{density}}->{id};
		$settings->{rows}=$settings->{densityPossibilities}->{$settings->{density}}->{rows};
		$settings->{cols}=$settings->{densityPossibilities}->{$settings->{density}}->{cols};


		#  verify the number of colonies on each plate matchs the density, calculate the # of plates
		$settings->{number_of_plates} = 0;
		$settings->{has_circularities}=0;
		{
			no warnings 'numeric'; # turn off warnings about numbers (important for sort in next line)
			# sort numeric then by alpha ie 1,2,3,a,b,c
			foreach my $plate(sort {$a cmp $b || $a <=> $b } keys %{$data->{'plates'}}){
				$settings->{number_of_plates}++;
				if(scalar @{$data->{'plates'}->{$plate}->{'sizes'}} != $settings->{density}){
					&exitProgram( "The number of colonies (".scalar @{$data->{'plates'}->{$plate}->{'sizes'}}.") on plate '$plate' does not match the determined density ($settings->{density}).");
				}
				elsif(defined $data->{'plates'}->{$plate}->{'circularities'} && scalar @{$data->{'plates'}->{$plate}->{'circularities'}} > 0){
					$settings->{has_circularities}=1;
					if(scalar @{$data->{'plates'}->{$plate}->{'sizes'}} != scalar @{$data->{'plates'}->{$plate}->{'circularities'}}){
						&exitProgram( "The number of colonies with size measurements (".scalar @{$data->{'plates'}->{$plate}->{'sizes'}}.") on plate '$plate' does not match the number with circularity measurements (".scalar @{$data->{'plates'}->{$plate}->{'circularities'}}.").");
					}
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

		if(!&is_numeric($settings->{number_of_plates}) || $settings->{number_of_plates} < 1){
			&exitProgram( "Number of plates ($settings->{number_of_plates}) is less than 1.");
		}

		$settings->{log_id} = &createNewLogDataset($settings);
		if($settings->{log_id} > 0){&insertLogData($settings, $data);}
		#warn Dumper $data;
		$counter++;
	}


	$settings->{'dbh'}->commit();
	$settings->{'dbh'}->disconnect();

	print '{"success":"success!", "rowNum": "'.$settings->{rowNum}.'"}';
}

sub insertLogData {
	my ($settings, $data) = @_;
	my $bindPlaceHolder=0;
	my $counter=0;
	my $iterator=0;

	# setup mysql insert statement
	my @dataOrder = ('plate', 'row', 'column', 'colony_measurement', 'experiment_raw_dataset_id');
	if($settings->{has_circularities}){	push(@dataOrder,'colony_circularity');}

	&setupLogDataInsert($settings, $dataTable, \@dataOrder, $limit);

	{
		no warnings 'numeric'; # turn off warnings about numbers (important for sort in next line)
		# sort numeric then by alpha ie 1,2,3,a,b,c
		my @abc = ("A".."ZZ");
		foreach my $plate(sort {$a cmp $b || $a <=> $b } keys %{$data->{'plates'}}){
			my $current_col=1;
			my $current_row=1;
			for (my $i = 0; $i < @{$data->{'plates'}->{$plate}->{'sizes'}}; $i++) {
				$bindPlaceHolder = $settings->{'bindSubRoutine'}->($settings->{'sth'},
																													$bindPlaceHolder,
																													$plate,
																													$abc[($current_row-1)],
																													$current_col,
																													$data->{'plates'}->{$plate},
																													$i,
																													$settings->{log_id});

				$current_row++;
				# if($current_col > $settings->{cols}){$current_col=1;}
				if($current_row > $settings->{rows}){$current_row=1;$current_col++;}

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

	if($iterator > 0){
		while($iterator < $limit){
			foreach(my $j=0;$j<@dataOrder;$j++){
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
	my $deleteMySQLsth = $settings->{'dbh'}->prepare("DELETE FROM `$dataTable` WHERE `experiment_raw_dataset_id` is null") or die "Can't prepare statement: $DBI::errstr"; # Prepare the statement
	$deleteMySQLsth->execute();
	#warn $deleteMySQLsth->rows()." row successfully deleted from MySQL table $table\n\n";
	$deleteMySQLsth->finish();

	$settings->{'dbh'}->commit();

	#warn "DONE! $counter rows processed for this plasmid / condition ($settings{pwj_plasmid} / $settings{condition}).\n\n\n";
	return 1;
}

sub validatePlasmid {
	my ($settings, $qORc, $mySQLdbh) = @_;

	if($settings->{$qORc} =~ /^pwj[0-9]{3,9}$/i){
		$settings->{'sth'} = $mySQLdbh->prepare("SELECT * FROM `pwj_plasmids` WHERE `number` = ?");
		$settings->{'sth'}->execute($settings->{$qORc}) or die $DBI::errstr;
		if($settings->{'sth'}->rows > 0){
			my (%plasmidNums, @plasmidGenes);
			while (my $results = $settings->{'sth'}->fetchrow_hashref) {
				push (@plasmidGenes, "$results->{promoter}-$results->{gene}, $results->{yeast_selection} -  ($results->{number}) - $results->{comments}");
				$plasmidNums{$results->{number}}=$results;
			}
			if(scalar(@plasmidGenes) == 1){
				$settings->{'sth'}->finish();
				$settings->{$qORc."_id"} = $plasmidNums{$settings->{$qORc}}->{'id'};
				return $settings->{$qORc};
			}
			else{
				&exitProgram( "ERROR! Too many plasmids found - the following plasmids were found for '$settings->{$qORc}':\n".join("\n",@plasmidGenes));
			}
		}
		else{
			&exitProgram( "ERROR! Could not find plasmid '$settings->{$qORc}' in the database.");
		}
	}
	else{
		&exitProgram( "ERROR! Invalid pwj stucture ($settings->{$qORc}). Pwj plasmids must be structured as 'pwj[0-9]{3,9}' where '[0-9]{3,9}' indicates 3-9 integers.");
	}
}

sub createNewLogDataset{
	my ($settings)=@_;

	$settings->{'sth'} = $settings->{'dbh'}->prepare("INSERT INTO `experiment_raw_datasets` (`batch_date`, `density_id`, `pwj_plasmid_id`, `condition`, `number_of_plates`, `updated_by`, `comments`, `updated_at`, `created_at`) VALUES (?,?,?,?,?,?,?, NOW(),NOW())");
	$settings->{'sth'}->bind_param(1, $settings->{date}, $sqlTypes->{'SQL_DATE'}->());
	$settings->{'sth'}->bind_param(2, $settings->{density_id}, $sqlTypes->{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(3, $settings->{pwj_plasmid_id}, $sqlTypes->{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(4, $settings->{condition}, $sqlTypes->{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(5, $settings->{number_of_plates}, $sqlTypes->{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(6, $settings->{uploadedBy}, $sqlTypes->{'SQL_VARCHAR'}->());
	$settings->{'sth'}->bind_param(7, $settings->{comments}, $sqlTypes->{'SQL_TEXT'}->());

	my $result = $settings->{'sth'}->execute();
	my $id = $settings->{'sth'}->{mysql_insertid};
	$settings->{'sth'}->finish();
	return $id;
}

sub validateUploadedBy{
	my $settings = shift;
	my $sth = $settings->{'dbh'}->prepare("SELECT COUNT(1) FROM `users` WHERE `login` = ?");
	$sth->execute($settings->{uploadedBy}) or die $DBI::errstr;
	if($sth->rows > 0 && $settings->{uploadedBy}){
		$sth->finish();
		return 1;
	}
	else{	&exitProgram ("Could not verify $settings->{uploadedBy} as a user.");	}
	return 0;
}

sub setupSettings{
	my %settings;

	$settings{'dbh'} = &connectToMySQL();
	$settings{comments} ='';
	# fetch density possibilities
	my $sth = $settings{'dbh'}->prepare("SELECT * FROM `densities`");
	$sth->execute() or die $DBI::errstr;
	if ($sth->rows < 0) {	&exitProgram("Sorry, query failed when asking for screen_types");	}
	while (my $results = $sth->fetchrow_hashref) {
		$settings{densityPossibilities}->{$results->{density}}={'id'=>$results->{id}, 'rows'=>$results->{rows}, 'cols'=>$results->{columns}};
	}
	$sth->finish();

	return \%settings;
}

sub setupLogDataInsert{
	my ($settings, $table, $dataOrder, $limit) = @_;
	# define the order of the parameters to push to the screenResults table
	my $inserts='';
	# set-up placeholders
	foreach my $i(@{$dataOrder}){	$inserts.='?, ';	}
	$inserts=~s/,\s$//; # delete training comma and extra space
	# iterate over allData - for each query condition combo create a new experiment and then push data into screenResults table.
	# setup statement to insert $limit records at a time
	$settings->{'sth'} = "INSERT INTO `$table` (`".join("`, `", @{$dataOrder})."`) VALUES ";
	for(my $j=0; $j < $limit; $j++){	$settings->{'sth'} .= "($inserts), ";	}
	$settings->{'sth'} =~ s/, $//; # remove trailing comma and space
	# prepare mysql statement for execution
	$settings->{'sth'} = $settings->{'dbh'}->prepare( $settings->{'sth'} ) || die "Can't prepare a statement: $DBI::errstr";

	if(!$settings->{has_circularities}){
		$settings->{'bindSubRoutine'} = sub{
			my($sth,$bindPlaceHolder, $plate, $row, $col,$dataArray, $index, $id)=@_;
			$sth->bind_param(($bindPlaceHolder+1), $plate);$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $row);$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $col);$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $dataArray->{'sizes'}->[$index]);$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $settings->{log_id});$bindPlaceHolder++;
			return $bindPlaceHolder;
		};
		return 1;
	}
	else{
		$settings->{'bindSubRoutine'} = sub{
			my($sth, $bindPlaceHolder, $plate, $row, $col, $dataArray, $index, $id)=@_;
			$sth->bind_param(($bindPlaceHolder+1), $plate);$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $row);$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $col);$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $dataArray->{'sizes'}->[$index]);$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $settings->{log_id});$bindPlaceHolder++;
			$sth->bind_param(($bindPlaceHolder+1), $dataArray->{'circularities'}->[$index]);$bindPlaceHolder++;
			return $bindPlaceHolder;
		};
	}

	return 1;
}


sub exitProgram{
	my ($error) = @_;
	my %error = ('errorMsg' => $error, 'dataSet'=>"$currentPlasmid - $currentCondition");
	print encode_json(\%error);
	if(defined $settings->{'sth'}){	eval{$settings->{'sth'}->finish();};	}
	if(defined $settings->{'dbh'}){
		$settings->{'dbh'}->rollback();
		$settings->{'dbh'}->disconnect();
	}
	exit(0);
}
