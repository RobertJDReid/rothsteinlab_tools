#!/usr/bin/perl -w


# Program created February 14, 2014 by John C. Dittmar.
# this program will take as input an experiment ID - using this as a key it will pull the associated data
# from screen_results and extract the excluded colonies. It will also use this data, along with the raw
# colony size data to infer which, if any comparer colonies were excluded...
#

# minimize variance?
#

# calculate mean of all, determine if it is greater than or less than the reported mean
# if it is less than, begin removing the smallest until it is no longer less than


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

my @alphabet = ("A".."ZZ");
my %rev_alphabet;
{
	my $i=0;
	%rev_alphabet = map {$_ => $i++} @alphabet;
}

#use JSON::JSON -support_by_pp; #qw( decode_json encode_json );
#  should use JSON::XS but the server does not have it installed, so we have to use the slower pure pure implimentation
use JSON::PP;
my $q=new CGI;
print $q->header(-type => "application/json", -charset => "utf-8");

{
	# check to make sure that user is valid
	# need to add check to validate that current user is a lab member
	my %variables;
	my $size_limit = 0.1;
	unless(&initialize($q, $size_limit)){exit(0);}
	unless(&validateUser(\%variables,$q)){exit(0);} # validate user
}

my %tables = ('experiments' => 'experiments',
							'colony_datasets' => 'experiment_raw_datasets',
							'raw_data' => 'experiment_colony_data',
							'screen_results' => 'screen_results',
							'exclusion' => 'excluded_colonies');

my $sqlTypes = &get_sql_types();

my $experiment_id = $q->param("experiment_id");

$experiment_id =~ s/rowNum//;

if(!&is_numeric($experiment_id)){	&exitProgram("Bad row number?");	}

my $dbh = &connectToMySQL();
my $sth;


my $experiment = &get_experiment_info();

my $comparer_dataset = &get_colony_dataset_info($experiment->{'experiment_comparer_raw_dataset_id'});

my $query_dataset = &get_colony_dataset_info($experiment->{'experiment_query_raw_dataset_id'});

# for query data can just iterate over the screen_results table to find excluded colonies, will also
# use the raw_data_table here to calculate the plate normalization values AND the comparer mean values.
# Using the 2 former pieces of info I can infer which raw comparer colony data was excluded.
#

# $plate_info is a hash reference, after find_query_excluded_colonies it contains the following structure:
# $plate_info->{plate_names}->{'query_normalization'}->query plate_normalization value
# $plate_info->{plate_names}->{'query_excluded'}->[[row, column]]; <-- this is an array of arrays (the sub arrays are size 2 with index 0 == row, index 1 == column)
# $plate_info->{plate_names}->{'compare_means'}->{row}->{column} = comparer mean value
# items in single quotes are strings, those without quotes are variables
# if all replicates are excluded then both sets (query and comparer) will be considered 'excluded', even if in reality only
# one of the sets was fully excluded
my ($plate_info) = &find_excluded_colonies($experiment, $query_dataset, $comparer_dataset);
use Data::Dumper;
warn Dumper $plate_info;


