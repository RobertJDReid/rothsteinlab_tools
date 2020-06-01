#!/usr/bin/perl -wT
use strict
use Statistics::Descriptive;

# control locations is only defined if the normalization method chosen was "Designated Controls"
my ($q, $mode, $variables, $controlLocations) = @_;
my $den = 1536;
my $alive_threshold=0.35;
my $absolute_dead_cutoff=0; # this being set at 0 makes some of the checks below redundent ...EVERY value should be >=0
my ($line_counter, $LOG, $head, $info, @info, %queries, $colony, %normalization_values, $control, $count, $plateDataCounter, $upload_dir, $foundControl,
		$perceived_density, %plate, @files, $files, $file,@data,%plate_circ,$circ_flag,$considered_growing, @sorted, $midPoint, $sortQuery);
	
# iterate over log file, prepend ALL control plate query names with 0000_ tag so that when sorted, they will be first (for display)
$line_counter=1;
$perceived_density=0;
$foundControl = 0; # keeps track if we have found the control (comparer) in the log file or not
open(my $LOG, "<$logFileName") or die "Cannot open key log file: $logFileName  $!";
		
$/ = line_break_check( $LOG ); # set the default perl line break to whatever in in the file
$head="";
chomp($head=<$LOG>);
$head=~ tr/"|\t//d; # remove any quotes or tabs in the string
if($head =~ /.DS_Store/i){chomp($head=<$LOG>);$head=~ tr/"//d;} # ignore .DS_Store if it is 1st line of log
@info = split/\./, $head;
if($info[$#info] =~ /^(tif|tiff|jpg|jpeg|gif|png|psd|bmp|fits|pgm|ppm|pbm|dic|dcm|dicom|pict|pic|pct|tga|ico|xbm|lsm|img|liff)/i){
	pop(@info);
}
$info = join(".",@info);
if($info=~/(\.|\!|\@|\#|\$|\%|\^|\\|\/)/){
	$head = substr($head,0,50)."..." if length($head) > 50;
	die("There seems to be an issue with you log file at line: $line_counter ($head)."); 
	@info=(split /,/,$info); # split file name based on commas --> index 0 should be the query, 1 = plate#, 2 = condition (if present)
	if(@info<2 || @info>3){
		die "issue with you log file at line: $line_counter ($head). program will only except file names with exactly 2 commas";
	}
		
	if(! defined $info[2]){ $info[2]='';}
	%{$variables->{'originalData'}->{"\U$info[1]"}->{"\L$info[0]"}->{"\L$info[2]"}} = ('plateNum'=>$info[1], 'query'=>$info[0], 'condition'=>$info[2]);
	$queries{$info[0]}->{$info[2]}='1'; # store query names in hash...makes sorting easy
	$info[1]="\U$info[1]"; # uppercase everything (plate number)
	$info[0]="\L$info[0]"; # lowercase everything (query)
	$info[2]="\L$info[2]"; # lowercase everything (condition)

	$sortQuery=$info[0];
	if($info[0] eq $variables->{'control'}){$sortQuery="0000_$sortQuery";$foundControl=1;}
	my $stat = Statistics::Descriptive::Full->new();
	
	$plateDataCounter=0;
	my $number_of_lines = $.;
	while(<$LOG>){
		chomp;
		$line_counter++;
		if($_ =~ /,/){ #new filename encountered
			# if no data found...
			if($plateDataCounter == 0){
				my $plateLabel = $variables->{'originalData'}->{$info[1]}->{$info[0]}->{$info[2]};
				die "Zero data error --> data pertaining to $info[1], $info[0], $info[2] contains $plateDataCounter.\n $!";
			}
			# based on above calculations, calculate the normalization values for current plate
			# set to plate mean
			$normalization_values{$info[1]}->{$info[0]}->{$info[2]} = $stat->mean();
			# iterate all colony sizes in current plate, if a colony size is within 35% of the maximum colony size on the plate
			# then consider it for the plate average
			$considered_growing = $normalization_values{$info[1]}->{$info[0]}->{$info[2]}*$alive_threshold;
			$stat = Statistics::Descriptive::Full->new();
			foreach $colony(@{$plate{$info[1]}->{$sortQuery}->{$info[2]}->[0]}){
				if($colony >=$considered_growing) { $stat->add_data($colony)}
			}
			# based on above calculations, calculate the average colony size for current plate
			$normalization_values{$info[1]}->{$info[0]}->{$info[2]} = $stat->mean();
		
			# ensure that the value is NOT 0
			if(defined $normalization_values{$info[1]}->{$info[0]}->{$info[2]}){	
				$normalization_values{$info[1]}->{$info[0]}->{$info[2]}= 1 if (! defined $normalization_values{$info[1]}->{$info[0]}->{$info[2]} || $normalization_values{$info[1]}->{$info[0]}->{$info[2]} <= 0);
			}
			else{$normalization_values{$info[1]}->{$info[0]}->{$info[2]}= 1; }
			
			if($perceived_density==0){$perceived_density=$plateDataCounter;}
			elsif($perceived_density != $plateDataCounter){
				my $plateLabel = $variables->{'originalData'}->{$info[1]}->{$info[0]}->{$info[2]};
				die "data pertaining to $info[1],$info[0],$info[2] contains $plateDataCounter data, but density screen seemed to be performed at is $perceived_density.\n $!";
			}

			$plateDataCounter=0; 
			$_=~ tr/"|\t//d;        #remove any quotes or tabs in the string
			@info = split/\./, $_;
			if($info[$#info] =~ /^(tif|tiff|jpg|jpeg|gif|png|psd|bmp|fits|pgm|ppm|pbm|dic|dcm|dicom|pict|pic|pct|tga|ico|xbm|lsm|img|liff)/i){
				pop(@info);
			}
			$info = join(".",@info);
			unless($info=~/[^\w\.\!\@\#\$\%\^\\\/]/){
				die "issue with you log file at line: $line_counter ($head). Illegal characters.";
			}
			@info=split(/,/, $info);  # split by commas
			
			if(@info<2 || @info>3){	die "issue with you log file at line: $line_counter ($_).";	}
			if(!defined $info[2]){$info[2]='';}
			%{$variables->{'originalData'}->{"\U$info[1]"}->{"\L$info[0]"}->{"\L$info[2]"}} = ('plateNum'=>$info[1], 'query'=>$info[0], 'condition'=>$info[2]);
			$queries{$info[0]}->{$info[2]}='1'; # store query names in hash...makes sorting easy
			$info[1]="\U$info[1]"; # uppercase everything
			$info[0]="\L$info[0]"; # uppercase first letter
			$info[2]="\L$info[2]"; # uppercase first letter

			$sortQuery=$info[0];
			if($info[0] eq $variables->{'control'}){$sortQuery="0000_$sortQuery";$foundControl=1;}
		}
		#  START push plate data into an array, add to plate sum if colony size < 25, iterate $plateDataCounter (plateDataCounter checks the integrity of the log file)
		else{
			@data=split/\t/;
			if(!defined $data[0] || $data[0]!~/[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?$/ ){
				my $bad_line = 1;
				if(!defined $data[0]){
					$bad_line=0;
					# determine if this is the last line...
					foreach my $line(<$LOG>){
						chomp($line);
						my @data1 = split(/\t/, $line);
						if(!defined $data1[0]){next;}
						else{$bad_line = 1; last;}
					}
				}
				if($bad_line){
					my $dataError = "";
					if($data[0]){$dataError = length($data[0] > 20) ? substr($data[0],0,17).'...' : $data[0];}
					die "issue with you log file at line #$line_counter (plate = $head) data = $dataError";
				}
			}
			else{
				if(defined $data[1]){ # for log files with circularity measurements
					push @{$plate{$info[1]}->{$sortQuery}->{$info[2]}->[1]}, $data[1]; # push circularity data into hash
					$circ_flag=1;
				}
				# add to "considered" data
				if($data[0] > $absolute_dead_cutoff){	$stat->add_data($data[0]);}
				push (@{$plate{$info[1]}->{$sortQuery}->{$info[2]}->[0]}, $data[0]);
				$plateDataCounter++;
			}
		}
	}
	# START FINAL PLATE CALCULATIONS (same as above)
	if($plateDataCounter == 0){
		my $plateLabel = $variables->{'originalData'}->{$info[1]}->{$info[0]}->{$info[2]};
		die("Your data pertaining to $plateLabel->{'plateNum'}, $plateLabel->{'query'}, $plateLabel->{'condition'} contains $plateDataCounter data. You should have 96, 384 or 1536 data per plate, separated by carriage returns in your log file.");
	}
	# set to plate mean
	$normalization_values{$info[1]}->{$info[0]}->{$info[2]} = $stat->mean();
	# iterate all colony sizes in current plate, if a colony size is within 35% of the maximum colony size on the plate
	# then consider it for the plate average
	$considered_growing = $normalization_values{$info[1]}->{$info[0]}->{$info[2]}*$alive_threshold;
	$stat = Statistics::Descriptive::Full->new();
	foreach $colony(@{$plate{$info[1]}->{$sortQuery}->{$info[2]}->[0]}){
		if($colony >=$considered_growing) { $stat->add_data($colony)}
	}
	# based on above calculations, calculate the average colony size for current plate
	$normalization_values{$info[1]}->{$info[0]}->{$info[2]} = $stat->mean();

	# ensure that the value is NOT 0
	if(defined $normalization_values{$info[1]}->{$info[0]}->{$info[2]}){	
		$normalization_values{$info[1]}->{$info[0]}->{$info[2]}= 1 if (! defined $normalization_values{$info[1]}->{$info[0]}->{$info[2]} || $normalization_values{$info[1]}->{$info[0]}->{$info[2]} <= 0);
	}
	else{$normalization_values{$info[1]}->{$info[0]}->{$info[2]}= 1;}
	# END FINAL PLATE CALCULATIONS (same as above)\
		
	if($circ_flag){$variables->{'circ_included'}=1;} # set flag to indicate if circularity measurements are included
	# set the density
	if($perceived_density==0){$variables->{'density'}=$plateDataCounter;}
	else{$variables->{'density'}=$perceived_density;}
	close $LOG;
}
	
$variables->{'control'}="0000_$variables->{'control'}"; 
# store queries in array, check to see if the control query entered by the user
# matches the name of one of the queries processed in the log file(s)
# only need this check during the initial processing
my @queries=sort {lc $a cmp lc $b} keys %queries; # case insensitive sort!
if(!$foundControl){
	$variables->{'control'}=~ s/0000_//; # strip out leading '0000_' 
	my $em.='The comparer query you entered ('.$variables->{'originalData'}->{'control'}.') is not present in the log file (case-insensitive). Please change your comparer query to something that is present in your log file. The queries present in the log file are:';
	my $last="";
	my $starting=0;
	$em.="\n";
	foreach(@queries){
		$_=~ s/^0000_//;
		if("\L$_" eq "\L$last"){	$em.=", $_";	}
		else{
			$em.= "$_";
			$starting=1;
		}
		$last=$_;
	}
	$em.= "\nIf you are sure that the comparer you entered is contained within your log file OR if no queries are listed as being present in the log file other problems may exist, including:\nThe file permissions on your log file may be to restrictive (may be problematic if file is stored on a server).\nYour log file may just be empty.\nPlease close this dialog and try again.\n";
	die $em;
}
# verify that every experimental plate has a corresponding control plate...
# also setup plate_order array, used to ensure that control plates are present first
# also verify that all plates contain the same amount of data and that the number of data in each plate
# is appropriate
my $o_control=$variables->{'control'};
$variables->{'plate_names'}=();
$o_control=~ s/0000_//; # strip out leading '0000_' 
{
	my $expQueryCount=0;
	no warnings 'numeric';
	foreach my $plate(sort {$a<=>$b} keys %plate){
		foreach my $query(sort keys %{ $plate{$plate} }){
			foreach my $condition(sort keys %{ $plate{$plate}->{$query} }){
				$variables->{'total_number_plates'}++;
				my $cleanQuery = $query;
				$cleanQuery =~ s/^0000_//; # strip out leading '0000_' 
				if(! defined $condition || $condition eq ''){
					my %tempHash=('plateNum'=>$plate, 'query'=>$cleanQuery, 'condition'=>'');
					push (@{$variables->{'plate_order'}}, {%tempHash});
				}
				else{
					my %tempHash=('plateNum'=>$plate, 'query'=>$cleanQuery, 'condition'=>$condition);
					push (@{$variables->{'plate_order'}}, {%tempHash});
				}
				if($cleanQuery eq $o_control){next;}
				$expQueryCount++;
				if(! defined $plate{$plate}->{$variables->{'control'}}->{$condition}){
					my $plateLabel = $variables->{'originalData'}->{$plate}->{$cleanQuery}->{$condition};
					my $info = (defined $condition && $condition ne '') ? "$plateLabel->{'plateNum'}, $plateLabel->{'query'}, $plateLabel->{'condition'}" : "$plateLabel->{'plateNum'}, $plateLabel->{'query'}";
					die("There is no matching comparer plate for $info (comparer = $o_control).\nEither add the corresponding comparer data from your log file or delete the data for $info from your log file.");
				}
			}
		}
	}
	if($expQueryCount < 1){
		die("There are no experimental plates present in your log file (i.e. only comparer data is present). Comparer = $o_control).\nPlease add experimental data to your log file and try again.");
	}
}
	
if($mode eq 'review'){
	# verify that the density is an acceptable value, set the number of rows and column for a particular density
	# $outer_ring_size = the number of colonies in the 2nd most outer ring of a plate
	if($variables->{'key_choice'} eq 'custom'){
		$DENSITY_REPLICATES{$variables->{'key_choice'}}[0] = $variables->{'c_density'}; # custom density entered by user, set in &validateKeyChoice
		$DENSITY_REPLICATES{$variables->{'key_choice'}}[1] = $variables->{'c_replicates'};
	}
	if($variables->{'density'}==384 && $DENSITY_REPLICATES{$variables->{'key_choice'}}[0] == 384){$variables->{'rows'}=16;$variables->{'cols'}=24; $variables->{'num_to_display'}=20; $variables->{'cell_size'}=25;}
	elsif($variables->{'density'}==1536 && $DENSITY_REPLICATES{$variables->{'key_choice'}}[0] == 1536){$variables->{'rows'}=32;$variables->{'cols'}=48; $variables->{'num_to_display'}=4; $variables->{'cell_size'}=15;}
	elsif($variables->{'density'}==2304 && $DENSITY_REPLICATES{$variables->{'key_choice'}}[0] == 2304){$variables->{'rows'}=48;$variables->{'cols'}=48; $variables->{'num_to_display'}=4; $variables->{'cell_size'}=15;}
	elsif($variables->{'density'}==96 && $DENSITY_REPLICATES{$variables->{'key_choice'}}[0] == 96){$variables->{'rows'}=8;$variables->{'cols'}=12; $variables->{'num_to_display'}=30; $variables->{'cell_size'}=50;}
	else{
		die "Impossible density calculated or key file does not match density. Density entered = $variables->{'density'}.  Key file = $variables->{'key_choice'}\n";
	}
	$variables->{'lastPage'}= int($variables->{'total_number_plates'} / $variables->{'num_to_display'} + 0.9999);
	# assuming that the key_file and density were properly assigned, we can now assign the # of replicates
	$variables->{'replicates'}=$DENSITY_REPLICATES{$variables->{'key_choice'}}[1]; # informative string (ie 1,2h,2v,4,16)
	&calcCollapsedRowsAndCols($q, $variables);
	$variables->{'key_file_name'}=$DENSITY_REPLICATES{$variables->{'key_choice'}}[2]; # actual key file name
}
else{
	if($variables->{'density'}==384){$variables->{'data_rows'}=16;$variables->{'data_cols'}=24;$variables->{'cell_size'}=25;}
	elsif($variables->{'density'}==1536){$variables->{'data_rows'}=32; $variables->{'data_cols'}=48; $variables->{'cell_size'}=13;}
	elsif($variables->{'density'}==96){$variables->{'data_rows'}=8;$variables->{'data_cols'}=12;$variables->{'cell_size'}=30;}
	else{
		die "Invalid density: $variables->{'density'}.  $!\n";
	}
}

# if the "Designated controls" method was chosen to normalize data to, do that now...
if($variables->{'normalization_method'} eq 'controls'){
	&calculateNormalizeToControlValues($q, $variables,$controlLocations, \%normalization_values, \%plate);
}