sub find_excluded_colonies {
	my($experiment_info, $query_dataset, $comparer_dataset) = @_;

	my $screen_results_sth = &get_screen_results($experiment_info->{replicates});
	my %plate_info=();
	my @possible_indices = (0..($experiment_info->{replicates}-1));
	my @sets = &combinations(@possible_indices);

	while (my $results = $screen_results_sth->fetchrow_hashref) {
		my $plate = $results->{plate};

		# if all colonies were excluded, exclude them all..
		if ($results->{number_of_considered_exp_replicates} < 1){
			my $c_colony_measurements = &get_raw_colony_measuments($experiment_info->{replicates}, $results->{plate}, $results->{row}, $results->{column}, $comparer_dataset->{id});
			my $q_colony_measurements = &get_raw_colony_measuments($experiment_info->{replicates}, $results->{plate}, $results->{row}, $results->{column}, $query_dataset->{id});
			foreach my $col(@possible_indices){
				push(@{$plate_info{$plate}->{'query_excluded'}},[$q_colony_measurements->[$col]->{row}, $q_colony_measurements->[$col]->{column}]);
				push(@{$plate_info{$plate}->{'comparer_excluded'}},[$c_colony_measurements->[$col]->{row}, $c_colony_measurements->[$col]->{column}]);
			}
		}
		# else figure out what was excluded...
		else{
			{
				# first for comparer data
				if(!defined $plate_info{$plate}->{'comparer_normalization'}){
					$plate_info{$plate}->{'comparer_normalization'} = &calculate_plate_normalization_value($plate, $experiment_info, $comparer_dataset->{id});
				}
				my $colony_measurements = &get_raw_colony_measuments($experiment_info->{replicates}, $results->{plate}, $results->{row}, $results->{column}, $comparer_dataset->{id});
				my %selected_set = (
					'min_diff' => abs($results->{comparer_colony_size_mean} - 0.1),
					'set' => [],
					'mean' => 0.1
				);
				for (my $i = 1; $i < scalar(@sets); $i++) {
					&determin_if_min_set(\%selected_set, $plate_info{$plate}->{'comparer_normalization'}, $results->{'comparer_colony_size_mean'}, $sets[$i], $colony_measurements);
				}
				my %diff;
				@diff{ @possible_indices } = undef;
				delete @diff{ @{$selected_set{'set'}} };
				foreach my $set(keys %diff){
					push(@{$plate_info{$plate}->{'comparer_excluded'}},[$colony_measurements->[$set]->{row}, $colony_measurements->[$set]->{column}]);
				}
			}
			# then for query data...
			if($results->{number_of_considered_exp_replicates} < $experiment_info->{replicates}){
				# warn Dumper $results;
				# figure out plate normalization value
				if(!defined $plate_info{$plate}->{'query_normalization'}){
					$plate_info{$plate}->{'query_normalization'} = &calculate_plate_normalization_value($plate, $experiment_info, $query_dataset->{id});
				}
				my $colony_measurements = &get_raw_colony_measuments($experiment_info->{replicates}, $results->{plate}, $results->{row}, $results->{column}, $query_dataset->{id});
				# warn Dumper $colony_measurements;
				my %selected_set = ('min_diff' => $results->{exp_colony_size_mean});
				for (my $i = 1; $i < scalar(@sets)-1; $i++) {
					next if scalar(@{$sets[$i]}) != $results->{number_of_considered_exp_replicates};
					&determin_if_min_set(\%selected_set, $plate_info{$plate}->{'query_normalization'}, $results->{'exp_colony_size_mean'}, $sets[$i], $colony_measurements);
				}
				my %diff;
				@diff{ @possible_indices } = undef;
				delete @diff{ @{$selected_set{'set'}} };
				foreach my $set(keys %diff){
					push(@{$plate_info{$plate}->{'query_excluded'}},[$colony_measurements->[$set]->{row}, $colony_measurements->[$set]->{column}]);
				}
			}
		}
	}
	return \%plate_info;
}

sub determin_if_min_set {
	my ($selected_set, $norm_value, $store_mean, $set, $colony_measurements) = @_;
	my $mean = &calculate_mean($set, $colony_measurements) / $norm_value;
	# warn "mean = $mean, db mean = $results->{exp_colony_size_mean}";
	my $diff = abs($mean-$store_mean);
	# if this mean is closer to the stored mean, then use it.
	if($diff < $selected_set->{'min_diff'}){
		$selected_set->{'min_diff'} = $diff;
		$selected_set->{'set'}=$set;
		$selected_set->{'mean'}=$mean;
	}
	# if it matches the one with the min_diff, only keep the set with the lower variance
	elsif($diff == $selected_set->{'min_diff'}){
		my $val1 = &calculate_varience($mean, $set, $colony_measurements);
		my $val2 = &calculate_varience($selected_set->{'mean'}, $selected_set->{'set'}, $colony_measurements);
		if($val1 < $val2){
			$selected_set->{'min_diff'} = $diff;
			$selected_set->{'set'}=$set;
			$selected_set->{'mean'}=$mean;
		}
	}
}

sub calculate_varience{
	my ($mean, $array, $cm) = @_;
	my $limit = scalar(@{$array});
	my $sum = 0;
	for (my $i = 0; $i < $limit; $i++) {
		$sum += ($mean - $cm->[$array->[$i]]->{'size'})**2;
	}
	return $sum/$limit;
}

sub calculate_mean{
	my ($array, $cm) = @_;
	my $limit = scalar(@{$array});
	my $sum = 0;
	for (my $i = 0; $i < $limit; $i++) {
		$sum += $cm->[$array->[$i]]->{'size'};
	}
	return $sum/scalar(@{$array});
}

# returns all combinations of items in array passed to it
sub combinations {
  return [] unless @_;
  my $first = shift;
  my @rest = combinations(@_);
  return (@rest, map { [$first, @$_] } @rest);
}

sub calculate_plate_normalization_value{
	my ($plate, $experiment_info, $dataset_id) = @_;
	$sth = "SELECT `exp_colony_size_mean`, `row`, `column` FROM $tables{'screen_results'}";
	$sth .= " WHERE `experiment_id` = ? AND `number_of_considered_exp_replicates` = ?  AND `plate` = ? LIMIT 1";
	$sth = $dbh->prepare($sth);
	$sth->execute($experiment_info->{id}, $experiment_info->{replicates}, $plate);

	if ($sth->rows != 1) {	&exitProgram("Sorry, query failed when attempting to calculate plate normalization value.");	}

	my ($mean, $row, $col);
	while (my $results = $sth->fetchrow_hashref) {
		$mean=$results->{exp_colony_size_mean};
		$row = $results->{row};
		$col = $results->{column};
	}
	$sth->finish();
	my $colony_measurements = &get_raw_colony_measuments($experiment_info->{replicates}, $plate, $row, $col, $dataset_id);

	my $sum = 0;
	for my $i(@{$colony_measurements}) {$sum+=$i->{'size'};}
	# return the average of the raw colony sizes divided by the mean exp_colony_size_mean
	return  (($sum / $experiment_info->{replicates}) / $mean);
}

sub get_raw_colony_measuments{
	my($reps, $plate, $row, $column, $experiment_raw_dataset_id) = @_;
	# warn "reps: $reps, plate: $plate, row: $row, column: $column, experiment_raw_dataset_id: $experiment_raw_dataset_id";
	my $rowSub = sub{return $_[0];};
	if($row =~ /[A-Za-z]/ && defined $rev_alphabet{$row}){
		$row = $rev_alphabet{$row};
		$rowSub = sub{return $alphabet[$_[0]+1];};
	}
	elsif($row !~ /^[0-9]+$/){&exitProgram("Sorry, invalid row value -- '$row'.");	}
	my $sql = "SELECT `colony_measurement`, `row`, `column` FROM $tables{'raw_data'} WHERE `experiment_raw_dataset_id` = ? AND `plate` = ? AND (";
	if($reps == 4 || $reps == 16){
		# get the number of rows and columns -- this will only work for 4 and 16 replicates
		my $dims = sqrt($reps);
		my $cornerRow = $row * $dims;
		my $cornerCol = $column * $dims;

		for (my $i = $dims; $i > 0; $i--) {
			$sql .= "(`row` = '".$rowSub->($cornerRow)."' AND `column` = '$cornerCol') OR ";
			$sql .= "(`row` = '".$rowSub->($cornerRow-1)."' AND `column` = '$cornerCol') OR ";
			$cornerCol--;
			$sql .= "(`row` = '".$rowSub->($cornerRow)."' AND `column` = '$cornerCol') OR ";
			$cornerRow--;
			$sql .= "(`row` = '".$rowSub->($cornerRow)."' AND `column` = '$cornerCol') OR ";
			--$i;
		}
		$sql =~ s/\sOR\s$//;
	}
	elsif($reps eq '2h'){
		my $col_pos = $column * 2;
		$sql .= "(`row` = '".$rowSub->($row)."' AND `column` = '$col_pos') OR ";
		$col_pos--;
		$sql .= "(`row` = '".$rowSub->($row)."' AND `column` = '$col_pos')";
	}
	elsif($reps eq '2v'){
		my $row_pos = $row * 2;
		$sql .= "(`row` = '".$rowSub->($row_pos)."' AND `column` = '$column') OR ";
		$row_pos--;
		$sql .= "(`row` = '".$rowSub->($row_pos)."' AND `column` = '$column')";
	}
	elsif($reps == 1){
		$sql .= "(`row` = '".$rowSub->($row)."' AND `column = '$column')";
	}
	else{&exitProgram("Sorry, invalid replicate value -- '$reps'.");	}
	$sql.=')';
	$sth = $dbh->prepare($sql);
	$sth->execute($experiment_raw_dataset_id,$plate) or &exitProgram("Sorry, the SQL failed: $DBI::errstr .");
	my @measurements = ();
	while (my $results = $sth->fetchrow_hashref) {
		push(@measurements, {'size' => $results->{colony_measurement}, 'row' => $results->{row}, 'column' => $results->{column} });
	}
	return \@measurements;
}

# returns screen_results
sub get_screen_results{
	my $reps = shift;
	my $colonies = "SELECT `plate`, `row`, `column`, `number_of_considered_exp_replicates`, `exp_colony_size_mean`, `comparer_colony_size_mean`, `problem_flag` ";
	$colonies .= "FROM $tables{'screen_results'} WHERE `experiment_id` = ?"; #" AND `number_of_considered_exp_replicates` < ? ";
	$colonies = $dbh->prepare($colonies);
	$colonies->execute($experiment_id) or &exitProgram("Sorry, the SQL failed: $DBI::errstr .");
	if ($colonies->rows < 1) {	&exitProgram("Sorry, query failed when asking for experiment -- could not find experiment with ID $experiment_id.");	}
	return $colonies;
}

sub get_colony_dataset_info{
	my $id = shift;
	$sth = "SELECT `id`, `pwj_plasmid_id`, `condition`, `number_of_plates`";
	$sth .= "FROM $tables{'colony_datasets'} WHERE `id` = ? ";
	$sth = $dbh->prepare($sth);
	$sth->execute($id) or &exitProgram("Sorry, the SQL failed: $DBI::errstr .");
	if ($sth->rows != 1) {	&exitProgram("Sorry, query failed when asking for colony dataset -- could not find id $id.");	}
	my %colony_dataset;
	while (my $results = $sth->fetchrow_hashref) {
		%colony_dataset=('id'=>$results->{id},
								 'pwj_plasmid_id'=>$results->{pwj_plasmid_id},
								 'condition'=>$results->{condition},
								 'number_of_plates'=>$results->{number_of_plates},
								);
	}
	$sth->finish();
	return \%colony_dataset;
}


sub get_experiment_info{
	$sth = "SELECT `id`, `comparer`, `query`, `condition`, `replicates`, `number_of_plates`, `experiment_comparer_raw_dataset_id`, `experiment_query_raw_dataset_id` ";
	$sth .= "FROM $tables{'experiments'} WHERE `id` = ? ";
	$sth = $dbh->prepare($sth);
	$sth->execute($experiment_id) or &exitProgram("Sorry, the SQL failed: $DBI::errstr .");
	if ($sth->rows != 1) {	&exitProgram("Sorry, query failed when asking for experiment -- could not find experiment with ID $experiment_id");	}
	my %experiment;
	while (my $results = $sth->fetchrow_hashref) {
		%experiment=('id'=>$results->{id},
								 'comparer'=>$results->{comparer},
								 'query'=>$results->{query},
								 'condition'=>$results->{condition},
								 'number_of_plates'=>$results->{number_of_plates},
								 'replicates'=>$results->{replicates},
								 'experiment_comparer_raw_dataset_id'=>$results->{experiment_comparer_raw_dataset_id},
								 'experiment_query_raw_dataset_id'=>$results->{experiment_query_raw_dataset_id}
								);
	}
	$sth->finish();
	return \%experiment;
}

sub exitProgram{
	my ($error) = @_;
	my %error = ('errorMsg' => $error, 'dataSet'=>"$experiment_id");
	print encode_json(\%error);
	if(defined $sth){	eval{$sth->finish();};	}
	if(defined $dbh){
		$dbh->rollback();
		$dbh->disconnect();
	}
	exit(0);
}