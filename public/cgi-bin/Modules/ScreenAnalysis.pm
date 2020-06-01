package Modules::ScreenAnalysis;
use strict;
use base qw(Exporter);

our @EXPORT = qw( is_numeric connectToMySQL get_sql_types get_db_name generic_message contact_admin try_again_or_contact_admin return_to_dr initialize update_error update_message validateUser getBaseDirInfo jsRedirect
	setSession static_asset_path); # access these using 'use Modules::ScreenAnalysis'
our @EXPORT_OK = qw(verifyDir is_numeric setupDynamicVariables checkForGlobalExclusion checkForReplicateExclusion send_results
	 									setupReviewLoadingPage update_message line_break_check update_error saveDRprogress getBaseDirInfo
										bookkeeper directory_setup printReviewCartoon setupKeyFile setupSQLite generateDescriptiveStats rollback_now
										calculateControlExperimentalRatios crunchNormalStatsAndOutput commitDB deleteSession findGOEnrichment setSession
										processOutAllFile processLogFile printComparisonCartoon setupFlashDIVS checkSelectedSets validateKeyChoice
										update_done initialize generic_message contact_admin return_to_dr getArrayMedian calculateOtherStatsAndOutput
										trimErroneousCharactersAtEnds get_sql_types mysql_setup_dr_experiment static_asset_path get_db_name);
our %EXPORT_TAGS = (	all	=>	[ @EXPORT, @EXPORT_OK ],
	 										validation => [@EXPORT, qw(line_break_check bookkeeper directory_setup processLogFile validateKeyChoice) ],
        							review	=>	[@EXPORT, qw(saveDRprogress setupDynamicVariables checkForGlobalExclusion checkForReplicateExclusion setupReviewLoadingPage printReviewCartoon) ],
        							analysis => [
																	 @EXPORT, qw( saveDRprogress setupDynamicVariables checkForGlobalExclusion checkForReplicateExclusion send_results setupKeyFile setupSQLite
																								generateDescriptiveStats calculateControlExperimentalRatios crunchNormalStatsAndOutput rollback_now commitDB
																								deleteSession findGOEnrichment setupFlashDIVS calculateOtherStatsAndOutput mysql_setup_dr_experiment get_db_name)
																	 ], # access these using 'use Modules::ScreenAnalysis qw(:analysis);'
											sv_engine => [@EXPORT, qw(directory_setup processOutAllFile processLogFile printComparisonCartoon setupFlashDIVS checkSelectedSets)],
											fileDL => [@EXPORT, qw(checkSelectedSets update_done)],
											sessions => [@EXPORT, qw(bookkeeper) ],
											facs_analysis_setup => [@EXPORT, qw(line_break_check bookkeeper directory_setup getArrayMedian)],
											facs_analysis => [@EXPORT],
											light => [@EXPORT],
											histogram => [@EXPORT, qw(directory_setup checkForGlobalExclusion checkForReplicateExclusion update_done)],
											clik => [@EXPORT, qw(directory_setup verifyDir)],
											sqlOnly => [qw(connectToMySQL get_sql_types static_asset_path get_db_name)],
											asset => [qw(static_asset_path)],
											uploadFiles => [qw(connectToMySQL get_sql_types get_db_name is_numeric initialize validateUser trimErroneousCharactersAtEnds )]
        						);

# setup an alphabet array so that rows can be associated with the proper letter designation
my @alphabet=("A".."ZZ");
## **************************************************************************

sub generic_message{return 'The program has encountered an error and cannot continue.<br/>'.contact_admin();}
sub contact_admin {return '<div>Please <a style=\'display:inline;\' href=\'mailto:admin@rothsteinlab.com\'>contact the administrator</a> for further assistance.</div>';}
sub return_to_dr {return '<a href=\'dr_engine_setup\'>Back to <i>ScreenMill - <b>D</b>ata <b>R</b>eview Engine</i></a>';}
sub try_again_or_contact_admin {return '<div>Please try again or <a style=\'display:inline;\' href=\'mailto:'.&admin_email().'\'>contact the administrator</a> for further assistance.</div>';}
sub admin_email{return 'admin@rothsteinlab.com';}

my %MIMES=(
						'text/csv'=>1,
						'text/plain'=>1,
						'application/text'=>1
					);

my %DENSITY_REPLICATES=(
 								 'r1536'=>['1536','4', 'HB_alpha' ],
								 'r1536a'=>['1536','4', 'MATaKEY' ],
								 'rhb_1rep'=>['384','1', 'HB_alpha'],
								 'r96_1rep'=>['96', '1', 'rothstein_deletion_alpha'],
							 	 'r96a_1rep'=>['96','1' , 'MATa_names'],
								 'r96a_4rep'=>['384','4', 'MATa_names'],
								 'r384'=>['384','4', 'rothstein_deletion_alpha'],
								 'c384'=>['384','4', 'curie_deletion_alpha'],
 								 'dampa'=>['1536','4', 'dampLibKey'],
								 'dpi'=>['1536','16', 'DPI_array'],
								 'hietermata'=>['1536','1', 'HieterMATa'],
								 'lisby384'=> ['384','1', 'Lisby_mat_a'],
								 'lisby1536'=> ['1536','4', 'Lisby_mat_a'],
								 'r1536ts_a'=> ['1536','4', 'tsMATaKeyFile'],
								 'custom'=>['','', 'custom'],
								 'none'=>['','', 'none']
								);

our %NUM_REPLICATES = (	'2h' => 2,
												'2v' => 2,
												'4' => 4,
												'1' => 1,
												'16' => 16);

my %POSSIBLE_DENSITIES = (	'1536' => 1536,
												'384' => 384,
												'96' => 96,
												'2304' => 2304	);

my %POSSIBLE_KEY_ROW_COLS = (
													'2304' => {'rows' => 48, 'cols' => 48},
													'1536' => {'rows' => 32, 'cols' => 48},
													'768' => {'2v' =>
																			{'rows'=> '16', 'cols' => '48'},
																		'2h' =>
																			{'rows'=> '32', 'cols' => '24'}
																		},
													'384' => {'rows'=>16, 'cols' => '24'},
													'192' => {'2v' =>
																			{'rows'=> '8', 'cols' => '24'},
																		'2h' =>
																			{'rows'=> '16', 'cols' => '12'}
																	 },
													'96' => {'rows'=>8, 'cols' => '12'}
);

my $RELATIVE_ROOT="tools";
my $DB = 'rothstei_rails4';
my $PUBLIC_KEY_DIR="../../tools/key_files";
my $EXCLUDE_PLATE_CUTOFF = 0.35; # this is a percent...of more then this value of a plate has been excluded the EXCLUDE THE ENTIRE PLATE!!!!
## **************************************************************************

sub get_db_name{return $DB;}

sub connectToMySQL{
	use DBI;
	my $db=$DB;
	my $host="127.0.0.1";
	my $userid="rothstei_website";
	my $passwd='Bh*4uG#ljF7dVwVgZ$2P';
	my $connectionInfo="dbi:mysql:$db;host=$host";
	my $dbh;
	eval{$dbh = DBI->connect("$connectionInfo", "$userid", "$passwd", {RaiseError => 1, AutoCommit => 0, mysql_enable_utf8 => 1});};
	if($@){
		warn $@;
		return undef;
	}
	# $dbh->{TraceLevel} = 2;
	return $dbh;
}

sub get_sql_types{
	use DBI qw(:sql_types);
	my %sqlTypes = (
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
sub initialize{
	my ($q,$size) = @_;
	my $error = $q->cgi_error;
	if ($error) {
		if(!$q->{'.header_printed'}){	print $q->header();}
		if($error =~ /413/ig){ # this is pretty pointless since the program will exit immediately if the file size is too large
			&update_error('Cannot proceed, 413 Error.<br/>This error occurs if the files you are uploading are to large.<br/> There is currently a '.$size.'mb size combined file size limit. Please reduce the size of your files and try again.<br/>If cannot reduce the size of your files please <a style=\'display:inline;\' href=\'mailto'.&admin_email().'\'>contact the administrator</a> for assistance.<br/><br/>'.return_to_dr(), $q);
		}
		else{
			&update_error('Cannot proceed, 400 Error.<br/>Sometimes this error occurs if a file you are trying to upload is currently open in another application. If this is the case please close the file and try again.<br/>If you repeatedly encounter this error or are not attempting to upload a file, <a style=\'display:inline;\' href=\'mailto:'.&admin_email().'\'>contact the administrator</a>.<br/><br/>'.return_to_dr(), $q);
		}
		warn "CGI Error: $error";
		return 0;
	}
	foreach(keys %{$q->{'.tmpfiles'}}){
		if(! defined $MIMES{"\L$q->{'.tmpfiles'}->{$_}->{'info'}->{'Content-Type'}"} && "\L$q->{'.tmpfiles'}->{$_}->{'info'}->{'Content-Disposition'}" !~ /\.txt"$/){
			my @info = split/\s/;
			if(!$q->{'.header_printed'}){	print $q->header();}
			&update_error('The file '.join(" ", @info[1..$#info]).' seems to be an invalid file format. Please ensure that you are only uploading plain text files (files should have a .txt file extension).<br/>If you repeatedly encounter this error or are not attempting to upload a file, <a style=\'display:inline;\' href=\'mailto:'.&admin_email().'\'>contact the administrator.</a><br/><br/>'.return_to_dr(), $q);
			#warn "MIME Type error ".join(" ", @info[1..$#info])."--> $_ ---> "."\L$q->{'.tmpfiles'}->{$_}->{'info'}->{'Content-Type'}";
			#use Data::Dumper;
			#warn Dumper($q->{'.tmpfiles'}->{$_});
			return 0;
		}
	}
	return 1;
}

sub setupDynamicVariables{
	use HTML::Entities;use Encode qw(encode_utf8);
	# $excluded_colonies_ref->{$i}[0] <-- true of false (excluded or not)
	# $excluded_colonies_ref->{$i}[1] <-- have we examined this colony yet?
	# $excluded_colonies_ref->{$i}[2] <-- are we in at a border?
	# $excluded_colonies_ref->{$i}[3] <-- are we in a corner?
	my ($acs,$dv,$q,$variables)=(@_); # $q = CGI instance, $dv = reference to %dynamic_variables, $variables = %variables
	# $acs == normalization values?
	# use Data::Dumper;
	# warn Dumper $acs;
	# starting is set in referal page that is not dr_engine/main.cgi (i.e. )
	if($dv->{'current_page'} ne $dv->{'from_page'} && !$dv->{'starting'}){
		my ($pos,$p,$query,$c, $current_excluded_comp, %current_excluded_user);

		# validate $excludeList
		if ($q->param("exclusionList")){
			my $els=encode_utf8(decode_entities($q->param("exclusionList"))); # hold the colonies that have been excluded from statistical consideration
			# get rid of preceeding and trailing tags...
			$els =~ s/^\*-\*//;
			$els =~ s/\*-\*$//;
			$els = lc($els);
			foreach my $el((split/\*-\*/,$els)){
				# warn $els;
				($query,$p,$c,$pos)=split(/,/, $el); # 0 = $p, 1 = $q, 2 = $c, 3 = number position in plate
				$p = uc($p);
				$c = '' if(! defined $c);
				if(! defined $acs->{$p}->{$query}->{$c}){warn "failed here -> $p,$query,$c,$pos\n"; next;} # check that plate,query,condition combo is valid
				if($pos !~  m/^[0-9]{1,4}$/){warn "failed here2 -> $el\n"; next;}# check valid position (1-4 numbers)
				$current_excluded_user{"$p,$query,$c,$pos"}=1;
				if(!defined $dv->{'excluded_colonies'}->{$p}->{$query}->{$c}->{$pos}[0] || $dv->{'excluded_colonies'}->{$p}->{$query}->{$c}->{$pos}[0] == 0){
					$dv->{'excluded_colonies'}->{$p}->{$query}->{$c}->{$pos}[0]=1; # set to one since we have manually excluded this...
				}
			}
		}

		use Storable qw(retrieve); # the storable data persistence module
		# current_excluded is made when the plates are initially drawn and the computer automatically determines exclusion
		# if a colony exists in this structure but not in current_excluded_user then it must have been re-introduced by the user.
		if( -e "$variables->{'save_directory'}/current_excluded.dat"){
			$current_excluded_comp = eval {retrieve("$variables->{'save_directory'}/current_excluded.dat")};
			if($@){ warn 'Serious error from Storable, retrieve @current_excluded';}
	  }

		foreach my $e(@{$current_excluded_comp}){
			if(! defined $current_excluded_user{$e}){ # this colony not in ec and it is in @e, it means that the user has chosen to re-introduce it
				($p,$query,$c,$pos)=split(/,/,$e);
				$p = uc($p);
				$dv->{'excluded_colonies'}->{$p}->{$query}->{$c}->{$pos}[0]=0; # set to zero since we have manually included this...
			}
		}

		# validate killedPlates
		%current_excluded_user=();
		if($q->param("killedPlateList")){
			my $kps=encode_utf8(decode_entities($q->param("killedPlateList"))) ; # hold the plates that have been excluded from statistical consideration
			$kps =~ s/^\*-\*//;
			$kps =~ s/\*-\*$//;
			foreach my $kp((split/\*-\*/,$kps)){
				my @kp_params = split(/,/,$kp); # 0 = query, 1 = plate number, 2 = condition
				$kp_params[2] = '' if ! defined $kp_params[2];
				if(! defined $acs->{$kp_params[1]}->{$kp_params[0]}->{$kp_params[2]}){next;} # check that plate,query,condition combo is valid
				$dv->{'excluded_plates'}->{$kp}=1;
				$current_excluded_user{$kp}=1;
			}
		}

		if($dv->{'from_page'}){
			my $ref_control = $variables->{'control'}; # remove 0000_ tag used to present controls first
			$ref_control =~ s/^0000_//;
			# start and limit will help define the plates that we will be viewing on the current page
			my $start=(($dv->{'from_page'}-1)*$variables->{'num_to_display'});
			my $limit = ($#{$variables->{'plate_order'}}+1)<($start+$variables->{'num_to_display'}) ? ($#{$variables->{'plate_order'}}+1) : ($start+$variables->{'num_to_display'});
			for(my $p=$start; $p<$limit; $p++){
				# iterate over plates from previous page. If plate ($holder) is not in BOTH %current_excluded_user and $dv->{'excluded_plates'} then that plate should not be excluded
				my $plateInfo = ${$variables->{'plate_order'}}[$p];
				# plateInfo is a hash --> 'plateNum'=>plate, 'query'=>query, 'condition'=>condition
				#  plateNum is already been capitalized when initialized, so no problem
				my $holder = $plateInfo->{'query'};
				# plate = 0, query = 1, condition = 2
				$holder=~ s/^0000_// if $holder eq $variables->{'control'}; # remove 0000_ tag used to present controls first
				#$temp[2] = '' if ! defined $temp[2];
				$holder = "$holder,$plateInfo->{'plateNum'},$plateInfo->{'condition'}";
				if(! defined $current_excluded_user{$holder} && $dv->{'excluded_plates'}->{$holder}){
					delete $dv->{'excluded_plates'}->{$holder};
					if($holder eq $ref_control){
						foreach my $ePlate(keys %{$dv->{'excluded_plates'}}){
							if($ePlate =~ /$holder,ce$/){
								delete $dv->{'excluded_plates'}->{$ePlate};
							}
						}
					}
				}
				elsif(! defined $current_excluded_user{"$holder,$ref_control,$plateInfo->{'plateNum'},$plateInfo->{'condition'}"} &&
				 					$dv->{'excluded_plates'}->{"$holder,$ref_control,$plateInfo->{'plateNum'},$plateInfo->{'condition'}"}){
					delete $dv->{'excluded_plates'}->{"$holder,$ref_control,$plateInfo->{'plateNum'},$plateInfo->{'condition'}"};
				}
			}
		}

	}
	# return 1;
}
sub globalCrawlInteriorForExclusion{
	no warnings 'recursion';
	# $i = current position, $rows = number of rows of data, $cols = number of columns of data [note $rows * $cols = density screened in]
	# data = array containing all data of current plate
	# $ecRef = reference to data structure that contains exclusion info of current plate (see checkForGlobalExclusion sub routine for more details)
	# $deadSize = calculated deadSize threshold of current plate
	my($i, $rows, $cols, $data, $ecRef, $deadSize) = @_;
	# if we have already examined this colony do not look at it again...
	#unless(${$ecRef->{$i}}[1]){
		# check to make sure we are not in the top, bottom, left or right borders
		if(!( ($i % $rows) == 0 || (($i+1) % $rows)==0 || $i<$rows || $i>($cols*$rows-$rows) )) {
			# below, above, right, bottom-right, top-right, left, bottom-left, top-left
			my @surroundingPositions=($i+1,$i-1,$i+$rows,$i+$rows+1,$i+$rows-1,$i-$rows,$i-$rows+1,$i-$rows-1);
			my ($deadCounter, $surroundingFlag)=(0,0);
			if($data->[$i] <= $deadSize){
				foreach my $pos(@surroundingPositions){
					# if pos is < deadSize
					if($data->[$pos] <= $deadSize){	$deadCounter++;	}
					if(${$ecRef->{$pos}}[0]){	$surroundingFlag++;	}		# if pos has been excluded
				}
				if( $deadCounter>=6 || $surroundingFlag>=2){
					${$ecRef->{$i}}[0]=1;
					# call recursively on surrounding data...
					foreach my $pos(@surroundingPositions){
						# if this guy has already been excluded then it's surroundings have already been checked...
						if(! defined ${$ecRef->{$pos}}[0]){	&globalCrawlInteriorForExclusion($pos, $rows, $cols, $data, $ecRef, $deadSize); }
					}
					return 1;
				}
			}
		}
		${$ecRef->{$i}}[0]=0;
	#}
	return 0;

}

sub checkForGlobalExclusion{
	# should add check to verifiy that correct data is being passed to this program...
	# $excluded_colonies_ref->{$i}[0] <-- true of false (excluded or not)
	# $excluded_colonies_ref->{$i}[1] <-- have we examined this colony yet?
	# $excluded_colonies_ref->{$i}[2] <-- are we in at a border?
	# $excluded_colonies_ref->{$i}[3] <-- are we in a corner?
	my($data, $excluded_colonies_ref, $dead_size, $density, $rows, $cols, $plateLabel, $q)=@_;
	my ($current_row,$current_col);
	my $top_edge_limit=$rows-1; # if we are on top edge then avoid values whose $i % $rows == $top_edge_limit (these would be equivalent to guys on the bottom row of the previous column)

	if(!defined($dead_size)){
		if(! defined $plateLabel->{"condition"} || $plateLabel->{"condition"} eq ''){$plateLabel->{"condition"} = "-";}
		&update_error('The program has encountered an error (No dead size for plate: '.$plateLabel->{"plateNum"}.', query: '.$plateLabel->{"query"}.', condition: '.$plateLabel->{"condition"}.') and needs to quit.<br/>'.&contact_admin().'<br/>'.&return_to_dr(), $q);
		exit;
	}

	# check to make sure we are not in the top, bottom, left or right borders
	# we will come back to the border after the interior analysis is completed
	for(my $i=0;$i<$density;$i++){
		# if this guy has already been excluded then it's surroundings have already been checked...
		if(! defined ${$excluded_colonies_ref->{$i}}[0]){	&globalCrawlInteriorForExclusion($i, $rows, $cols, $data, $excluded_colonies_ref, $dead_size);	}
	}

	my ($flag, $tempI, $bottom_edge_flag,$top_edge_flag,$alive_surrounding_flag,$modulus,%corners,$dead_counter,$surrounding_flag);
	%corners=(0 => 1, ($rows-1)=>1, ($density-1)=>1, ($density-1-$rows)=>1);
	# now check borders
	for(my $i=0;$i<$rows;$i++){
		# how to tell what position you are in [if statement to avoid these positions]:
		#		$tempI+1 == $rows --> bottom row  [($tempI+1) != $rows]
		#		$tempI==0 -->  top row [$tempI!=0]
		#		($current_col+1) == $cols --> right-most column [($current_col+1) == $cols]
		#		$current_col==0 --> left-most column [$current_col!=0]
		#	Exclude the following if we are in the positions indicated:
		#	top-left ->  $i-1 && $i-rows
		#	top-right -> $i-1 && $i+rows
		#	bottom-left -> $i+1 && $i-$rows
		#	bottom-right -> $i+1 && $i+$rows
		#	top row -> $i-1
		#	bottom row -> $i+1
		#	left -> $i-$rows
		#	right -> $i+$rows
		$current_col=0;
		$flag=0;
		$tempI=$i;
		$bottom_edge_flag=0;
		$top_edge_flag=0;
		if($i % $rows == 0){$top_edge_flag=1;}
		if(($i+1) % $rows == 0){$bottom_edge_flag=1;}
		while(!$flag){
			# if we have already examined this colony do not look at it again...
			#unless(${$excluded_colonies_ref->{$i}}[1]){
				# below, above, right, bottom-right, top-right, left, bottom-left, top-left
				my @colony_positions=($i+1,$i-1,$i+$rows,$i+$rows+1,$i+$rows-1,$i-$rows,$i-$rows+1,$i-$rows-1);
				($surrounding_flag, $alive_surrounding_flag, $dead_counter)=(0,0,0);
				foreach my $pos(@colony_positions){
					$modulus=($pos % $rows);
					if(( defined($data->[$pos]) && $pos >= 0 ) && (!$bottom_edge_flag || $modulus != 0) && (!$top_edge_flag || $modulus != $top_edge_limit)){ # avoids going 'out of bounds'
						if($data->[$pos] <= $dead_size){
							if(${$excluded_colonies_ref->{$pos}}[0]){$surrounding_flag++;} # I'm dead and excluded
							$dead_counter++;
						}
						elsif(${$excluded_colonies_ref->{$pos}}[0]){$alive_surrounding_flag++;} # I'm alive, but excluded
					}
				}
				${$excluded_colonies_ref->{$i}}[2]=1; # add marker to indicate that this is a border colony
				if ($corners{$i}){${$excluded_colonies_ref->{$i}}[3]=1;} # add marker to indicate that we are at a corner
				# if there are 2 or more dead guys around me that have been excluded OR if there are 3 living guys
				# around me that have been excluded, exclude me
				if($surrounding_flag>=2 || $alive_surrounding_flag>=3) {
					${$excluded_colonies_ref->{$i}}[0]=1;
					foreach my $pos(@colony_positions){
						$modulus=($pos % $rows);
						if(( defined($data->[$pos]) && $pos >= 0 ) && (!$bottom_edge_flag || $modulus != 0) && (!$top_edge_flag || $modulus != $top_edge_limit)){ # avoids going 'out of bounds'
							if($data->[$pos] <= $dead_size && (!${$excluded_colonies_ref->{$pos}}[0])){
								&globalCrawlInteriorForExclusion($pos, $rows, $cols, $data, $excluded_colonies_ref, $dead_size);
							}
						}
					}
				}
				else{${$excluded_colonies_ref->{$i}}[0]=0;}#${$excluded_colonies_ref->{$i}}[0]=0;
			#}
			if($tempI==0 || ($tempI+1)==$rows){ # if we are in 1st or last row (top or bottom)
				if($current_col<($cols-1)){ # move over 1 column
					$current_col++;
					$i=$i+$rows;
				}
				else{ # just iterated last column, exit loop
					$flag=1;
					$i=$tempI;
				}
			}
			else{ # we are in left or right columns
				if($current_col eq ($cols-1)){ # just iterated last row, exit loop
					$flag=1;
					$i=$tempI;
				}
				else{
					$i=$density-($rows-$i); # move down one row
					$current_col = ($cols-1);
				}
			}
		}
	}
	return 1;
}

sub printReviewCartoon{
	my($data, $dv, $control, $plate, $query, $condition, $v, $ratio_cutoff, $normalization_value, $current_excluded, $mode, $q, $plateDisplayIndex)=@_;
	# if $v->{'normalization_method'} eq 'nothing' just normalize to median for cartoon printing
	my $plateLabel = $v->{'originalData'}->{$plate}->{$query}->{$condition};
	if($v->{'normalization_method'} eq 'nothing'){	$normalization_value=&getArrayMedian($data,0);}
	if(! $normalization_value){$normalization_value=1;}

	# elsif($normalization_value == 0){
	# 	warn "$v->{'normalization_method'} -- $plate,$query,$condition --> $normalization_value\n";
	# }

	my $dead_size = $v->{'death_threshold_cutoff'} * $normalization_value; # dead_size actually gets passed to this method as death_threshold_cutoff
	my($html, $current_col, $current_row)=('',0,0);
	my($pos,$exclude_flag,$ratio,$color_ratio, $humanColumn, $colSpan, $extraTDstyle, $excludeCount);
	my $excludeList='';
	my $excludeCutoff = $v->{'density'} * $EXCLUDE_PLATE_CUTOFF; # if exclude count for the current plate > excludeCutoff then exclude the entire plate...this feature not yet fully implimented

	$html.= &printColumnHeadings($plate, $query, $condition, $plateLabel, $v->{'cols'},$v->{'replicates'},$plateDisplayIndex);

	my $asset_prefix = &static_asset_path();
	# *********************** START footer **********************************************
	$html.="<tfoot><tr>\n\t";
	# td so that all cells are same size...
	$html.=  "<td class='blankCellBottom'>&nbsp</td><td class='blankCellBottom'> &nbsp; </td>\n";
	for( my $i=1;$i<=$v->{'cols'};$i++){$html.=  "<td class='blankCellBottom'><img src='$asset_prefix->{'images'}/colonies/blank.png' width=\"$v->{'cell_size'}\" height=\"$v->{'cell_size'}\" /></td>\n";}
	$html.=  "</tr></tfoot><tbody>";
	# *********************** END footer ************************************************

	my $runRepExclusion=1;
	if((defined $dv->{'plates_reviewed'}->{"$plate,$query,$condition"} && $dv->{'plates_reviewed'}->{"$plate,$query,$condition"} == 1) || $v->{'replicateExclusion'} != 1){
		$runRepExclusion = 0;
	}

	$colSpan = 1;
	$extraTDstyle='';
	if($v->{'replicates'} eq '2h' || $v->{'replicates'} eq '1'){
		$extraTDstyle = 'style="border-left:1px solid black;"';
	}
	my $extraClass='';
	my $rowSpan = ($v->{'replicates'} eq '16') ? 4 : 2;
	if($v->{'rows'} >=24){$extraClass=" small";}

	for(my $i=1;$i<=$v->{'rows'};$i++) {
		$html.=  "<tr>\n\t"; # row title
		if($v->{'replicates'} eq '4' || $v->{'replicates'} eq '2v'  || $v->{'replicates'} eq '16'){ # row title
			if($i % $rowSpan==1){$html.=  "\t<td rowspan='$rowSpan' class='reps rowHead$extraClass'>$alphabet[($i/$rowSpan)] </td>";}
		}
		else{$html.=  "\t<td class='blankCellRight'></td>";}
		if($v->{'density'}==1536){$html.=  "\t<td class='a1536 rowSubHead$extraClass' colspan='$colSpan' $extraTDstyle> $alphabet[$i-1] </td>";}
		else{$html.=  "\t<td  class='other rowSubHead$extraClass'>$alphabet[$i-1]</td>";}

		while($current_col<$v->{'cols'}){
			$pos=($i-1)+($current_col*$v->{'rows'});

			# only look for death amoung replicates if we have 2, 4 || 16 replicates AND if this position has not already been examined
			# set_pos = integer representing letter in alphabet:
			# A (0), B (1), C (2), D (3), E(4), F(5), G(6), H(7), I(8), J(9), K(10), L(11), M(12), N(13), O(14), or P(15)
			#  use $dynamicVariables->{'plates_reviewed'}->{"$plate,$query,$condition"} to determine if rep has been excluded or not
			my ($set_pos, $repPositions) = &checkForReplicateExclusion(
													$dv->{'excluded_colonies'}->{$plate}->{$query}->{$condition},
													$v->{'rows'}, $dead_size, $data,
													$current_col, $current_row,	$pos,
													$v->{'replicates'},$runRepExclusion,$rowSpan, $q
				);
			$humanColumn=$current_col+1;
			if(${$dv->{'excluded_colonies'}->{$plate}->{$query}->{$condition}->{$pos}}[0]){
				$exclude_flag='eSingle';
				push(@{$current_excluded},"$plate,$query,$condition,$pos");
				$excludeCount++; # exclusion counter
				$excludeList.="*-*$plateLabel->{'query'},$plateLabel->{'plateNum'},$plateLabel->{'condition'},$pos,$alphabet[$i-1]$humanColumn";
			}
			else{$exclude_flag='';}

			# presumably controls for this plate have already been printed...if this is NOT a control plate, check $excluded_coloies_ref
			# to see if all control replicates of the currently printed colony have been excluded, if so add the appropriate class to
			# exclude flag....NOTE ==> $control had 0000_ stripped out of it before it was passed to this routine
			if($query ne $control){
				my $c_counter=0;
				foreach my $position(@{$repPositions}){$c_counter++ if(${$dv->{'excluded_colonies'}->{$plate}->{$control}->{$condition}->{$position}}[0]);}
				if($c_counter == $NUM_REPLICATES{$v->{'replicates'}}){$exclude_flag.= ' ce';}
			}

			# mark this position as being examined...
			#	dont need to do this any more since we are not using $dynamicVariables->{'plates_reviewed'}->{"$plate,$query,$condition"}
			# ${$dv->{'excluded_colonies'}->{$plate}->{$query}->{$condition}->{$pos}}[1]=1;

			$ratio=($data->[$pos] / $normalization_value)*$v->{'cell_size'};
			($color_ratio, $ratio) = &getColSize($ratio, $v->{'cell_size'});
			if ($ratio <= $ratio_cutoff  ) {$exclude_flag.=' low'} # if this is a 'dead' colony, mark it as such (yellow background)
			$html.=  "<td id=\"p$plateDisplayIndex-$pos-$repPositions->[0]\" alt=\"$data->[$pos]\"  title=\"$alphabet[$i-1]$humanColumn\" class=\"$exclude_flag";

			#++++++++ start borders for 2 or 4 replicates +++++++++
			if ( $current_col % $rowSpan==0 || $v->{'replicates'} eq '2v' || $v->{'replicates'} eq '1'){ $html.= " bl";} # add left border
			if($v->{'replicates'} eq '4' || $v->{'replicates'} eq '2v' || $v->{'replicates'} eq '16'){
				if ($current_row % $rowSpan == 0 ){ $html.= " bt";} # add top border
				else{$html.= " nb";} # no extra border
			}
			else{$html.= " bt";} # add top border
			#++++++ end borders for 2 or 4 replicates +++++++++++

			$html.= " col\" "; # close style tag from last td
			$html.= "><img src='$asset_prefix->{'images'}/colonies/colony_".$color_ratio.".png' width=".($ratio+0.5)." height=".($ratio+0.5)." /></td>";
			$current_col++;
		}
		# td so that all cells are same side...
		$html.=  "\n<td class='blankCellRight'><img src='$asset_prefix->{'images'}/colonies/blank.png' width=\"$v->{'cell_size'}\" height=\"$v->{'cell_size'}\" /></td>\n";
		$html.=  "</tr>\n";
		$current_col=0;
		$current_row++;
	}

	$html.= "</tbody>";
	$html.="</table></div><br/><br/>";

	use Encode qw(decode_utf8 encode HTMLCREF);
	print encode('ascii', decode_utf8($html), HTMLCREF);
	return $excludeList;
}

# check_replicate_growth and check_positions
# check to se what position we are at (A,B,C, or D).  Figure out the current colony's positions relative to the
# other colonies in the same set.
# If a significant number of THIS colonys neighbors have already been excluded, then exclude it
# If the current colony size is significantly different then the other replicates then exclude it
# in 4 replicates the colony positions are as follows:
#       A C
#       B	D
sub checkForReplicateExclusion{
	# $excluded_colonies_ref->{$i}[0] <-- true of false (excluded or not)
	# $excluded_colonies_ref->{$i}[1] <-- have we examined this colony yet?
	# $excluded_colonies_ref->{$i}[2] <-- are we in at a border?
	# $excluded_colonies_ref->{$i}[3] <-- are we in a corner?
	my $size = @_;
	my $q = pop;
	my $set_position;
	if($size == 11){
		my ($excluded_colonies_ref,$rows,$dead_size,$data,$curCol, $curRow,$position, $reps, $runReplicateExclusion, $modDivisor)=@_;
		if($reps ne '1'){
			return &check_replicate_growth($position,$excluded_colonies_ref,$curCol, $curRow,$rows,$dead_size, $data, $reps, $runReplicateExclusion, $modDivisor);
		}
		#${$excluded_colonies_ref->{$position}}[0]=0;
		my @temp=($position);
		return (0, \@temp);
	}
	elsif($size == 9){ # scan entire plate (ALL COLONIES), since everything is sent as references, nothing actually needs to be returned
		my ($excluded_colonies_ref,$rows,$cols,$dead_size, $data,$reps, $runReplicateExclusion, $modDivisor)=@_;
		if($reps ne '1'){
			my($curCol, $curRow, $position);
			$curCol=0;
			$curRow=0;
			for(my $i=1;$i<=$rows;$i++){
				while($curCol<$cols){
					$position=($i-1)+($curCol*$rows);
					$set_position=&check_replicate_growth($position,$excluded_colonies_ref,$curCol,$curRow,$rows,$dead_size, $data,$reps,$runReplicateExclusion, $modDivisor);
					$curCol++;
				}
				$curCol=0;
				$curRow++;
			}
		}
		return 1;
	}
	else{
		&update_error('The program has encountered an error (wrong number of arguments for checkForReplicateExclusion: '.$size.') and needs to quit.<br/>'.&contact_admin().'<br/>'.&return_to_dr(), $q);
		die "Wrong number of arguments for checkForReplicateExclusion ($size). \n";
	}
	return 0; # should never get here
}

sub check_replicate_growth{
	my ($position,$excluded_colonies_ref,$curCol,$curRow,$rows,$dead_size, $data,$reps,$runReplicateExclusion, $modDivisor)=@_;

	# ************************************************************************************************************
	# ************************************ DETERMINE REPLICATE POSITION ******************************************
	# ************************************************************************************************************
	my $replicatePosition=0;
	# modDivisor == 2 unless 16 replicates, then it == 4
	# since index starts at 0...
	#		reps eq '4'
	#			modCol == 0 then position = A or B
	#			if 1 position = C or D,
	#		reps eq '2h'
	#			modCol == 0 at position A
	#			modCol == 1 position B
	#		reps eq '2v'...this does not matter
	my $modCol = $curCol % $modDivisor;

	#		reps eq '4'
	#			modRow == 0 then position = A or C
	#			if 1 position = B or D,
	#		reps eq '2h'...this does not matter
	#		reps eq '2v'
	#			modRow == 0 at position A
	#			modRow == 1 position B
	my $modRow = $curRow % $modDivisor;

	# $modPosition == the position of 'A'
	# to navigate to position 'A' modPosition = position - modRow - ($modCol*$rows)
	my $modPos = $position - $modRow - ($modCol*$rows);
	my @replicatePositions = ();
	my $excludeCountThresh=17;
	my $timesToRunExclusion=0;
	if($reps eq '4'){
		$timesToRunExclusion=2;
		$excludeCountThresh=2;
		$replicatePosition = $modRow+($modDivisor*$modCol);
		@replicatePositions = ( $modPos, ($modPos+1),($modPos+$rows),($modPos+$rows+1) );
		#if($modRow == 0) { # we are at position (mod col) A (0) or C (1)
		#elsif($modRow == 1){	 # we are at position B (0)  or D (1)
	}
	elsif($reps eq '2h'){
		$excludeCountThresh=1;
		$timesToRunExclusion=1;
		@replicatePositions = ( $position, ($position+$rows) );
		if($modCol){
			@replicatePositions = ( ($position-$rows), $position);
			$replicatePosition=1;
		}
	}
	elsif($reps eq '2v'){
		$excludeCountThresh=1;
		$timesToRunExclusion=1;
		@replicatePositions = ( $position, ($position+1) );
		if($modRow){
			$replicatePosition=1;
			@replicatePositions = ( ($position-1), $position);
		}
	}
	elsif($reps eq '16'){
		$excludeCountThresh=16;
		$timesToRunExclusion=1;
		$replicatePosition = $modRow+($modDivisor*$modCol);
		# if($modRow == 0) { # we are at position (mod col) A (0), E (1), I (2) or M (3)
		# elsif($modRow==1){ # B (0), F (1), J (2), N (3)
		# elsif($modRow==2){ # C, G, K, O
		# elsif($modRow==3){ # D, H, L, P
			my $col1 = $rows; my $col2 = $rows*2; my $col3 = $rows*3;
		  @replicatePositions=(
													$modPos, ($modPos+1), ($modPos+2), ($modPos+3),
													($modPos+$col1), ($modPos+$col1+1), ($modPos+$col1+2), ($modPos+$col1+3),
													($modPos+$col2), ($modPos+$col2+1), ($modPos+$col2+2), ($modPos+$col2+3),
													($modPos+$col3), ($modPos+$col3+1), ($modPos+$col3+2), ($modPos+$col3+3)
												);
	}
	else{	return (0, \@replicatePositions);	}

	# ************************************************************************************************************
	# ********************************** END DETERMINE REPLICATE POSITION ****************************************
	# ************************************************************************************************************

	# if the user has chosen to run replicateExclusion OR
	# if this colony has NOT already been examined THEN
	# compare the current colony's growth to the growth of its fellow replicates to determine if it should be excluded...
	if($runReplicateExclusion){
		&check_positions($replicatePosition,$excluded_colonies_ref, $rows,$position,$dead_size, $data,$reps, \@replicatePositions, $excludeCountThresh, $timesToRunExclusion);
	}
	return ($replicatePosition, \@replicatePositions);
}

sub check_positions{
	my ($replicatePosition, $excluded_colonies_ref, $rows, $position, $dead_size, $data, $reps, $replicatePositions, $excludeCountThresh, $timesToRunExclusion)=@_;

	my $reference_colony=$data->[$position]; # guy we are comparing the others to
	my ($max,$min,$total,$exclude_count,$i)=($reference_colony, $reference_colony,$reference_colony,0,0);
	# iterate over replicates, ignore the index whose value == $replicatePosition
	# meaning that if $replicatePosition == 0, ignore the 1st index, if $replicatePosition == 1, ignore the second index, ect.
	my @dataValues;

	for(my $i=0; $i<@{$replicatePositions}; $i++){
		if($i != $replicatePosition){
			if( $data->[$replicatePositions->[$i]] > $max){$max=$data->[$replicatePositions->[$i]];} # determine maximum size of replicates
			elsif($data->[$replicatePositions->[$i]] < $min){$min=$data->[$replicatePositions->[$i]];} # determine minimum size of replicates
			$total+=$data->[$replicatePositions->[$i]]; # determine total value of replicates
			if(${$excluded_colonies_ref->{$replicatePositions->[$i]}}[0]){$exclude_count++;} # determine number of replicates currently excluded
		}
		push(@dataValues,$data->[$replicatePositions->[$i]]); # capture data values so we can easily calc median later
	}
	if(($max-$min)<$dead_size){	return 1;} # if there is not a lot of variation on colony sizes return...
	my $median = &getArrayMedian(\@dataValues)+0.000000000001;
	for(my $j=0; $j<$timesToRunExclusion; $j++){
		for(my $i=0; $i<@{$replicatePositions}; $i++){
			# ${$excluded_colonies_ref->{$position}}[1] = 1; # mark as being viewed
			$position = $replicatePositions->[$i];
			if(!${$excluded_colonies_ref->{$position}}[0]){
				# if the difference between this colony and the median is not significant (significant being greater then $dead_size) do not exclude it
				# otherwise divided this colony value by the median to calculate the $sub_ratio value
				# if more of this sets replicates are excluded then excludeCountThresh (dependent on # of replicates), exclude this one as well
				if($exclude_count>=$excludeCountThresh){${$excluded_colonies_ref->{$position}}[0]=1;$exclude_count++;}
				elsif((abs($data->[$position]-$median))>$dead_size){
					my $ratio=$data->[$position]/$median;
					# if the $sub_ratio value is <= 1.45 or >= 0.55 return 0.....in other words, if this colony value is not more then 145% of the median or
					# less than 45% do not exclude
					if(!($ratio<=1.45 && $ratio>=0.55)){
						#  exclude...
						${$excluded_colonies_ref->{$position}}[0]=1;
						$exclude_count++;
					}
				}
			}
		}
	}

	return 1;
}

sub send_results{
	use Mail::Mailer;
	my $body = shift;
	my $from_address =shift;
	my $subject =shift;
	my $to_address=shift;
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
	#	print "Success.\n";
	}
}

sub printScripts{
	my($js_files, $css_files)=@_;
	my $html='';
	my $asset_prefix = &static_asset_path();
	foreach(@{$js_files}){$html.= '<script src="'.$asset_prefix->{"javascripts"}.''.$_.'" type="text/javascript"></script>';}
	foreach(@{$css_files}){$html.='<link href="'.$asset_prefix->{"stylesheets"}.''.$_.'.css" media="screen" rel="Stylesheet" type="text/css" />';}
	return $html;
}

sub findPosition{
	# note that the below code is JAVASCRIPT...
	return <<'CODE';
	function findPosition( oElement ) {
	  if( typeof( oElement.offsetParent ) != "undefined" ) {
	    for( var posX = 0, posY = 0; oElement; oElement = oElement.offsetParent ) {
	      posX += oElement.offsetLeft;
	      posY += oElement.offsetTop;
	    }
	    return [ posX, posY ];
	  } else {
	    return [ oElement.x, oElement.y ];
	  }
	}
CODE
}
sub setupReviewLoadingPage{
	my ($query,$cs,$ud,$npr,$tnp,$pd,$o,$pn,$options,$ep)=@_;
	$cs.='px';
	my $pd1=int($pd+0.5);
	my @js =qw(/dr_engine/main.js /jquery.min.js);
	my @css = qw(/public/layout /public/tags /public/bee /dr_engine/plate_layout);
	my $html = '<html><head>'.&printScripts( \@js, \@css);
	print <<"CODE";
		$html
		<script type="text/javascript">
			\$(document).ready(function(){
				parent.document.title="DR Engine - Page $pn";
				setupPage("$ep".split("*-*"));
			});
CODE
	print &findPosition;
	print <<CODE;
	</script>
	</head>
  <body id="screen_mill_dr_engine" style="width:100%;">
CODE
	my $extraStyle = $pd > 99 ? 'allRadius' : 'leftRadius';

	print <<CODE;
	<div id=layout style="margin:0px;display:none;">
	<div style="float:left;">
		<strong class=strongGraph> $npr plates out of $tnp plates analyzed so far &rArr;</strong>
		<div class="graph"><strong class="bar $extraStyle" style="width:$pd%;"><span>$pd1%</span></strong></div>
	</div>
	<div style="float:right;padding:5px;" id="plate_jump">
		<form name="plate_jump" id="plate_jump" method = "post" action="/$RELATIVE_ROOT/cgi-bin/dr_engine/main.cgi" >
			<input type="hidden" id="excludeList2" name="exclusionList" value="">
			<input type="hidden" id="killedPlates2" name="killedPlateList" value="">
			<strong>Currently displaying page # $pn &rArr; Jump to page:  </strong>
			<select name='page_num' id='next_page_num'>$options</select>
			<input type="submit" value="Go!" id='drPlateJumpSubmit' style="display:inline">
		</form>
	</div>
	<br style="clear:both;">
CODE
	return 1;
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

sub validateGoodTextFile{
	my $file = shift;
	if(!$file){return 0;}
	local $/ = \1000; # read first 1000 bytes
	local $_ = <$file>; # read
	if(!$_ || (! -r $file) || (-z $file) || (! -T $file) ){return 0;}
	return 1;
}

sub jsRedirect{
	my ($message, $q) = @_;
	print $q->p("
		<script type='text/javascript'>
			alert('$message');
			if(parent.window){parent.window.location = \"http://$ENV{'HTTP_HOST'}/$RELATIVE_ROOT/login\";}
			else{window.location = \"http://$ENV{'HTTP_HOST'}/$RELATIVE_ROOT/login\";}
		</script>");
	warn "$message";
	exit(0);
}

sub update_done{
	use HTML::Entities;
	use Encode qw(decode_utf8 encode HTMLCREF);
	my ($line, $head, $q, $addendum)=@_;
	$line = encode('ascii', decode_utf8($line), HTMLCREF);
	$addendum = ($addendum && $addendum eq 'one_extra') ? $addendum = 'parent.' : '';
	if(!$q->{'.header_printed'}){	print $q->header();}
	print $q->p("
		<script type='text/javascript'>
			if(typeof ".$addendum."parent.updateFlash == 'function'){
				".$addendum."parent.updateFlash('$line', '$head', 'flashDone');
			}
			else if(typeof ".$addendum."updateFlash == 'function'){".$addendum."updateFlash('$line', '$head', 'flashDone');}
		</script>");
}

sub update_interactive{
	use HTML::Entities;
	use Encode qw(decode_utf8 encode HTMLCREF);
	my ($head, $line, $continueMessage, $continueHead, $updateID, $formName, $q, $addendum)=@_;
	$line = encode('ascii', decode_utf8($line), HTMLCREF);
	$addendum = ($addendum && $addendum eq 'one_extra') ? $addendum = 'parent.' : '';
	if(!$q->{'.header_printed'}){	print $q->header();}
	print $q->p("
		<script type='text/javascript'>
			if(typeof ".$addendum."parent.updateFlash == 'function'){
				".$addendum."parent.updateFlash('$line', '$head', 'flashInteractive');
				".$addendum."parent.updateInteractive(true, true, '$updateID', '$continueMessage','$continueHead', '$formName');
			}
			else if(typeof ".$addendum."updateFlash == 'function'){".$addendum."updateFlash('$line', '$head', 'flashInteractive'); ".$addendum."updateInteractive(true, true);}
		</script>");
}

sub update_message{
	use HTML::Entities;
	use Encode qw(decode_utf8 encode HTMLCREF);
	my ($line, $q, $addendum)=@_;
	$line = encode('ascii', decode_utf8($line), HTMLCREF);
	$addendum = ($addendum && $addendum eq 'one_extra') ? $addendum = 'parent.' : '';
	if(!$q->{'.header_printed'}){	print $q->header();}
	print $q->p("
			<script type='text/javascript'>
				if(typeof ".$addendum."parent.updateFlash == 'function'){
					".$addendum."parent.updateFlash('$line');
				}
				else if(typeof ".$addendum."updateFlash == 'function'){".$addendum."updateFlash('$line');}
			</script>");
}

sub update_error{
	use HTML::Entities;
	use Encode qw(decode_utf8 encode HTMLCREF);
	my ($line, $q, $addendum)=@_;
	$line = encode('ascii', decode_utf8($line), HTMLCREF);
	$addendum = ($addendum && $addendum eq 'one_extra') ? $addendum = 'parent.' : '';
	$line=~ s/'/\\'/g; # escape single quotes
	# because of the dumb way I set up the website I kindof need to SEARCH for the flash body
	$line=~ s/\n|\r//g;
	if(!$q->{'.header_printed'}){	print $q->header();}
	print $q->p("
			<script type='text/javascript'>
				if(typeof ".$addendum."parent.updateFlash == 'function'){
					".$addendum."parent.updateFlash('$line', 'ERROR!', 'flashError');
				}
				else if(typeof ".$addendum."updateFlash == 'function'){".$addendum."updateFlash('$line', 'ERROR!', 'flashError');}
			</script>");
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
			if(-d "$dir/$file"){
				opendir ( DIR, "$dir/$file" ) || die "Error in opening dir $dir/$file\n";
				my $count=0;
				while ( (my $filename = readdir(DIR)) ) {
				  next if $filename =~ /^\.{1,2}$/; # skip . and ..
				  $count++;
				}
				closedir(DIR);
				rmdir("$dir/$file") if($count < 1);
			}
			elsif (-M "$dir/$file" > 30){
				# warn "$dir -- $file";
				# warn -M "$dir/$file";
				# warn -d "$dir/$file";
				if(-d "$dir/$file"){rmdir("$dir/$file");} # rmdir will remove any empty directories
				else{unlink "$dir/$file";}
			}
		}
	}
}

sub directory_setup{
	use File::Find;
	## **************************************************************************
	## **************** SETUP TEMPORARY USER DIRECTORY STRUCTURE ****************
	## **************************************************************************
	my ($v, $q, $comingFrom)=@_; # variables
	if(!defined $comingFrom){$comingFrom='flash';}

	my $td = $v->{'base_upload_dir'};
	my $user = $v->{'user'};
	my $base = $v->{'base_dir'};

	my $ud="$td/$user"; # user specific upload directory
	my $count=0;
	return undef if !&verifyDir($q,$td,$comingFrom);

	# check if directory exists for this user
	if(-d $ud){
		# find out what we can name this new directory (by figure out what is already there, or not there)
		opendir(DIR, $ud);
		my @files = readdir(DIR);
		$count = scalar(@files)-2;
		while(-e "$ud/$count"){	$count++;	}
		if($count>=150){
			if($comingFrom eq 'flash'){&update_error('No more room on Rothstein lab servers to store your data. Please try again in 24 hours.<br/>'.&contact_admin(), $q);}
			warn "directory setup count > 150.";
			return undef;
		}
	}
	# if the user does not currently have a directory, create it
	else{	return undef if !&verifyDir($q,$ud,$comingFrom);}

	# function call to delete old user files
	&finddepth(sub{&bookkeeper($_)}, "$ud");

	# create the temporary directory that will be used for this session
	return undef if !&verifyDir($q,"$ud/$count",$comingFrom,'Problem creating session temp directory.tab: ');
	$ud="$ud/$count";
	# warn "$v->{'base_upload_dir'}/$v->{'user'}/$count";
	$v->{'save_directory'} = "$v->{'base_upload_dir'}/$v->{'user'}/$count";
	$v->{'dirNumber'}=$count;
	if($base eq 'nil'){return $ud;}
	return($ud,$count);
	## **************************************************************************
	## ************* END SETUP TEMPORARY USER DIRECTORY STRUCTURE ***************
	## **************************************************************************
}

sub printColumnHeadings{

	my($p,$query,$c, $plateLabel, $cols, $reps, $plateDisplayIndex)=@_; # query, plate, condition, $plateLabel, cols, holder, variables{'replicates'}
	my $id = "$query,$p,$c";
	my $label = "$plateLabel->{'query'}, $plateLabel->{'plateNum'}";
	if (defined $c && $c ne '-' && $c ne '') {
		$label.=  ", $plateLabel->{'condition'}";
	}
	my $class = 'colSubHead';
	if($cols >24){$class.= ' small';}
	my $html='<div>';

	$html.="\n<table onselectstart='return false;' cellspacing=0 cellpadding=0 id=\"plate$plateDisplayIndex\" class=\"plate\"><thead>";
	$html.="<tr>\n\t<td></td><td></td>\n\t<th colspan=".($cols)." class=plateTitle>";
	$html.="<div class=\"left\" onclick=\"removeAllExclusion(\$('#plate$plateDisplayIndex'));\"><small>(Remove All Exclusion)</small></div>";
	$html.="<div class=\"middle\"><a name=\"$id\">$label</a></div>";
	$html.= '<div class="right" onclick="killPlate($(\'#plate'.$plateDisplayIndex.'\'), \''.$query.'\', false);"><small>(Exclude Entire Plate)</small></div></th></tr>';
	#+++++++++++ Start row to print column number header for replicates that span several columns +++++++++++
	if($reps eq '4' || $reps eq '2h' || $reps eq '16'){
		my $colSpan = ($reps eq '16') ? 4 : 2;
		$html.= "\n<tr>\n\t<td></td><td></td>\n";
		for(my $i=1;$i<=($cols/$colSpan);$i++){
			$html.= "\t<td class=\"colHeader\" onclick=\"excludeColumn(this)\" colspan=\"$colSpan\"> $i </td>\n";
		}
		$html.= "\t<td class=\"blankCellRight\"> &nbsp </td>\n";
		$html.= "\n </tr>\n";
	}
	# +++++++++++++++ END +++++++++++++++++++

	# +++++++++ START literal position column header +++++++++++++
	$html.= "<tr>\n\t<td></td><td></td>\n";
	for(my $i=1;$i<=$cols;$i++){
		$html.= "\t<td class=\"$class\" onclick=\"excludeColumn(this)\"";
		$html.= " \"> $i </td>\n";
	}
	$html.= "\t<td class=\"blankCellRight\"> &nbsp </td>\n";
	$html.= "</tr></thead>\n";
	# +++++++++++++++ END numbered column headings for 2 or 4 replicates ++++++++++++
	return $html;
}

sub getColSize{
	my ($ratio, $cs) = @_;
	my $color_ratio=int((($ratio/$cs)*10)+0.5)*10;
	if($color_ratio > 150){
		if($color_ratio< 200){ $color_ratio=200; }
		elsif( $color_ratio < 300 ){$color_ratio = 1000;}
		else{$color_ratio=2000;}
	}
	if ($ratio<1) {$ratio=1;}
	if ($ratio>$cs){$ratio=$cs;}
	$ratio = int($ratio+0.5); # sizes can only be positive integers
	return ($color_ratio, $ratio);
}

sub printComparisonCartoon{
	my ($data, $variables, $plate, $query, $condition, $normalization_value) = @_;
	if($variables->{'normalization_method'} eq 'nothing'){$normalization_value=&getArrayMedian($data,0);}
	my ($current_col, $current_row)=(0,0); # used to keep track of current column and current row of the plate that we are on
	my ($i, $ratio, $color_ratio, $humanColumn, $html);
	$html = "<div>\n";
	$html.= "<table cellspacing=0 cellpadding=0 >\n";
	my $asset_prefix = &static_asset_path();
	for($i=1;$i<=$variables->{'data_rows'};$i++) {
		$html.= "<tr>\n\t";
		while($current_col < $variables->{'data_cols'}){
			$ratio=($data->[($i-1)+($current_col*$variables->{'data_rows'})] / $normalization_value)*$variables->{'cell_size'};
			($color_ratio, $ratio) = &getColSize($ratio, $variables->{'cell_size'});
			#if ($variables{'density'}==1536){$ratio=$ratio/1.2;}
			$humanColumn=$current_col+1;
			# no on click
			$html.= '<td><img src="'.$asset_prefix->{"images"}.'/colonies/colony_'.$color_ratio.'.png" width="'.$ratio.'" height="'.$ratio.'" /></td>';
			$current_col++;
		}
		# td so that all cells are same height...
		$html.= '<td class="blankCellRight"><img src="'.$asset_prefix->{"images"}.'/colonies/blank.png" width="'.$variables->{"cell_size"}.'" height="'.$variables->{"cell_size"}.'" /></td>';
		$html.= "</tr>\n";
		$current_col=0;
		$current_row++;
	}
	$html.= "<tr>\n\t";
	$html.= "<td colspan=$variables->{'data_cols'} >\n";
	my $plateLabel = $variables->{'originalData'}->{$plate}->{$query}->{$condition};
	if($condition eq '-' || $condition eq ''){$html.= "<center><h3 style=\"padding:0px; margin:0px;\" >$plateLabel->{'query'}, $plate</h3></center></td>\n";}
	else{$html.= "<center><h3 style=\"padding:0px; margin:0px;\" >$plateLabel->{'query'}, $plate, $plateLabel->{'condition'}</h3></center></td>\n";}
	$html.= '</tr><tr>';
	# td so that all cells are same width...
	for($i=1;$i<=$variables->{'data_cols'};$i++){$html.= "<td class=blankCellBottom><img src='$asset_prefix->{'images'}/colonies/blank.png' width='".$variables->{'cell_size'}."' height='1' /></td>\n";}
	$html.= "\t</tr>\n\t</table>\n</div>";
	return $html;
}

sub setupKeyFile{
	use Storable qw(store); # the storable data persistence module
	my($variables, $q)=@_;
	my (%keyinfo,$iloop, %colindex, $head,@headers,$resthead, $KEY, @kdata, $data, $restinfo, %potential_row_values,$num_rows_per_plate);
	my $additionalMsg = '';

	if($variables->{'generateHistogram'}){
		$additionalMsg = '<br/>Processing the key file is necessary when generating a histogram so that blanks and controls can be omitted from consideration.<br/><br/>';
	}
	# if key_choice is custom the file was passed via POST and is accessible through the query parameters
	if($variables->{'key_choice'} eq 'custom'){
		$KEY=$q->param("key_file");
		$variables->{'key_file_name'}='custom';
		if(!$KEY){
			&update_error ('There was an issue processing your key file. If you have your key file open in any other program please close it before attempting to upload it to the <em>DR Engine.</em><br/>'.$additionalMsg.&try_again_or_contact_admin(),$q);
			exit;
			#die "Cannot open custom key file handle.  $!";
		}
	}
	else{
		$variables->{'id_col'}='orf';
		eval{open($KEY, "<$PUBLIC_KEY_DIR/"."$variables->{'key_file_name'}.tab") or die "Cannot open key file: $PUBLIC_KEY_DIR/"."$variables->{'key_file_name'}.tab.  $!";};
		if($@){
			opendir(DIR, "$PUBLIC_KEY_DIR");
			my @files= readdir(DIR);
			close DIR;
			my $file="$PUBLIC_KEY_DIR/"."$variables->{'key_file_name'}.tab";
			@files=grep(/$file/i, @files);
			eval{
				if($files[0]){open($KEY, "<$PUBLIC_KEY_DIR/$files[0]") or die "Cannot open key file: $PUBLIC_KEY_DIR/$files[0].tab.  $!";}
				else{die 'No file grepped out!'}
			};
			if($@){
				&update_error ('There was an issue retrieving your data.<br/>'.$additionalMsg.&try_again_or_contact_admin(),$q);
				exit;
				#die "Cannot open key file: $PUBLIC_KEY_DIR/$variables->{'key_file_name'}.tab.  $!";
			}
		}
	}
	$num_rows_per_plate = $POSSIBLE_DENSITIES{$DENSITY_REPLICATES{"\L$variables->{'key_choice'}"}[0]} /  $NUM_REPLICATES{$DENSITY_REPLICATES{"\L$variables->{'key_choice'}"}[1]};
	if(!&validateGoodTextFile($KEY)){
		&update_error ('Error processing key file.<br/>If you have uploaded your own key file, ensure that it contains the column headings "Plate #", "Row", "Column". This is not case sensitive.<br/>You may also receive this message if your key file is inaccessible. Please make sure that your key file is not open in another application before uploading.<br/>'.$additionalMsg.&try_again_or_contact_admin(),$q);
		exit;
		#die "Cannot open key file: $PUBLIC_KEY_DIR/$variables->{'key_file_name'}.tab.  $!";
	}
	$/ = line_break_check( $KEY );

	# $KEY is now a file handle to the key file that the user selected (if nothing went wrong)
	@potential_row_values{@alphabet}=(0..$#alphabet);
	#--------------------------- START PROCESSING KEY FILE HEADERS --------------------------------
	# the key file should be formated so that the plate column and row columns are last
	# store header information and indices into colindex
	$iloop=0; #used to check if we are in a seemingly infinite loop
	while(!(exists $colindex{'plate #'} && $colindex{'row'} && $colindex{'column'})){
	  $iloop++;
	  if($iloop==1000){
			&update_error('Error processing key file.<br/>If you have uploaded your own key file, ensure that it contains the column headings "plate #", "row", "column".<br/>This is not case sensitive.<br/>'.$additionalMsg.&contact_admin, $q);
			exit;
			#die "Error processing key file...";
		}
		$head = <$KEY>;
		chomp($head) if $head;
		@headers = split /\t/, "\L$head";
		%colindex=();
		@colindex{@headers} = (0..$#headers); # store column header names as the keys of this hash and their index numbers as the values
		$resthead=""; # this string will store the info in the key file that is not associated with the "plate", "row", or "column" columns. This will be use to print out the header of the output files
		foreach $head(@headers){if($head ne "plate #" && $head ne "row" && $head ne "column"){$resthead.="$head\t";}}
	}
	%colindex=();
	# check to make sure that each column label is only defined once in the header
	my @dupColHeads = ();
	for(my $j=0; $j<@headers; $j++){
		if(defined($colindex{$headers[$j]})){	push(@dupColHeads, $headers[$j]);}
		else{	$colindex{$headers[$j]} = $j;	}
	}
	if(scalar(@dupColHeads) > 0){
		&update_error('Your key file file contains duplicate column header(s). Each column header must be unique. Please edit your key data file to fix this problem<br/>Note that the only required column headers are: \'Plate #\', \'Row\' and \'Column\'.<br/><br/>The following column header(s) appear more then once in your file:<br/>'.join(", ",@dupColHeads).'<br/><br/>'.$additionalMsg.&contact_admin(), $q);
		exit;
		#die "duplicate column headers found in ScreenMillStats-All data file.";
	}
	if(! defined $colindex{$variables->{'id_col'}}){
		@headers = (sort keys %colindex);
		$head = join("', '",@headers);
		$head="'$head'";
		&update_error("Unable to locate the ID column inputed ($variables->{'id_col'}) in the key file you selected.<br/>The ID Column is NOT case sensitive but MUST be present in the header line of your key file.<br/>Headers found:<br/>$head<br/>".$additionalMsg.&contact_admin, $q);
		exit;
		#die "Unable to locate the ID column inputed ($variables->{'id_col'}) in the key file selected ($variables->{'key_choice'}).";
	}
	#----------------------- END PROCESSING KEY FILE HEADERS --------------------------------

	# iterate over data in key file, store information in the following data structure:
	# plate number -> row number (letters) -> column number (number) -> all other info
	#     HASH----------->HASH------------------->ARRAY----------------->STRING
	# this structure will make data association easier later on in the program
	# verify that key file matches desity / replicate numbers
	# verify that all row data are leters (e.g 'A, B or C')
	# verify that all colums are positive integers
	# Store plate number and position of all postions labeled as "POSITIVE CONTROL"
	if(! defined $colindex{'gene'}){$colindex{'gene'}=$colindex{$variables->{'id_col'}};} # need this to prevent warnings from popping up if 'gene' heading is missing...
	my (%plate_count, $counter);
	while(<$KEY>){
		chomp;
		@kdata=split /\t/;
		$kdata[$colindex{'plate #'}] = uc($kdata[$colindex{'plate #'}]);
		if(!@kdata || scalar(grep{ /./ } @kdata) <1 ){next;}

		$iloop++;
		# fill in ORF name for gene name if ORF is present and gene name is not. This does nothing if there is no 'gene' header.
		if(defined $kdata[$colindex{$variables->{'id_col'}}] && (! defined $kdata[$colindex{'gene'}] || $kdata[$colindex{'gene'}] eq "")){$kdata[$colindex{'gene'}] = $kdata[$colindex{$variables->{'id_col'}}];}
		$restinfo="";

		# if the current position is a positive control push that position into the appropriate data structure withing the
		# %keyinfo hash. Later, once we know and validate the rows, columns and replicates on a plate we will be able to
		# figure out what data in the log file are positive controls
		if($kdata[$colindex{$variables->{'id_col'}}] && $kdata[$colindex{$variables->{'id_col'}}] =~ /positive\scontrol/i){
			push(@{ $keyinfo{'controlLocations'}->{$kdata[$colindex{'plate #'}]}->{"\U$kdata[$colindex{'row'}]"}},  $kdata[$colindex{'column'}]);
		}

		if(! defined $keyinfo{$kdata[$colindex{'plate #'}]}->{"\U$kdata[$colindex{'row'}]"}){
			$plate_count{$kdata[$colindex{'plate #'}]}->{'rows'}++;
		}
		# do not store info for blank positions...blank positions either have not data or are marked with BLANK
		if((! defined $kdata[$colindex{$variables->{'id_col'}}] && ! defined $kdata[$colindex{'gene'}]) || $kdata[$colindex{$variables->{'id_col'}}]!~/BLANK/ig){
			$counter=0;
			foreach $data(@kdata){
				# print out all info not included in the plate, row, and column headings to $restinfo
				if($counter != $colindex{'plate #'} && $counter != $colindex{'row'} && $counter != $colindex{'column'}){
					$restinfo.="$data\t";
				}
				elsif($data eq $kdata[$colindex{'row'}]){
					if( !defined $potential_row_values{"\U$data"}){
						&update_error("There was an error processing your key file at line number $iloop.<br/>Row values must be valid letters (A-Z, then AA-AZ, then BA-BZ, and so on).<br/>Current value = $data.<br/>".$additionalMsg.&contact_admin(), $q);
						exit;
						#die "error processing key file at line number $iloop. Row value must be a valid letter. Current value = -$data- ".$kdata[$colindex{'column'}];
					}
				}
				elsif($data eq $kdata[$colindex{'column'}]){
					if( $data !~ m/^[1-9][0-9]*/){
						&update_error("There was an error processing your key file at line number $iloop.<br/>Column values must be positive integers greater then 0.<br/>Invalid value found = $data.<br/>".$additionalMsg.&contact_admin(), $q);
						exit;
						#die "error processing key file at line number $iloop. Row value must be a positive integers. Current value = -$data-.";
					}
				}
				$counter++;
			}
			if($keyinfo{$kdata[$colindex{'plate #'}]}->{"\U$kdata[$colindex{'row'}]"}[$kdata[$colindex{'column'}]]){
				&update_error("There was an error processing your key file at line number $iloop.<br/>Plate: $kdata[$colindex{'plate #'}], Row: "."\U$kdata[$colindex{'row'}]".", Column: $kdata[$colindex{'column'}] exist in more then one location.<br/>Please edit your key file appropriately and try again.<br/>".$additionalMsg.&contact_admin(),$q);
				exit;
				#die "error processing key file at line # $iloop.<br/>Plate: $kdata[$colindex{'plate #'}], Row: "."\U$kdata[$colindex{'row'}]".", Column: $kdata[$colindex{'column'}] exist in more then one location";
			}
			else{$keyinfo{$kdata[$colindex{'plate #'}]}->{"\U$kdata[$colindex{'row'}]"}[$kdata[$colindex{'column'}]]=$restinfo;}
		}
		else{$keyinfo{$kdata[$colindex{'plate #'}]}->{"\U$kdata[$colindex{'row'}]"}[$kdata[$colindex{'column'}]]="BLANK";}
		$plate_count{$kdata[$colindex{'plate #'}]}->{'total'}++;
	}

	#warn Dumper(\%keyinfo);
	#exit;
	#my %seen=();
	#my @uniqu = {! $seen{$_}++} (keys %plate_count);
	# check to see if the number of rows for any plate differs from the calculated value $num_rows_per_plate
	# also check to ensure that if we are using designated controls to normalize data that each plate has a control on it
	my $values="";
	my $plates="";
	my ($rows, $cols) = ('n/a','n/a');
	{ # put this in bracket b/c we only want the no warnings to apply for this section
		no warnings 'numeric'; # turn off warnings about numbers (important for sort in next line)
		# sort numeric then by alpha ie 1,2,3,a,b,c
		foreach(sort {$a cmp $b || $a <=> $b } keys %plate_count){
			if ($plate_count{$_}->{'total'} != $num_rows_per_plate){
				$values.= "Plate: $_ - # of data: $plate_count{$_}->{'total'}<br/>";
			}
			elsif($NUM_REPLICATES{$DENSITY_REPLICATES{$variables->{'key_choice'}}[1]} == 2){
				if(defined($POSSIBLE_KEY_ROW_COLS{"$num_rows_per_plate"}->{$variables->{'replicates'}}->{'rows'}) &&
					$POSSIBLE_KEY_ROW_COLS{"$num_rows_per_plate"}->{$variables->{'replicates'}}->{'rows'} != $plate_count{$_}->{'rows'}){
						$values.= "Plate: $_ - # of data: $plate_count{$_}->{'total'} - Rows: $plate_count{$_}->{'rows'}<br/>";
						$rows = $POSSIBLE_KEY_ROW_COLS{"$num_rows_per_plate"}->{$variables->{'replicates'}}->{'rows'};
						$cols = $num_rows_per_plate / $rows;
				}
			}
			elsif(defined($POSSIBLE_KEY_ROW_COLS{"$num_rows_per_plate"}->{'rows'}) &&
				$POSSIBLE_KEY_ROW_COLS{"$num_rows_per_plate"}->{'rows'} != $plate_count{$_}->{'rows'}){
					$values.= "Plate: $_ - # of data: $plate_count{$_}->{'total'} - Rows: $plate_count{$_}->{'rows'}<br/>";
					$rows = $POSSIBLE_KEY_ROW_COLS{"$num_rows_per_plate"}->{'rows'};
					$cols = $num_rows_per_plate / $rows;
			}

			# if we are normalizing to designated controls and no controls were found on the currently plate then throw an error...
			if($variables->{'normalization_method'} eq 'controls' && ! defined $keyinfo{'controlLocations'}->{$_}){	$plates.="$_<br/>";	}
		}
	}
	# if values exist then some plates have different number of rows then other
	if($values){
		my $msg = "There was an error processing your key file. The following plate(s) have a number of rows that differs from the expected number of data ($num_rows_per_plate) based on the density ($POSSIBLE_DENSITIES{$DENSITY_REPLICATES{$variables->{'key_choice'}}[0]}) and number of replicates ($variables->{'replicates'}) you have selected:<br/><br/>Expected number of data ($num_rows_per_plate) = screen density ($POSSIBLE_DENSITIES{$DENSITY_REPLICATES{$variables->{'key_choice'}}[0]}) / number of replicates ($variables->{'replicates'}) <br/><br/>THE DENSITY YOU SELECT MUST BE EQUAL TO THE DENSITY YOU SCREENED IN. THIS IS THE SAME AS THE # OF DATA PER PLATE IN YOUR LOG FILE.<br/>";
		if($rows ne 'n/a'){
			$msg.= "<br/>You may also receive this error if the number of rows and columns in your key file for a given plate do not match the number expected based on the density screened at and the replicate format you have selected. Based on the information you filled in <em>DR Engine</em> expects $rows rows and $cols columns for each plate in your key file.<br/><br/>";
		}
		$msg .= "$values<br/>All plates in your key file must have a row for every position, even if that position is blank.<br/>";
		&update_error($msg.$additionalMsg.&contact_admin(), $q);
		exit;
		#die "error processing key file. All plates in your key file must have a row for every position. $values.";
	}
	# if $plates exists and we are in designated controls normalization mode, throw and error
	if($plates && $variables->{'normalization_method'} eq 'controls'){
		&update_error("There was an error processing your key file. <em>DR Engine</em> could not find designated controls on the following plates:<br/>$plates<br/><br/>Note that you may specify control locations by placing the phrase <em>Positive Control</em> in the ID column of the rows that contain control data.<br/>".$additionalMsg.&contact_admin(), $q);
		exit;
		#die "error processing key file. Could not find designated controls in every plates. $plates.";
	}
	# validate all plates to ensure that the proper amount of data exists
	# Store key data structure to disk...these files will not be accessed again until the review process is completed and the output files are generated.
	eval {store(\%keyinfo, "$variables->{'key_dir'}/$variables->{'key_file_name'}.dat")};
	if($@){ &update_error('There was an error processing your key file.<br/>'.$additionalMsg.&contact_admin(), $q); die 'Serious error from Storable, storing %keyinfo: '.$@;}
	eval {store(\$resthead, "$variables->{'key_dir'}/$variables->{'key_file_name'}"."-head.dat")};
	if($@){ &update_error('There was an error processing your key file.<br/>'.$additionalMsg.&contact_admin(), $q); die 'Serious error from Storable, storing $resthead: '.$@;}
	return(\%keyinfo, \$resthead);
}

sub processLogFile{
	$|=1;
	use Statistics::Descriptive;
	# control locations is only defined if the normalization method chosen was "Designated Controls"
	my ($q, $mode, $variables, $controlLocations) = @_;
	my $alive_threshold=0.35;
	my $absolute_dead_cutoff=0; # this being set at 0 makes some of the checks below redundent ...EVERY value should be >=0
	my ($line_counter, $LOG, $head, $info, @info, %queries, $colony, %normalization_values, $control, $count, $plateDataCounter, $upload_dir, $foundControl,
			$perceived_density, %plate, @files, $files, $file,@data,%plate_circ,$circ_flag,$considered_growing, @sorted, $midPoint, $sortQuery);
	if($mode eq 'review' || ($mode eq 'ic' && $variables->{'processing_choice'} eq 'log_file')){
		# iterate over log file, prepend ALL control plate query names with 0000_ tag so that when sorted, they will be first (for display)
		$line_counter=1;
		$perceived_density=0;
		$foundControl = 0; # keeps track if we have found the control (comparer) in the log file or not
		$LOG=$q->param("logFile");
		if(!$LOG){
			&update_error("You forgot to upload a log file!", $q);
			exit;
			#die "No log file uploaded.";
		}
		if(!&validateGoodTextFile($LOG)){
			update_error('Your log file did not upload properly or it does not contain any data (i.e. blank file). If you have it open in another application, please close it and try again<br/>'.&contact_admin(), $q);
			exit;
			#die "data file is not formatted properly.";
		}
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
			&update_error("There seems to be an issue with you log file at line: $line_counter ($head).<br/><br/>This program will not except data containing the following characters:<br/><center>\"!, @, #, \$, %, or /\"</center><br/>In addition, it cannot contain more then 1 period.<br/><br/>".&contact_admin(), $q);
			exit;
		}
		@info=(split /,/,$info); # split file name based on commas --> index 0 should be the query, 1 = plate#, 2 = condition (if present)
		if(@info<2 || @info>3){
			&update_error("There seems to be an issue with you log file at line: $line_counter ($head).<br/>Queries, plates numbers and conditions must be separated by commas and cannot contain commas themselves. For example, 'query,plate1,condition1' is a valid plate identifier. 'qu,ery,plate1,condition1' is not.<br/>".&contact_admin(), $q);
			exit;
			#die "issue with you log file at line: $line_counter ($head). program will only except file names with exactly 2 commas";
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
		my $den;
		# for dr engine
		if(defined $variables->{'key_choice'}){$den = $POSSIBLE_DENSITIES{$DENSITY_REPLICATES{$variables->{'key_choice'}}[0]};}
		# for sv engine
		else{$den = $variables->{'rows'} * $variables->{'cols'} * $NUM_REPLICATES{$variables->{'replicates'}};}
		$plateDataCounter=0;
		my $number_of_lines = $.;
		while(<$LOG>){
			chomp;
			$line_counter++;
			if($_ =~ /,/){ #new filename encountered
				# if no data found...
				if($plateDataCounter == 0){
					my $plateLabel = $variables->{'originalData'}->{$info[1]}->{$info[0]}->{$info[2]};
					&update_error("Your data pertaining to $plateLabel->{'plateNum'}, $plateLabel->{'query'}, $plateLabel->{'condition'} contains $plateDataCounter data. You should have 96, 384 or 1530 data per plate, separated by carriage returns in your log file.<br/>".&contact_admin(), $q);
					exit;
					#die "Zero data error --> data pertaining to $info[1], $info[0], $info[2] contains $plateDataCounter.\n $!";
				}
				# based on above calculations, calculate the normalization values for current plate
				if($variables->{'normalization_method'} eq 'mean'){
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
				}
				elsif($variables->{'normalization_method'} eq 'median'){
					$normalization_values{$info[1]}->{$info[0]}->{$info[2]} =  ($variables->{'ignoreZeros'}) ? &getNonZeroArrayMedian($plate{$info[1]}->{$sortQuery}->{$info[2]}->[0]) : &getArrayMedian($plate{$info[1]}->{$sortQuery}->{$info[2]}->[0]);
				}
				# if normalization method is 'controls' need to do this step to properly correct for the corn row effect. Any normalization values calculated for
				# plates will be over-written in the function calculateNormalizeToControlValues
				elsif($variables->{'normalization_method'} eq 'krogan' || $variables->{'normalization_method'} eq 'controls'){	$normalization_values{$info[1]}->{$info[0]}->{$info[2]} = $stat->trimmed_mean(0.4);	}
				elsif($variables->{'normalization_method'} eq 'nothing'){$normalization_values{$info[1]}->{$info[0]}->{$info[2]}=1;} # else do not normalize
				else{$normalization_values{$info[1]}->{$info[0]}->{$info[2]}=1;}
				# ensure that the value is NOT 0
				if(defined $normalization_values{$info[1]}->{$info[0]}->{$info[2]}){
					$normalization_values{$info[1]}->{$info[0]}->{$info[2]}= 1 if (! defined $normalization_values{$info[1]}->{$info[0]}->{$info[2]} || $normalization_values{$info[1]}->{$info[0]}->{$info[2]} <= 0);
				}
				else{$normalization_values{$info[1]}->{$info[0]}->{$info[2]}= 1; }

				if($perceived_density==0){$perceived_density=$plateDataCounter;}
				elsif($perceived_density != $plateDataCounter){
					my $plateLabel = $variables->{'originalData'}->{$info[1]}->{$info[0]}->{$info[2]};
					&update_error("Your data pertaining to $plateLabel->{'plateNum'}, $plateLabel->{'query'}, $plateLabel->{'condition'} contains $plateDataCounter data, but the density that this screen seemed to be performed at is $perceived_density.<br/>Please close this window, fix your log file and re-upload it.  Thank you.<br/>".&contact_admin(), $q);
					exit;
					#die "data pertaining to $info[1],$info[0],$info[2] contains $plateDataCounter data,
					#		but density screen seemed to be performed at is $perceived_density.\n $!";
				}

				# correct for corn field effect, do this after checking to make sure that density is correct
				#&normalizeOuterRowGrowth($plate{$info[1]}->{$sortQuery}->{$info[2]}->[0], $POSSIBLE_KEY_ROW_COLS{$den}, $normalization_values{$info[1]}->{$info[0]}->{$info[2]});

				$plateDataCounter=0;
				$_=~ tr/"|\t//d;        #remove any quotes or tabs in the string
				@info = split/\./, $_;
				if($info[$#info] =~ /^(tif|tiff|jpg|jpeg|gif|png|psd|bmp|fits|pgm|ppm|pbm|dic|dcm|dicom|pict|pic|pct|tga|ico|xbm|lsm|img|liff)/i){
					pop(@info);
				}
				$info = join(".",@info);
				unless($info=~/[^\w\.\!\@\#\$\%\^\\\/]/){
					&update_error("There seems to be an issue with you log file at line: $line_counter ($head).<br/>This program will not except data containing the following characters:<br/><br/><center>!, @, #, \$, %, \\, or /</center><br/><br/>In addition, file names present in log file cannot contain more then 1 period.<br/>".&contact_admin(), $q);
					exit;
					#die "issue with you log file at line: $line_counter ($head). Illegal characters.";
				}
				@info=split(/,/, $info);  # split by commas

				if(@info<2 || @info>3){
					&update_error("There seems to be an issue with you log file at line: $line_counter ($_).<br/>This program will only except file names with exactly 2 commas.<br/>".&contact_admin(), $q);
					exit;
					#die "issue with you log file at line: $line_counter ($_).";
				}
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
						&update_error("There seems to be an issue with you log file at line #$line_counter (plate = $head, data = '$dataError').<br/>Note that values must be positive numbers. If this is at the end of your log file the issue may be that you have extra blank lines.<br/>This program will only except positive numbers as data input.<br/>".&contact_admin(), $q);
						exit(0);
					}
					#die "issue with you log file at line #$line_counter (plate = $head) data = $_";
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
			&update_error("Your data pertaining to $plateLabel->{'plateNum'}, $plateLabel->{'query'}, $plateLabel->{'condition'} contains $plateDataCounter data. You should have 96, 384 or 1536 data per plate, separated by carriage returns in your log file.<br/>".&contact_admin(), $q);
			exit;
			#die "Zero data error --> data pertaining to $info[1], $info[0], $info[2] contains $plateDataCounter.\n $!";
		}
		if($variables->{'normalization_method'} eq 'mean'){
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
		}
		elsif($variables->{'normalization_method'} eq 'median'){
			$normalization_values{$info[1]}->{$info[0]}->{$info[2]} =  ($variables->{'ignoreZeros'}) ? &getNonZeroArrayMedian($plate{$info[1]}->{$sortQuery}->{$info[2]}->[0]) : &getArrayMedian($plate{$info[1]}->{$sortQuery}->{$info[2]}->[0]);
		}

		# if normalization method is 'controls' need to do this step to properly correct for the corn row effect. Any normalization values calculated for
		# plates will be over-written in the function calculateNormalizeToControlValues
		elsif($variables->{'normalization_method'} eq 'krogan' || $variables->{'normalization_method'} eq 'controls'){	$normalization_values{$info[1]}->{$info[0]}->{$info[2]} = $stat->trimmed_mean(0.4);	}

		# ensure that the value is NOT 0
		if(defined $normalization_values{$info[1]}->{$info[0]}->{$info[2]}){
			$normalization_values{$info[1]}->{$info[0]}->{$info[2]}= 1 if (! defined $normalization_values{$info[1]}->{$info[0]}->{$info[2]} || $normalization_values{$info[1]}->{$info[0]}->{$info[2]} <= 0);
		}
		else{$normalization_values{$info[1]}->{$info[0]}->{$info[2]}= 1;}
		# END FINAL PLATE CALCULATIONS (same as above)\

		# correct for corn field effect
		#&normalizeOuterRowGrowth($plate{$info[1]}->{$sortQuery}->{$info[2]}->[0], $POSSIBLE_KEY_ROW_COLS{$den}, $normalization_values{$info[1]}->{$info[0]}->{$info[2]});

		if($circ_flag){$variables->{'circ_included'}=1;} # set flag to indicate if circularity measurements are included
		# set the density
		if($perceived_density==0){$variables->{'density'}=$plateDataCounter;}
		else{$variables->{'density'}=$perceived_density;}
		close $LOG;
	}
	elsif($mode eq 'ic' && $variables->{'processing_choice'} eq 'pictures'){
		eval{opendir(TEMP_DIR, $variables->{'picture_dir'}) || die "Could not open picture directory: $!";};
		if($@){&update_error ('There was an issue retrieving your images.  '.&try_again_or_contact_admin(),$q); die "could not open picture directory.: $@";}
		@files=grep(!/^\.\.?}$/, readdir TEMP_DIR); # exclude files starting with . and ..
		foreach $file(@files){
			my $full_path= $$variables->{'picture_dir_html'}."/".$file;
			my $file=(split/\./, $file)[0];   #remove file extension
			if($file ne ""){
				@info=split /,/,"\L$file";	# split by commas
				$info[1]="\U$info[1]"; # uppercase everything
				$info[0]=ucfirst($info[0]); # uppercase first letter
				$info[2]=ucfirst($info[2]); # uppercase first letter
				$sortQuery=$info[0];
				if($info[0] eq $variables->{'control'}){$sortQuery="0000_$sortQuery"; $foundControl=1;}
				${$plate{$info[1]}->{$sortQuery}->{$info[2]}->[0]} = $full_path; # store file name associated with plate/query/condition combo
				$queries{$sortQuery}->{$info[2]}='1'; # store query names in hash...makes sorting easy
			}
		}
	}
	else{&update_error ('There was an error processing your log file (undefined mode).  '.&try_again_or_contact_admin(),$q); die "Error processing log file (undefined mode).";}
	&update_message('Verifying Comparer Data', $q);
	$variables->{'control'}="0000_$variables->{'control'}";
	# store queries in array, check to see if the control query entered by the user
	# matches the name of one of the queries processed in the log file(s)
	# only need this check during the initial processing
	my @queries=sort {lc $a cmp lc $b} keys %queries; # case insensitive sort!
	if(!$foundControl){
		$variables->{'control'}=~ s/0000_//; # strip out leading '0000_'
		my $em.='<b><div class="side_margin">The comparer query you entered ('.$variables->{'originalData'}->{'control'}.') is not present in the log file (case-insensitive). Please change your comparer query to something that is present in your log file. The queries present in the log file are:</div>';
		$em.='<ol>';
		my $last="";
		my $starting=0;
		foreach(@queries){
			$_=~ s/^0000_//;
			if("\L$_" eq "\L$last"){	$em.=", $_";	}
			else{
				if($starting){	$em.="</li>";		}
				$em.= "<li>$_";
				$starting=1;
			}
			$last=$_;
		}
		$em.= "</li></ol><div class='clear block side_margin no_decorators top_padding10'>If you are sure that the comparer you entered is contained within your log file OR if no queries are listed as being present in the log file other problems may exist, including:<ul class='no_margin no_decorators i_side_margin'><li class='normal_list no_decorators y_padding10'>The file permissions on your log file may be to restrictive (may be problematic if file is stored on a server).</li><li class='normal_list y_padding10 no_decorators'>Your log file may just be empty.</li></ul></div><br/><center class='clear'>Please close this dialog and try again.</center><br/>";
		&update_error($em, $q);
		exit;
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
						&update_error("There is no matching comparer plate for $info (comparer = $o_control).<br/>Either add the corresponding comparer data from your log file or delete the data for $info from your log file.<br/>".&contact_admin(), $q);
						exit;
					}
				}
			}
		}
		if($expQueryCount < 1){
			&update_error("There are no experimental plates present in your log file (i.e. only comparer data is present). Comparer = $o_control).<br/><br/>Please add experimental data to your log file and try again.<br/><br/>".&contact_admin(), $q);
			exit;
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
			&update_error("Impossible density calculated from log file, or key file density does not match log file density.<br/>Density calculated = $variables->{'density'}.<br/>Key file = $variables->{'key_choice'} (density = $DENSITY_REPLICATES{$variables->{'key_choice'}}[0]).<br/><br/>Note that the only densities currently supported are 96, 384 and 1536.<br/>".&contact_admin(), $q);
			exit;
			#die "Impossible density calculated or key file does not match density. Density entered = $variables->{'density'}.  Key file = $variables->{'key_choice'}\n";
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
			&update_error("Invalid density calculated.<br/>Density calculated = $variables->{'density'}.<br/>".&contact_admin(), $q);
			exit;
			#die "Invalid density: $variables->{'density'}.  $!\n";
		}
	}

	# if the "Designated controls" method was chosen to normalize data to, do that now...
	if($variables->{'normalization_method'} eq 'controls'){
		&calculateNormalizeToControlValues($q, $variables,$controlLocations, \%normalization_values, \%plate);
	}

	# store the data structures we just created in Storable file for quick / easy retrieval later
	eval {store(\%plate, "$variables->{'save_directory'}/plate_data.dat")};
	if($@){&update_error ('There was an issue with your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable storing \%plate: $@";}
	eval {store(\%normalization_values, "$variables->{'save_directory'}/normalization_values.dat")};
	if($@){&update_error ('There was an issue with your data.  '.&try_again_or_contact_admin(),$q); die 'Serious error from Storable storing %normalization_values: $@';}
	eval {store(\%queries, "$variables->{'save_directory'}/queries.dat")};
	if($@){&update_error ('There was an issue with your data.  '.&try_again_or_contact_admin(),$q); die 'Serious error from Storable storing %queries: $@';}
	eval {store(\%{$variables}, "$variables->{'save_directory'}/variables.dat")};
	if($@){&update_error ('There was an issue with your data.  '.&try_again_or_contact_admin(),$q); die 'Serious error from Storable storing %variables: $@';}
	if($mode eq 'review'){
		&update_message('Everything looks good.  Redirecting to data review.' , $q); return (\%plate, \%queries);
	}
	#  else this is sv engine
	&update_message('Everything looks good.', $q);
	return(\%plate, \%normalization_values);
}

sub calculateNormalizeToControlValues{
	my ($q, $variables, $controlLocations, $normalization_values, $plateData) = @_;

	&update_message('Processing normalization data...', $q);
	if(! defined $controlLocations || $controlLocations eq ''){
		&update_error("Error calculating normalization values<br/><br/>Please make sure that you have specified positive control locations for all plates in your key file AND that the median of the corresponding values in your log file is > 0.<br/><br/>".&contact_admin(), $q);
		exit;
		#die "Error calculating normalization value for all plates.\n";
	}
	my %tempNormValues;
	my $col1 = $variables->{'rows'}; my $col2 = $variables->{'rows'}*2; my $col3 = $variables->{'rows'}*3;
	# array index 0 - 3 = 4 replicates, 0-1 = 2v, 0 and 2 = 2h, 0-15 = 16 replicates
  my @replicatePositions=(
													0, 1, $col1, $col1+1, 2, 3, $col1+2, $col1+3,
													$col2, $col2+1, $col2+2, $col2+3, $col3, $col3+1, $col3+2, $col3+3
													);

	my ($rowAdjust, $colAdjust) = (1,1);

	if($variables->{'replicates'} eq '4'){
		@replicatePositions = splice(@replicatePositions, 0, 4);
		$rowAdjust=2; $colAdjust=2;
	}
	elsif($variables->{'replicates'} eq '2v'){
		@replicatePositions = splice(@replicatePositions, 0, 1);
		$rowAdjust=2;
	}
	elsif($variables->{'replicates'} eq '2h'){
		@replicatePositions = ($replicatePositions[0], $replicatePositions[2]);
		$colAdjust=2;
	}
	elsif($variables->{'replicates'} eq '16'){
		@replicatePositions = splice(@replicatePositions, 0, 16);
		$rowAdjust=4; $colAdjust=4;
	}

	# iterate over control location data and pull out the relevent values from the log file data
	foreach my $plate(keys %{$controlLocations}){
		foreach my $row(keys %{$controlLocations->{$plate}}){
			foreach my $col(@{$controlLocations->{$plate}->{$row}}){
				# translate row letter into is corresponding number...(e.g., A=0, B=1, C=2...)
				my $rowVal = &indexArray($row, @alphabet);
				# substract 1 from col value, this will make is so that col values start at 0 instead of 1
				my $modCol = $col-1;
				# translate the position in the key file to the corresponding position in the raw data (data in log file)
				my $translatedPosition = ($rowAdjust*$rowVal) + ($colAdjust*$modCol*$variables->{'rows'});
				# iterate over queries and conditions to pull all values out
				foreach my $query(keys %{ $plateData->{$plate} }){
					foreach my $condition(keys %{ $plateData->{$plate}->{$query} }){
						foreach my $rep(@replicatePositions){
						#	warn "$rep, $translatedPosition, $rowVal, $modCol";
							push(@{$tempNormValues{$plate}->{$query}->{$condition}}, $plateData->{$plate}->{$query}->{$condition}->[0][($rep+$translatedPosition)]);
						}
					}
				}
			}
		}
	}
	# iterate over $tempNormValues and calculate median for each, the median of these values defines the normalization value for a given plate
	foreach my $plate(keys %tempNormValues){
		foreach my $query(keys %{ $tempNormValues{$plate} }){
			my $modQ = $query; $modQ=~ s/0000_//;
			foreach my $condition(keys %{ $tempNormValues{$plate}->{$query} }){
				$normalization_values->{$plate}->{$modQ}->{$condition} = &getNonZeroArrayMedian($tempNormValues{$plate}->{$query}->{$condition});
			}
		}
	}
	# perform a quick check to ensure that there is a valid normalization value for each plate currently "valid" means that it exists and is greater then 0
	foreach my $plate(keys %{$plateData}){
		foreach my $query(keys %{ $plateData->{$plate} }){
			foreach my $condition(keys %{ $plateData->{$plate}->{$query} }){
				my $modQ = $query; $modQ=~ s/0000_//;
				if(! defined $normalization_values->{$plate}->{$modQ}->{$condition}){
					my $c = (defined $condition && $condition ne '') ? $condition : '-';
					&update_error("Error calculating normalization value for:<br/>Query: $modQ <br/>Plate: $plate <br/>Condition: $c<br/><br/>Please make sure that you have specified positive control locations for this plate in your key file AND that the median of the corresponding values in your log file is > 0.<br/><br/>".&contact_admin(), $q);
					exit;
					#die "Error calculating normalization value for: Query: $modQ, Plate: $plate, Condition: $c\n";
				}
			}
		}
	}
}

sub calcCollapsedRowsAndCols{
	my($q, $variables) = @_;
	# figure out "collapsed" number of rows and columns. This is equivilent to dividing the plate density
	# by the number of replicates and then figuring out how many rows and columns are in this "collapsed" density
	$variables->{'collapsedDensity'} = $variables->{'density'} / $NUM_REPLICATES{$variables->{'replicates'}};
	# 1536 with 16 replicates or 384 with 4 replicates or 96 with 1 replicate
	if($variables->{'collapsedDensity'} == 96 ){
		$variables->{'collapsedRows'} = 8;
		$variables->{'collapsedCols'} = 12;
	}
	# 1536 with 4 replicates or 384 with 1
	elsif($variables->{'collapsedDensity'} == 384 ){
		$variables->{'collapsedRows'} = 16;
		$variables->{'collapsedCols'} = 24;
	}
	# 1536 with 1 replicate
	elsif($variables->{'collapsedDensity'} == 1536 ){
		$variables->{'collapsedRows'} = 32;
		$variables->{'collapsedCols'}= 48;
	}
	# 2304 with 1 replicate
	elsif($variables->{'collapsedDensity'} == 2304 ){
		$variables->{'collapsedRows'} = 48;
		$variables->{'collapsedCols'}= 48;
	}
	# 2304 with 4 replicate
	elsif($variables->{'collapsedDensity'} == 576 ){
		$variables->{'collapsedRows'} = 24;
		$variables->{'collapsedCols'}= 24;
	}
	# 2304 with 16 replicate
	elsif($variables->{'collapsedDensity'} == 144 ){
		$variables->{'collapsedRows'} = 12;
		$variables->{'collapsedCols'}= 12;
	}
	# 96 with 16 replicates
	elsif($variables->{'collapsedDensity'} == 16 ){
		$variables->{'collapsedRows'} = 8;
		$variables->{'collapsedCols'}=12;
	}
	# 384 w/ 16 replicates or 96 with 4
	elsif($variables->{'collapsedDensity'} == 24 ){
		$variables->{'collapsedRows'} = 8;
		$variables->{'collapsedCols'}*=12;
	}
	# dealing with situations that could only exist if we have 2h or 2v replicates
	else{
		my $rowMod=1;
		my $colMod=1;
		if($variables->{'replicates'} eq '2v'){	$rowMod=0.5;}
		elsif($variables->{'replicates'} eq '2h'){$colMod=0.5;}
		else{	# error
			&update_error ('There was an issue with your data.  '.&try_again_or_contact_admin(),$q); die "Error calculating collapsed density (d = $variables->{'collapsedDensity'}, reps = $variables->{'replicates'})";
		}
		# 96 with 2h or 2v replicates
		if($variables->{'collapsedDensity'} == 48 ){
			$variables->{'collapsedRows'} = 8*$rowMod;
			$variables->{'collapsedCols'}=12*$colMod;
		}
		# 384 with 2v or 2h replicates
		elsif($variables->{'collapsedDensity'} == 192 ){
			$variables->{'collapsedRows'} = 16*$rowMod;
			$variables->{'collapsedCols'} = 24*$colMod;
		}
		# 1536 with 2v or 2h replicates
		elsif($variables->{'collapsedDensity'} == 768 ){
			$variables->{'collapsedRows'} = 32*$rowMod;
			$variables->{'collapsedCols'} = 48*$colMod;
		}
		else{ # error
			&update_error ('There was an issue with your data.  '.&try_again_or_contact_admin(),$q); die "Error calculating collapsed density (d = $variables->{'collapsedDensity'}, reps = $variables->{'replicates'})";
		}
	}
}

sub processOutAllFile{
	use Storable qw(store); # the storable data persistence module
	my($q, $variables)=@_;
	my($DATA,$iloop,%colindex, %all_data, %data, $pvalFlag, @headers);
	# open file for ScreenMillStats-all.txt file analysis, process it, this is done regardless of how plate images are displayed (cartoon or real)
	$DATA=$q->param("out_all");
	if(! defined $DATA || ! -s $DATA){
		update_error('Your ScreenMillStats-All data file did not upload properly. If you have it open in another application, please close it and try again<br/>'.&contact_admin(), $q);
		exit;
		#die "data file is not formatted properly.";
	}
	# determine MIME content type --> will be needed for excel stuff...
	#my $contenttype = $q->uploadInfo($DATA)->{'Content-Type'};
	$/ = line_break_check( $DATA ); # adjust line break character if necessary
	# get rid of header
	$iloop=0; #used to check if we are in a seemingly infinite loop
	while(!
		(defined $colindex{'plate #'} && defined $colindex{'row'} && defined $colindex{'column'} && defined $colindex{'id column'} &&
		defined $colindex{'condition'} && defined $colindex{'query'}  )){
    $iloop++;
    if($iloop==100){
			update_error('Your data file is not formatted properly.<br/>Make sure that it contains a header with the words "Plate #", "Query", "Condition", "Row", "Column" and "ID Column" over the appropriate columns.<br/>This is not case sensitive.<br/><br/>You may also receive this message if you are attempting to upload this file while it is open in another program'.&contact_admin(), $q);
			exit;
			#die "data file is not formatted properly.";
		}
		chomp (my $head = <$DATA>);
		@headers = split /\t/, "\L$head"; # want it to be case insensitive
		if($pvalFlag){ # using this method we WILL store a little bit of unrelated data, but whatever
			if($headers[0] && defined $headers[1] && defined $headers[2]){
				$variables->{'pthresh'}->{$headers[0]}->{$headers[1]}=$headers[2];
			}
		}
		elsif($headers[1] && $headers[1]=~/p-value/gi){$pvalFlag=1;} # found heading for p-value, everything row below this, but above the header should contain pvalue threshold info
		if($headers[0]){
			$headers[0] =~ /^.*:\s*(.*)$/i; # get data after ':', store in $data
			my $data = $1;
			$data=~s/\s+//ig if ($data); # strip out spaces
			if($headers[0]=~/normalized/gi){
				if($data eq 'mean' || $data eq 'median' || $data eq 'nothing' || $data eq 'controls' || $data eq 'krogan'){
					$variables->{'normalization_method'}=$data;
				}
				# default to median
				else{$variables->{'normalization_method'}='median';}
			}
			elsif($headers[0]=~/Yellow Highlight/gi){
				if($data =~ /%$/){chop($data); $data=$data/100;}
				if($data > 0 && $data < 1 ){
					$variables->{'death_threshold_cutoff'}=$data;
				}
				# default to 25%
				else{$variables->{'death_threshold_cutoff'}=0.25;}
			}
			elsif($headers[0]=~/Ignore Zero/gi){
				# should zero values be ignored???
				$variables->{'ignoreZeros'} = ((&is_numeric($data) && $data == 0) || $data =~ /no/i || $data =~ /false/i || $data eq '0') ? 0 : 1;
			}
			elsif($headers[0]=~/Replicates/gi){				$variables->{'replicates'} = $data;			}
			elsif($headers[0]=~/Statistical Method/gi){				$variables->{'statsMethod'} = $data;		}
		}
		# commented out below line, if analyzing old data will re-calculate pthresh on a query-condition basis
		# elsif($headers[0] && $headers[0]=~/p-value cut-off for significance:/){$variables->{'pthresh'}=$headers[1];}
		%colindex=();
		@colindex{@headers} = (0..$#headers);
		# check to make sure that each column label is only defined once in the header
		if(defined $colindex{'plate #'} && defined $colindex{'row'} && defined $colindex{'column'} && defined $colindex{'condition'} && defined $colindex{'query'} && !defined $colindex{'id column'} ){
			$colindex{'id column'} = $variables->{'ignoreID'};
			if(!defined $colindex{'id column'}){
				if($variables->{'normalization_method'} && $variables->{'normalization_method'} eq 'controls'){
					&update_error('Could not find an ID column present in the ScreenMillStats-All data file.<br/>This file indicates that you would like to normalize your data to designated controls (labeled "positive controls" in ScreenMillStats-All data file).<br/>If you would like to normalize you data to designated controls you MUST include a column labeled "ID Column" in this file along with the phrase "Positive Controls" in ID column of the rows that contain control data.</br> If you do not want to normalize your data to designated controls please change the normalization mode designated in your the ScreenMillStats-All data file to another supported normalization method (e.g, median or nothing).<br/>'.&contact_admin(), $q);
					exit;
					#die "data file is not formatted properly.";
				}
				# if the only thing that is not defined is the id column perhaps that is ok....ask user
				&update_interactive('Note!', 'Could not find an ID column present in the ScreenMillStats-All Data File.<br/>If you processed your data without a key file it is normal to not have and ID column, please click "Continue".<br/>Press "Continue" to process without an ID Column or "Cancel" to exit. ', ' ', 'Processing ScreenMillStats-all data file...', 'ignoreID', 'svEngineSetup', $q);
				exit;
				#die "no id column found";
			}
		}
	}
	%colindex=();
	# check to make sure that each column label is only defined once in the header
	my @dupColHeads = ();
	for(my $j=0; $j<@headers; $j++){
		if(defined($colindex{$headers[$j]})){	push(@dupColHeads, $headers[$j]);}
		else{	$colindex{$headers[$j]} = $j; push(@{$all_data{"header"}}, $headers[$j]);}
	}
	if(scalar(@dupColHeads) > 0){
		&update_error('Your ScreenMillStats-All data file contains duplicate column header(s). Each column header must be unique. Please edit your ScreenMillStats-All data file to fix this problem<br/>Note that the only required column headers are: \'Plate #\', \'Row\', \'Column\', \'ID Column\', \'Condition\' and \'Query\'.<br/><br/>The following column header(s) appear more then once in your file:<br/>'.join(", ",@dupColHeads).'<br/><br/>'.&contact_admin(), $q);
		exit;
		#die "duplicate column headers found in ScreenMillStats-All data file.";
	}
	# if $variables->{'normalization_method'} is not defined set it to be median
	$variables->{'normalization_method'}='median' if ! defined $variables->{'normalization_method'};
	if(! defined $variables->{'death_threshold_cutoff'}){$variables->{'death_threshold_cutoff'} = 0.25;}
	$variables->{'death_threshold_cutoff'} = ($variables->{'death_threshold_cutoff'} == 0 || $variables->{'normalization_method'} eq 'nothing') ? 0 : $variables->{'death_threshold_cutoff'};

	if(! defined $variables->{'statsMethod'}){
		update_error('Could not find the method you defined in your ScreenMillStats-all.txt for data analysis.</br>Please see the sample ScreenMillStats-all.txt on this web page for instructions on how to define the statistical method used in your analysis.<br/>'.&contact_admin(), $q);
		exit;
	}

	# setup missing data message, only display it if data is indeed missing
	my $missingData='Could not find the following column(s) in your ScreenMillStats-all.txt file.<br/>These columns are not required (and may not even be applicable to your data), but if you would like to include these in SV Engine click "Cancel", modify your ScreenMillStats-all.txt and re-upload it. Otherwise click "Continue".<br/><ul>';

	# check if the calculated log ratio column was found
	my $calcLogRatioCol;
	if(defined $colindex{'log growth ratio'}){$calcLogRatioCol = $colindex{'log growth ratio'};}
	elsif(defined $colindex{'calculated log ratio (comparer::exp)'}){$calcLogRatioCol = $colindex{'calculated log ratio (comparer::exp)'};}
	elsif(defined $colindex{'ratio'}){$calcLogRatioCol = $colindex{'ratio'};}

	if(!defined $calcLogRatioCol){
		$calcLogRatioCol = -1;
		$missingData.='<li>Log Growth Ratio</li>';
	}
	else{$variables->{'statCols'}->{'calcLogRatio'}=1;}

	# check if the growth ratio column was found
	my $normGrowthRatioCol = -2;
	if(defined $colindex{'growth ratio (comparer / exp)'}){$normGrowthRatioCol = $colindex{'growth ratio (comparer / exp)'};}
	elsif(defined $colindex{'ratio'}){$normGrowthRatioCol = $colindex{'ratio'};}
	if($normGrowthRatioCol < 0 && $normGrowthRatioCol != $calcLogRatioCol ){$missingData.='<li>Growth Ratio (Comparer / Exp)</li>';}
	else{$variables->{'statCols'}->{'normGrowthRatio'}=1;}

	# check if the the normalized growth ratio column was found
	my $normRatioCol = -1;
	if(defined $colindex{'normalized growth ratio (comparer::exp)'}){$normRatioCol = $colindex{'normalized growth ratio (comparer::exp)'};}
	elsif(defined $colindex{'normalized ratio (comparer::exp)'}){$normRatioCol = $colindex{'normalized ratio (comparer::exp)'};}
	if($normRatioCol < 0){$missingData.='<li>Normalized Growth Ratio (Comparer::Exp)</li>';}
	else{$variables->{'statCols'}->{'normRatio'}=1;}

	# check if the pvalue column was found
	my $pValueCol;
	$variables->{'statCols'}->{'pValue'}=1;
	if(defined $colindex{'p-value'}){
		$pValueCol= $colindex{'p-value'};
	}
	elsif(defined $colindex{'t-test p-value'}){$pValueCol = $colindex{'t-test p-value'}; }
	elsif(defined $colindex{'mann-whitney probability'}){$pValueCol = $colindex{'mann-whitney probability'}; }
	else{
		$pValueCol=-1;
		$missingData.='<li>P-Value, T-Test P-Value or Mann-Whitney Probability</li>';
		$variables->{'statCols'}->{'pValue'}=0;
	}

	# check if the zscore column was found
	my $zScoreCol = defined $colindex{'z-score'} ? $colindex{'z-score'} : -1;
	if($zScoreCol < 0){
		$missingData.='<li>Z-Score</li>';
	}
	else{$variables->{'statCols'}->{'zScore'}=1;}

	# display warning message about missing data, if needed
	if($missingData =~ /<li>/i && ! defined $variables->{'dontDorryAboutMissingValues'} ){
		$missingData.='</ul>';
		&update_interactive('Warning!', $missingData,' ','Processing ScreenMillStats-all data file...', 'dontDorryAboutMissingValues', 'svEngineSetup', $q);
		exit;
	}
	my $counter=0;
	my %data_per_plate;
	my %stats;
	my %controlInfo;
	# iterate over actual data
	while(<$DATA>){
		chomp;
		my @line=split /\t/;
		my $restinfo=''; # this string will store the info in the data file that is not associated with the "plate", "row", or "column" columns
		# start required fields...
		# required fields will be displayed in the image comparison tool, all other info will only be visible in the output file
		my $pval = ($pValueCol > 0 && defined $line[$pValueCol]) ? $line[$pValueCol] : '-' ;
		my $id='';
		if(! defined $variables->{'ignoreID'}){
			$id = defined $line[$colindex{'id column'}] ? $line[$colindex{'id column'}] : '';
			if($id eq ''){$id="BLANK";}
		}

		if($_ =~/- PLATE EXCLUDED/i){$id.=" --> PLATE EXCLUDED!";}
		my $logRatio = ($calcLogRatioCol > 0 && defined $line[$calcLogRatioCol]) ? $line[$calcLogRatioCol] : '-';
		my $zscore = ($zScoreCol > 0 && defined $line[$zScoreCol]) ? $line[$zScoreCol] : '-';
		my $gRatio = ($normGrowthRatioCol > 0 && defined $line[$normGrowthRatioCol]) ? $line[$normGrowthRatioCol] : '-';
		my $row = "\U$line[$colindex{'row'}]"; # convert row letters to uppercase
		my $col = $line[$colindex{'column'}];
		my $p="\U$line[$colindex{'plate #'}]";
		# remove brackets at the beginning and end of plate numbers
		$p =~ s/^\[{1}//;
		$p =~ s/\]{1}$//;
		#$p=~tr/0-9//cd; # remove anything that is not a number
		my $n_ratio = ($normRatioCol>0 && defined $line[$normRatioCol] ) ? $line[$normRatioCol] : '-';

		my $query = $line[$colindex{'query'}];
		my $condition = $line[$colindex{'condition'}];
		if(!defined $condition){$condition='';}
		%{$variables->{'originalData'}->{$p}->{"\L$query"}->{"\L$condition"}} = ('plateNum'=>$condition, 'query'=>$query, 'condition'=>$condition);
		$query = lc($query);
		$condition = lc($condition);
		# attempt to store designated control locations, if present
		if($colindex{'id column'} && $line[$colindex{'id column'}] && $line[$colindex{'id column'}] =~ /positive\scontrol/i){
			push(@{ $controlInfo{'controlLocations'}->{$p}->{$row}},  $col);
		}

		# if the current item is not excluded, dead or blank
		if($n_ratio!~/^ex|^dead|^blank|^\-/i){
			# and if a pthesh does not exist for it && the ratio is a valid number
			if(! defined $variables->{'pthresh'}->{$query}->{$condition} && &is_numeric($logRatio)){
					push(@{$stats{$query}->{$condition}->{'ratios'}},$logRatio);
					$stats{$query}->{$condition}->{'log_ratio_sum'}+=$logRatio;
			}
			# otherwise if it is significant add it to the list of significant data
			elsif($variables->{'pthresh'}->{$query}->{$condition} && &is_numeric($pval) && $pval <= $variables->{'pthresh'}->{$query}->{$condition}){
				# count number of guys below threshold for current condition
				$variables->{'num_sigs'}->{$query}->{$condition}++;
				$variables->{'hit_list'}->{$query}->{$condition}->{$p}.="<li>"."$id ($p - $row$col)</li>";
			}
			$variables->{'sample_size'}->{$query}->{$condition}++;
		}
		# end required fields

		# index 0 should be query name and index 1 should be condition
		$data_per_plate{"$query -> $condition -> $p"}++;

		# store the different conditions in the following hash (%conditions)
		if(defined $condition){if(!($variables->{'conditions'}->{$condition})){$variables->{'conditions'}->{$condition}=1;}}
		else{$condition='';}
		@{$data{$p}->{$query}->{$condition}->{$row}[$col]}=($id, $pval, $zscore, $n_ratio, $logRatio, $gRatio); #"$restinfo";
		$counter++;
		@{$all_data{$p}->{$query}->{$condition}->{$row}[$col]}=@line;
	}
	close $DATA;

	{
		# verify data per plate
		my ($base, $baseRef) =('','');
		foreach my $plateID(keys %data_per_plate){
			if($base && $base != $data_per_plate{$plateID} ){
				&update_error("Number of data per plate in ScreenMillStats-all file error.<br/>$plateID contains $data_per_plate{$plateID} and $baseRef contains $base.<br/>Fix your ScreenMillStats-all data file and try again.<br/>".&contact_admin(), $q);
				exit;
				#die "# data / plate in ScreenMillStats-all file error.  $plateID contains $data_per_plate{$plateID} and $baseRef contains $base\n";
			}
			else{$base= $data_per_plate{$plateID}; $baseRef=$plateID;}
		}

		my @temp = keys %data_per_plate;
		if(!defined($base) || scalar(@temp) < 1 || $base eq ''){
			&update_error("Could not find any data within your ScreenMillStats-All Data File. Please verify that this file contains data and try again.</br></br>".&contact_admin(), $q);
			exit;
		}

		# based on the $base variable that was verified in the previous coding block, assign row and col values
		if($base==96){$variables->{'rows'}=8;$variables->{'cols'}=12;}
		elsif($base==384){$variables->{'rows'}=16;$variables->{'cols'}=24;}
		elsif($base==1536){$variables->{'rows'}=32; $variables->{'cols'}=48;}
		elsif($base==768 && $variables->{'replicates'} eq '2h'){$variables->{'rows'}=32; $variables->{'cols'}=24;}
		elsif($base==768 && $variables->{'replicates'} eq '2v'){$variables->{'rows'}=16; $variables->{'cols'}=48;}
		else{
			if(!defined($base) || !$base){$base = "n/a";}
			&update_error("Invalid density / replicate combinations calculated.<br/>Replicates calculated = $variables->{'replicates'}<br/>Density calculated = $base.<br/><i>ScreenMill - SV Engine</i> currently only supports:<br/>96, 384, and 1536 densities<br/>and<br/>2 horizontal, 2 vertical, 4 square, or 16 square replicates".&contact_admin(), $q);
			exit;
			#die "Invalid density: Replicates: $variables->{'replicates'} --> Density $base.\n";
		}
		$variables->{'density'}=$base;
	}
	# check to make sure that a p-value thresh has been calculated for all combos, if not, do it
	foreach my $query(keys %stats){
		foreach my $condition(keys %{$stats{$query}}){
			if(! defined $variables->{'pthresh'}->{$query}->{$condition}){
				if(($variables->{'statsMethod'} eq 't-test' || $variables->{'statsMethod'} eq 'Mann-Whitney')){
					$variables->{'pthresh'}->{$query}->{$condition}=0.05;
				}
				elsif(@{$stats{$query}->{$condition}->{'ratios'}} > 0){
					my ($std_dev, $var, $average);
					($std_dev, $var, $variables->{'pthresh'}->{$query}->{$condition}, $average) =
											&generateNormalStats(\@{$stats{$query}->{$condition}->{'ratios'}}, $stats{$query}->{$condition}->{'log_ratio_sum'}, $q);
					$variables->{'num_sigs'}->{$query}->{$condition}=0;
					$variables->{'hit_list'}->{$query}->{$condition}={};
				}
				foreach my $plate(keys %data){
					if($data{$plate}->{$query}->{$condition}){ # if this plate exists
						for(my $col=1; $col<=$variables->{'cols'}; $col++) {
							for (my $row=0; $row<$variables->{'rows'}; $row++){
								my $pval=$data{$plate}->{$query}->{$condition}->{$alphabet[$row]}[$col]->[1];
								if(&is_numeric($pval)
										&& $pval <= $variables->{'pthresh'}->{$query}->{$condition}
										&& $data{$plate}->{$query}->{$condition}->{$alphabet[$row]}[$col]->[3] !~/^ex|^dead|^blank/i){
									# count number of guys below threshold for current condition
									$variables->{'num_sigs'}->{$query}->{$condition}++;
									$variables->{'hit_list'}->{$query}->{$condition}->{$plate}.="<li>$data{$plate}->{$query}->{$condition}->{$alphabet[$row]}[$col]->[0]"." ($plate- $alphabet[$row]$col)</li>";
								}
							}
						}
					}
				}
			}
		}
	}


	if($variables->{'normalization_method'} eq 'controls'){
		my $plates="<ul>";
		foreach my $plate(sort {$a<=>$b} keys %data){
			# if we are normalizing to designated controls and no controls were found on the currently plate then throw an error...
			if(! defined $controlInfo{'controlLocations'}->{$plate}){	$plates.="<li>$plate</li>";	}
		}
		# if $plates exists and we are in designated controls normalization mode, throw and error
		if($plates=~/li/){
			$plates.="</ul>";
			&update_error('There was an error processing your ScreenMillStats-all.txt file. SV Engine could not find designated controls on the following plates:<br/>'.$plates.'Note that control locations should be indicated by placing the phrase "Positive Control" in the ID column of the rows that contain control data.<br/>'.&contact_admin(), $q);
			exit;
			#die "error processing key file. could not find designated controls $plates.";
		}
	}

	if($variables->{'processing_choice'} eq 'pictures'){ # this should already be done if we are not in picture mode...
		if($variables->{'density'} == 96){$variables->{'rows'}=8; $variables->{'cols'}=12;}
		elsif($variables->{'density'} == 384){$variables->{'rows'}=16; $variables->{'cols'}=24;}
		elsif($variables->{'density'} == 1536){$variables->{'rows'}=32; $variables->{'cols'}=48;}
		else{
			&update_error("Invalid density calculated from your ScreenMillStats-all data file (density screened / # replicates).<br/>Density calculated = $variables->{'density'}, acceptable values are: 96, 384, or 1536.<br/>".&contact_admin, $q);
			exit;
			#die "Invalid density calculated from your ScreenMillStats-all data file (density screened / # replicates).<br/>Density calculated = $variables->{'density'}. $!\n";
		}
	}

	eval {store(\%data, "$variables->{'save_directory'}/out_all_shorty.dat")};
	if($@){&update_error (&generic_message(),$q); die 'Serious error from Storable storing %data: $@';}
	eval {store(\%all_data, "$variables->{'save_directory'}/out_all.dat")};
	if($@){&update_error (&generic_message(),$q); die 'Serious error from Storable storing %all_data: $@';}

	return(\%data, \%controlInfo);
}

sub mysql_setup_dr_experiment{
	use DateTime;
	my ($q, $variables)=@_;
	my %db_info;
	# remove duplicates...
	{
		my %seen;
		my @temp = grep { !$seen{$_}++ } @{$variables->{'store_params'}->{'sets_to_save'}};
		$variables->{'store_params'}->{'sets_to_save'} = \@temp;
	}

	$db_info{'insert_limit'} = 20;

	# connect to the db, verify connection
	$db_info{'dbh'} = &connectToMySQL();
	if(!$db_info{'dbh'}){
		&update_error("Error connecting to MySQL database - analysis halted.<br/>".&return_to_dr(),$q);
		die "Could not connect to mysql db in &mysql_setup_dr_experiment.";
	}

	my $exp_table = 'experiments';
	my $raw_dataset_table = 'experiment_raw_datasets';

	# NOTE! if the order of @raw_fields changes the array is modified in any way it WILL break stuff below when inserting data
	my @raw_fields = qw(density_id pwj_plasmid_id condition batch_date updated_by created_at updated_at);

	my @exp_fields = qw(batch_date density comparer query condition replicates screen_type screen_purpose library_used donor_strain_used);

	# if we have made it this far then we can safely store the experiment data in the db
	# at this point add ALL data except `number_of_plates` and `experiment_comparer_raw_dataset_id`
	my $select = 'SELECT `id`, `rows`, `columns` from `densities` WHERE `density` = ? LIMIT 1';
	my $st = $db_info{'dbh'}->prepare($select);
	$st->execute($variables->{'density'});
	my $density_id = -1;
	while ( my $row = $st->fetchrow_arrayref() ) {
		if(defined $row->[0] && $row->[0] ne ""){
			$density_id = $row->[0];
			$variables->{'store_params'}->{'raw_rows'} = $row->[1];
			$variables->{'store_params'}->{'raw_columns'} = $row->[2];
		}
	}
	$st->finish();

	eval{
		# setup statememt to store experiment params
		push(@exp_fields, qw(incubation_temperature pre_screen_library_replicates mating_time first_gal_leu_time second_gal_leu_time final_incubation_time created_by updated_by performed_by created_at updated_at experiment_query_raw_dataset_id experiment_comparer_raw_dataset_id));
		my $mySQLst = "INSERT INTO `$exp_table` (`".join('`, `',@exp_fields)."`) VALUES ";
		my @placeHolders = ('?') x scalar(@exp_fields);
		my $placeHolders = join(',',@placeHolders);
		my $limit = 1;
		$mySQLst .= "($placeHolders), " x $limit;
		$mySQLst =~ s/, $//; # remove trailing comma and space
		$mySQLst.=" ON DUPLICATE KEY UPDATE ";
		foreach my $field(@exp_fields){$mySQLst.= "`$field`=VALUES(`$field`), ";}
		$mySQLst =~ s/, $//; # remove trailing comma and space

		my $statement = $db_info{'dbh'}->prepare($mySQLst);

		# setup statememt to store raw dataset params...
		my $raw_dataset_sql = "INSERT INTO `$raw_dataset_table` (`".join('`, `',@raw_fields)."`) VALUES ";
		@placeHolders = ('?') x scalar(@raw_fields);
		$placeHolders = join(',',@placeHolders);
		$raw_dataset_sql .= "($placeHolders), " x $limit;
		$raw_dataset_sql =~ s/, $//; # remove trailing comma and space
		$raw_dataset_sql.=" ON DUPLICATE KEY UPDATE ";
		foreach my $field(@raw_fields){$raw_dataset_sql.= "`$field`=VALUES(`$field`), ";}
		$raw_dataset_sql =~ s/, $//; # remove trailing comma and space
		my $raw_statement = $db_info{'dbh'}->prepare($raw_dataset_sql);

		# setup and execute statement to determine the id value of the comparer pwj
		$select = 'SELECT `id` from `pwj_plasmids` WHERE `number` LIKE ? LIMIT 1';
		my $plasmid_st = $db_info{'dbh'}->prepare($select);
		$plasmid_st->execute($variables->{'store_params'}->{'comparer_pwj'}->{'pwj'});
		my $comparer_plasmid_id = -1;
		while ( my $row = $plasmid_st->fetchrow_arrayref() ) {
			if(defined $row->[0] && $row->[0] ne ""){
				$comparer_plasmid_id = $row->[0];
			}
		}
		$plasmid_st->finish();

		my $now = DateTime->now->datetime;
		$now =~ y/T/ /;

		my $control_query = $variables->{'control'};
		$control_query =~ s/^0000_//;


		foreach my $c(keys %{$variables->{'store_params'}->{'conditions'}}){
			# $c = the user-entered condition, $condition is the usered entered, corrected condition
			my $condition = $variables->{'store_params'}->{'conditions'}->{$c};
			$raw_statement->bind_param(1, $density_id);
			$raw_statement->bind_param(2, $comparer_plasmid_id);
			$raw_statement->bind_param(3, $condition);
			$raw_statement->bind_param(4, $variables->{'store_params'}->{'batch_date'});
			$raw_statement->bind_param(5, $variables->{'store_params'}->{'performed_by'});
			$raw_statement->bind_param(6, $now);
			$raw_statement->bind_param(7, $now);
			$raw_statement->execute();
			# get ID of last row inserted
			$db_info{'row_ids'}->{'raw_dataset_ids'}->{lc($control_query)}->{lc($c)} = $db_info{'dbh'}->{mysql_insertid};
		}

		foreach my $qc_sets( @{ $variables->{'store_params'}->{'sets_to_save'} }){
			# if the query is the control, do not create a new experiment
			if($qc_sets->{'query'} ne $control_query){
				# $qc_sets is a hash ref with the following keys:
				# 'id', 'query', 'pwj', 'condition'
				$now = DateTime->now->datetime;
				$now =~ y/T/ /;

				$plasmid_st->execute($qc_sets->{'pwj'});
				my $plasmid_id = -1;
				while ( my $row = $plasmid_st->fetchrow_arrayref() ) {
					if(defined $row->[0] && $row->[0] ne ""){
						$plasmid_id = $row->[0];
					}
				}
				$plasmid_st->finish();

				# create a dataset row
				$raw_statement->bind_param(1, $density_id);
				$raw_statement->bind_param(2, $plasmid_id);
				$raw_statement->bind_param(3, $qc_sets->{'condition'});
				$raw_statement->bind_param(4, $variables->{'store_params'}->{'batch_date'});
				$raw_statement->bind_param(5, $variables->{'store_params'}->{'performed_by'});
				$raw_statement->bind_param(6, $now);
				$raw_statement->bind_param(7, $now);
				$raw_statement->execute();
				$raw_statement->finish();
				my $raw_query_dataset_id = $db_info{'dbh'}->{mysql_insertid}; # returns last ID of last row inserted
				$db_info{'row_ids'}->{'raw_dataset_ids'}->{lc($qc_sets->{'query'})}->{lc($qc_sets->{'original_condition'})} = $raw_query_dataset_id;

				my $raw_comparer_dataset_id = $db_info{'row_ids'}->{'raw_dataset_ids'}->{lc($control_query)}->{lc($qc_sets->{'original_condition'})};
				if(!defined $raw_comparer_dataset_id){
					&update_error("Error identifying the proper comparer dataset id for condition '$qc_sets->{'condition'}'.<br/>".&return_to_dr(),$q);
					exit(0);
				}

				# warn "inserting exp for $qc_sets->{'query'}, $qc_sets->{'condition'}";
				my $placeHolder=1;
				# below is far from efficient, but it's more maintainable and I think it means that if we change the param array
				# that the code below `shouldn't` need to change
				foreach my $field(@exp_fields){
					if($field =~ /^comparer$/){	$statement->bind_param($placeHolder++, $variables->{'store_params'}->{'comparer_pwj'}->{'pwj'});	}
					elsif($field =~ /^query$/){	$statement->bind_param($placeHolder++, $qc_sets->{'pwj'});	}
					elsif($field =~ /^condition$/){	$statement->bind_param($placeHolder++, $qc_sets->{'condition'});	}
					elsif($field =~ /_by$/){	$statement->bind_param($placeHolder++, $variables->{'store_params'}->{'performed_by'});	}
					elsif($field =~ /_at$/){	$statement->bind_param($placeHolder++, $now);	}
					elsif($field =~ /^experiment_query_raw_dataset_id$/){	$statement->bind_param($placeHolder++, $raw_query_dataset_id);	}
					elsif($field =~ /^experiment_comparer_raw_dataset_id$/){	$statement->bind_param($placeHolder++, $raw_comparer_dataset_id);	}

					elsif(defined $variables->{'store_params'}->{$field}){
						$statement->bind_param($placeHolder++, $variables->{'store_params'}->{$field});
					}
					elsif(defined $variables->{$field}){
						$statement->bind_param($placeHolder++, $variables->{$field});
					}
					else{
						&update_error("Error identifying experiment fields, could not id field: '$field' - analysis halted.<br/>".&return_to_dr(),$q);
						&rollback_now(\%db_info);
						$db_info{'dbh'}->disconnect();
						die "Error identifying experiment fields, could not id field: '$field'.";
					}
				}
				$statement->execute();
				# $db_info{'row_ids'}->{'experiments'}->{lc($qc_sets->{'query'})}->{lc($qc_sets->{'original_condition'})} = $db_info{'dbh'}->{mysql_insertid}; # returns last ID of last row inserted
			}
		}
		$statement->finish();
	};
	if($@){
		&update_error("Error inserting experiment data into database - analysis halted.<br/>".&return_to_dr(),$q);
		die "Error inserting experiment data into database. $@";
	}
	return(\%db_info);
}

sub mysql_setup_statement{
	my ($table_name, $fields, $limit) = @_;
	my $mySQLst = "INSERT INTO `$table_name` (`".join('`, `',@{$fields})."`) VALUES ";
	my @placeHolders = ('?') x scalar(@{$fields});
	my $placeHolders = join(',',@placeHolders);
	$mySQLst .= "($placeHolders), " x $limit;
	$mySQLst =~ s/, $//; # remove trailing comma and space
	return $mySQLst;
}

sub mysql_setup_raw_data_statement_handle{
	my $variables = shift;
	my $table_name = 'experiment_colony_data';
	my @fields = qw(plate row column colony_measurement colony_circularity experiment_raw_dataset_id);
	my $limit = $NUM_REPLICATES{$variables->{'replicates'}} * $variables->{'store_params'}->{'sql_vars'}->{'insert_limit'};
	my $mySQLst = &mysql_setup_statement($table_name, \@fields, $limit);
	$variables->{'store_params'}->{'sql_vars'}->{'raw_data_insert_sth'}->{'sth'} = $variables->{'store_params'}->{'sql_vars'}->{'dbh'}->prepare($mySQLst);
	$variables->{'store_params'}->{'sql_vars'}->{'raw_data_insert_sth'}->{'num_bind_params'} = scalar(@fields)*$limit;
	return 1;
}

sub mysql_setup_exclude_colonies_statement_handle{
	my $variables = shift;
	my $table_name = 'excluded_colonies';
	my @fields = qw(experiment_raw_dataset_id plate row column);
	my $limit = 1;
	my $mySQLst = &mysql_setup_statement($table_name, \@fields, $limit);
	$variables->{'store_params'}->{'sql_vars'}->{'excluded_colonies'}->{'sth'} = $variables->{'store_params'}->{'sql_vars'}->{'dbh'}->prepare($mySQLst);
	return 1;
}

# sub mysql_setup_screen_results_statement_handle{
# 	my $variables = shift;
# 	my $table_name = 'screen_results';
# 	my @fields = qw(experiment_id plate row column p_value z_score ratio ORF number_of_considered_exp_replicates exp_colony_circularity_mean exp_colony_circularity_variance exp_colony_size_mean exp_colony_circularity_variance comparer_colony_size_mean);
# 	my $limit = 20;
# 	my $mySQLst = &mysql_setup_statement($table_name, \@fields, $limit);
# 	$variables->{'store_params'}->{'sql_vars'}->{'screen_results_sth'}->{'sth'} = $variables->{'store_params'}->{'sql_vars'}->{'dbh'}->prepare($mySQLst);
# 	return 1;
# }

sub mysql_insert_excluded_colonies{
	my ($excluded_colony,$variables) = @_;
	$variables->{'store_params'}->{'sql_vars'}->{'excluded_colonies'}->{'sth'}->execute(@{$excluded_colony});
	return 1;
}

sub mysql_insert_raw_data{
	my ($mysql_raw_col,$variables,$iterator) = @_;
	# iterator starts at 1!!!
	if($iterator >= $variables->{'store_params'}->{'sql_vars'}->{'insert_limit'}){
		my $length = scalar(@{$mysql_raw_col});
		my $req_length = $variables->{'store_params'}->{'sql_vars'}->{'raw_data_insert_sth'}->{'num_bind_params'};
		push(@{$mysql_raw_col}, (undef) x ($req_length-$length));
		$variables->{'store_params'}->{'sql_vars'}->{'raw_data_insert_sth'}->{'sth'}->execute(@{$mysql_raw_col});
		@{$mysql_raw_col} = ();
		return 1;
	}
	return $iterator+1;
}

# sub mysql_insert_screen_results{
# 	my ($screen_results,$variables) = @_;
# 	$variables->{'store_params'}->{'sql_vars'}->{'screen_results_sth'}->{'sth'}->execute(@{$screen_results});
# 	return 1;
# }

sub mysql_delete_null_exp_colony_data_rows{
	my ($variables) = @_;
	my $deleteMySQLsth = $variables->{'store_params'}->{'sql_vars'}->{'dbh'}->prepare("DELETE FROM `experiment_colony_data` WHERE `experiment_raw_dataset_id` is NULL") or die "Can't prepare statement: $DBI::errstr"; # Prepare the statement
	$deleteMySQLsth->execute();
	$deleteMySQLsth->finish();
}

# average growth of replicates, normalize to plate mean or median,
sub generateDescriptiveStats{
	use Statistics::Descriptive;
	my($control,$p, $normalization_values, $variables, $excluded_plates, $exclude_col_ref,$q)=@_;

	my ($control_plate_details, $plate_summary, %excludedData,$original_query,$excludedOnControlCounter,
		 $control_sizes, $orfs_considered_total,$plate_con,$col_size, $controlInfoForDatabase, $dead_size,
		 %original_data, $query, $plate, $condition, $current_col, %plateStats,
		 $current_row, $colony_count, $i, $sizes,$col_circ, $circularities);


	my $raw_data_sql_sub = sub{ $_[0] = (); return 0;};
	my $excluded_col_sql_sub = sub{ return 0;};
	# my $screen_results_sql_sub = sub{ return 0;};
	if($variables->{'store_params'}->{'sql_vars'}){
		&mysql_setup_raw_data_statement_handle($variables);
		&mysql_setup_exclude_colonies_statement_handle($variables);
		$raw_data_sql_sub = \&mysql_insert_raw_data;
		$excluded_col_sql_sub = \&mysql_insert_excluded_colonies;
	}

	# if variables->{'replicates'} eq '2v', need to use alternative ordering of colony_positions
	# (essentially just current position and one below ), the other (longer) config is
	# suited for 1, 2h, 4, or 16 reps. This is because the 1st 2 indices are the current
	# position and one to the right (this is suited for the 2h config)
	#
	my @colony_positions = ($variables->{'replicates'} ne '2v') ? (-1,$variables->{'rows'}-1,0,$variables->{'rows'},1,2,($variables->{'rows'}+1),($variables->{'rows'}+2),($variables->{'rows'}*2-1), ($variables->{'rows'}*2),($variables->{'rows'}*2+1),($variables->{'rows'}*2+2),($variables->{'rows'}*3-1),($variables->{'rows'}*3), ($variables->{'rows'}*3+1), ($variables->{'rows'}*3+2)) : (-1,0);

	# $colony_count will be set to the number of colonies on the plate that need to be iterated over
	# if the replicates = 2h or 4 the last column does not need to be iterated over
	if($variables->{'replicates'} eq '4' || $variables->{'replicates'} eq '2h' ){$colony_count=$variables->{'density'}-$variables->{'rows'};}
	elsif($variables->{'replicates'} eq '1' || $variables->{'replicates'} eq '2v' ) {$colony_count=$variables->{'density'};}
	# do not need to iterate over the last 3 columns because they should be accounted for in the average calculations
	#for the 4th to last column (16 replicates = 4 x 4)
	elsif($variables->{'replicates'}==16){$colony_count=$variables->{'density'}-($variables->{'rows'}*3);}
	else{$colony_count=$variables->{'density'};}

	my $stripped_control_query=$control;
	$stripped_control_query=~ s/0000_//;
	$control_plate_details="";
	$plate_summary="";

	# the following loops (3) will iterate over all data entered and calculate the average colony growth
	my %controlData;

	# use Benchmark; # bench mark running time -> used for debugging
	# my $preStart = new Benchmark;

	# iterate over all raw data, sort so that controls are analyzed first.
	# only consider data that has NOT been marked for exclusion
	# If performing Mann-Whitney U test then p-values will be directly calculated here and we will need to store the replicate values for the control
	# data and then access them when we are iterating over the experimental data. If we are not performing a mann-whitney test then count (# replicates)
	# count(), mean, standard_deviation and variance for each set of replicates is calculated (regardless of whether it is control or experimental data)
	foreach $plate(keys %{$p}){
		foreach $query(sort keys %{ $p->{$plate} }){
			$original_query=$query; # before we strip out 0000_
			foreach $condition(keys %{ $p->{$plate}->{$query} }){
				my $raw_data_mysql_iterator = 1;
				#warn "$query --> $plate\n";
				# the above two lines print out the colony growth average on each plate
				my $data=$p->{$plate}->{$original_query}->{$condition}->[0]; # $data is a reference to an array that contains all the colony areas for a given plate, condition, and query combo
				my $circ=$p->{$plate}->{$original_query}->{$condition}->[1]; # $circ is a reference to an array that contains all the circularity measurements for a given plate, condition, and query combo
				delete($p->{$plate}->{$original_query}->{$condition});
				$query=~ s/^0000_// if $query eq $control;
				&update_message("Analyzing Replicates - $plate, $query, $condition", $q);

				# this needs to be after we strip out the 0000_
				my $raw_dataset_id = -1;
				# my $experiment_id = -1;
				if($variables->{'store'}){
					$raw_dataset_id = $variables->{'store_params'}->{'sql_vars'}->{'row_ids'}->{'raw_dataset_ids'}->{$query}->{$condition};
					if(defined $raw_dataset_id){
						$raw_data_sql_sub = \&mysql_insert_raw_data;
						$excluded_col_sql_sub = \&mysql_insert_excluded_colonies;
					}
					else{
						$raw_data_sql_sub = sub{ $_[0] = (); return 0;};
						$excluded_col_sql_sub	= sub{ return 0;};
					}
				}

				my @dataStats=(); # will store the descriptive statistics of considered data
				my @original_sizes=(); # will store the original values and indicate which, if any, of the colonies in a set were excluded
				my @original_circularities=();
				$current_col=1; # used to calculate current column of the plate that we are on
				$current_row=0; # used to calculate current row of the plate that we are on
				$dead_size=$normalization_values->{$plate}->{$query}->{$condition} * $variables->{'death_threshold_cutoff'}; # retrieve dead size of current plate
				# store summary of plate information into database
				$plate_summary.="$query\t$condition\t$plate\t$normalization_values->{$plate}->{$query}->{$condition}\t$dead_size\n";

				#calculate the stats, store in the lexical array variable @dataStats

				my @mysql_raw_col = ();

				for($i=1;$i<=$colony_count;$i++) {
					# the following two lines skip over columns so that you do not count values more then once
					if(	$i>=$variables->{'rows'} && $i % ($variables->{'rows'})==1	){
						$current_row=0;
						$current_col++;
						if($variables->{'replicates'} eq '2h' || $variables->{'replicates'} eq '4'){$i=$i+$variables->{'rows'}; }
						elsif($variables->{'replicates'} eq '16'){$i=$i+($variables->{'rows'}*3);}
					}
					# initialize variables
					# $colony_sizes_considered --> Stats::Descriptive object, holds values of colony sizes being considered for statistics
					# $colony_circularities_considered --> Stats::Descriptive object, holds values of colony circularities being considered for statistics
					# $sizes --> holds colony sizes as a sting, delimited by tabs
					# $allReplicates --> another Stats::Descriptive object, keeps track of total, regardless if colony has been excluded or not
					# $excludedOnControlCounter --> counts the number of excluded control colonies in a given set of replicates
					$sizes="";
					$excludedOnControlCounter=0;
					$control_sizes="";
					$circularities="";
					# note, full stats are required so we can pull the data out
					my $colony_sizes_considered = Statistics::Descriptive::Full->new();
					# my $colony_circularities_considered = Statistics::Descriptive::Sparse->new();
					my $allReplicates = Statistics::Descriptive::Full->new();


					for(my $j=0;$j<$NUM_REPLICATES{$variables->{'replicates'}};$j++){

						my $position = $colony_positions[$j]+$i;

						my $current_raw_col = int( $position / $variables->{'rows'} );
						my $current_raw_row = $position - ($current_raw_col*$variables->{'rows'});

						push(@mysql_raw_col, ($plate,$alphabet[$current_raw_row],$current_raw_col+1) );
						push(@mysql_raw_col, $data->[$position]);

						$col_size=0;
						$col_circ='n/a';

						# get first value, normalize it
						my $normValue = $data->[$position]/$normalization_values->{$plate}->{$query}->{$condition};
						# if colony size is a non-zero value divide it by the plate norm value to get its relative growth rate
 						if($data->[$position] >= 1 || $data->[$position] > $dead_size){
							$col_size=sprintf("%.2f",($normValue));
							if (defined $$circ[$position]){
								$col_circ=$$circ[$position]
								# $colony_circularities_considered->add_data($col_circ);
							}
						}
						push(@mysql_raw_col, ($col_circ, $raw_dataset_id) );


						# if this colony or plate has been excluded from statistical consideration by the user then...
						if($excluded_plates->{"$query,$plate,$condition"} || ${$exclude_col_ref->{$plate}->{$query}->{$condition}->{$position}}[0]){
							$col_size.='*';
							$col_circ.='*';# mark with '*' if this colony has been excluded
							$excluded_col_sql_sub->([$raw_dataset_id, $plate, $alphabet[$current_raw_row],$current_raw_col+1], $variables);
						}
						else{
							$colony_sizes_considered->add_data($normValue);

						}

						if(${$exclude_col_ref->{$plate}->{$stripped_control_query}->{$condition}->{$position}}[0] || $excluded_plates->{"$stripped_control_query,$plate,$condition"}){
							$excludedOnControlCounter++;
							$control_sizes.="$col_size^\t";
							$col_size.='^';
							$col_circ.='^';
						} # else if it has been excluded on control then add 1 to excluded_on_control
						$allReplicates->add_data($normValue);

						# now that col_size and col_circ have been 'processed' add them to the sizes and circularities strings
						$sizes.="$col_size\t";
						$circularities.="$col_circ\t";

					}

					$raw_data_mysql_iterator=$raw_data_sql_sub->(\@mysql_raw_col,$variables,$raw_data_mysql_iterator);

					# remove trailing tabs, if they exist
					$sizes  =~ s/\t+$//;
					$circularities  =~ s/\t+$//;
					$control_sizes  =~ s/\t+$//;

					#warn "$query,$plate,$condition $alphabet[$current_row]$current_col- $sizes - colony_sizes_considered count = ".$colony_sizes_considered->count()."excludedOnControlCounter = $excludedOnControlCounter\n";

					my $ave = $colony_sizes_considered->mean();

					# if there is no data in @colony_sizes_considered, then all colonies were selected for exclusion
					# also if excludedOnControlCounter == # replicates then all control colonies for this guy have been excluded, so exclude it as well....
					if($colony_sizes_considered->count() == 0 || $excludedOnControlCounter==$NUM_REPLICATES{$variables->{'replicates'}}){
						$colony_sizes_considered = $allReplicates; # set the data to be considered to be allReplicates
						$ave = $colony_sizes_considered->mean(); # reset the average
						if($excludedOnControlCounter==$NUM_REPLICATES{$variables->{'replicates'}}){
							$sizes = $control_sizes;
							$controlInfoForDatabase='^'.$ave; # store average, mark as control excluded
						}
						else{$controlInfoForDatabase=$ave;} # store average
						$excludedData{"$plate,$query,$condition-".($#dataStats+1)}=1; # mark this as excluded
						#warn "added to exclude list as --> $plate,$query,$condition ->".($#dataStats+1)."\n";
					}
					else{
						# else we are good, but check to make sure average colony size is > 1
						if($ave>$variables->{'death_threshold_cutoff'}){
							$controlInfoForDatabase=$ave;
						}
						# else these guys are dead!
						else{
							$ave = ($ave > 0.1) ? $ave : 0.1;
							$controlInfoForDatabase ="dead";
						}
					}

					if($variables->{'statsMethod'} eq 'Mann-Whitney'){
						# if we are in a control situation store all data...will get marked as excluded later
						if($original_query eq $control){
							$controlData{$plate}->{$condition}->{$current_row}->{$current_col} = $colony_sizes_considered->{data};
							push @dataStats, [0, $ave, $colony_sizes_considered->standard_deviation(), $colony_sizes_considered->variance()];
						}
						# else calculate Mann-Whitney Stat
						else{
							push @dataStats, [&calculateMannWhitney($colony_sizes_considered->{data}, $controlData{$plate}->{$condition}->{$current_row}->{$current_col}), $ave, $colony_sizes_considered->standard_deviation(), $colony_sizes_considered->variance()];
						}
					}
					# else push general info...
					else{	push @dataStats, [$colony_sizes_considered->count(), $ave, $colony_sizes_considered->standard_deviation(), $colony_sizes_considered->variance()];}

					$variables->{'numData'}->{$query}->{$condition}++;
					# iterate i here to move to the next set of replicates....note that i will also increase by 1 at the start of this loop
					if($variables->{'replicates'} eq '4' || $variables->{'replicates'} eq '2v'){$i++;}
					elsif($variables->{'replicates'} eq '16'){$i+=3;}
					push (@original_sizes,$sizes);
					push(@original_circularities, $circularities);
					if($original_query eq $variables->{'control'}){
					# 	# store detailed control plate info...
						$control_plate_details.="$query\t$condition\t$plate\t$alphabet[$current_row]\t$current_col\t$controlInfoForDatabase\t$sizes\t$circularities\n";
					}
					$current_row++;
				}

				# set the 3rd param to an arbitrary large value to ensure the statement is executed...
				$raw_data_mysql_iterator=$raw_data_sql_sub->(\@mysql_raw_col,$variables,$colony_count);

				#store a reference to @dataStats in the data structure, overwriting the previous data that was there (the original, raw data...)
				$plateStats{$plate}->{$query}->{$condition}=[@dataStats];
				$original_data{$plate}->{$query}->{$condition}->[0]=[@original_sizes]; # colony area measurements
				$original_data{$plate}->{$query}->{$condition}->[1]=[@original_circularities]; # colony circularity measurements
			}
		}
	}

	if($variables->{'store'}){
		&mysql_delete_null_exp_colony_data_rows($variables);
	}
	# my $start = new Benchmark;
	#warn "Time taken to load data was ", timestr(timediff($start, $preStart), 'all'), " seconds";
	# warn "Time taken was ". timestr(timediff($start, $preStart), 'all'). " seconds<br/>";


	return (\%plateStats, \%original_data, \%excludedData, \$plate_summary, \$control_plate_details);
}

# perform the Wilcoxon (aka Mann-Whitney) rank sum test on two sets of numeric data with continuity correction...
# In statistics, the Mann-Whitney U test (also called the Mann-Whitney-Wilcoxon (MWW), Wilcoxon rank-sum test,
# or Wilcoxon-Mann-Whitney test) is a non-parametric test for assessing whether two samples of observations come from the same distribution.
# The null hypothesis is that the two samples are drawn from a single population, and therefore that their probability distributions are equal
# returns probability that samples are from the same population, if total sample size <= 10 returns an exact p-value, otherwise assumes a normal distribution
sub calculateMannWhitney{
	use Statistics::MannWhitneyTest;
	# data1 and data2 are references to arrays that contain the 2 different data sets to perform the Mann-Whitney test on
	my ($data1, $data2) = @_;

	#warn Dumper($data1); warn Dumper($data2);
	my @dataCheck1 = grep { $_ > 0 } @{ $data1 };
	my @dataCheck2 = grep { $_ > 0 } @{ $data2 };
	# warn join(", ", @{$data1});
	# warn join(", ", @{$data2});
	# if both datasets contain only 0 values then return 1
	if(!@dataCheck1 && !@dataCheck2){return 1;}
	# if only one dataset contains all zeros, add 0.0000001 to the first element of each
	# to prevent wilcox_test from throwing an error
	elsif(!@dataCheck1 || !@dataCheck2){
		$data1->[0]+=0.00000001;
		$data2->[0]+=0.00000001;
	}
	my $wilcox_test = Statistics::MannWhitneyTest->new();
	$wilcox_test->load_data($data1, $data2);
	# warn "P-value = ".$wilcox_test->probability();
	return $wilcox_test->probability();
}

sub calculateControlExperimentalRatios{
	my ($plateStats, $variables, $excludedData, $keyinfo, $normalization_values, $q)=@_;
	my %num_orfs_considered; # number of ORFS considered on a per gene basis...
	my %orfs_considered_total; # total unique orfs considered...uses information stored in %keyinfo as values to prevent duplicate entries
	my ($dead_size, @ratio_data, $data_size, $c_size, @actualR, $plate, $query, $condition, $rows, $cols, $current_col,
			$current_row, $i, $rounded, $blank_rounded, $dead_rounded, $exclude_rounded, $total_ratio_info, @total_ratio_data, %ratios, %log_ratio_sum,%considered_ratios);
	#calculate ratios of experimental data:control
	my $fBlankMarker = ($variables->{'key_choice'} eq 'none') ? '' : 'blank-';
	my $eBlankMarker = ($variables->{'key_choice'} eq 'none') ? '' : '-blank';

	my $control = $variables->{'control'};
	$control=~ s/0000_//; # strip out 0000_ tag...
	foreach $plate(keys %{$plateStats}){
		foreach $query(keys %{ $plateStats->{$plate} }){
			foreach $condition(keys %{ $plateStats->{$plate}->{$query} }){
				#warn "$plate,$query,$condition \n";
				$condition = (defined $condition) ? $condition : '';
				if ($query ne $control){
					$dead_size=$normalization_values->{$plate}->{$query}->{$condition}*$variables->{'death_threshold_cutoff'};

					my $eStats=$plateStats->{$plate}->{$query}->{$condition}; #store experimental data stats
					my $cStats=$plateStats->{$plate}->{$control}->{$condition}; #store control data stats
					@ratio_data=(); # this will be the array that will temporarily store the ratio data for a given query

					$data_size=scalar(@{$eStats});  #stores the size of the data
					$c_size=scalar(@{$cStats});   #stores the size of the control data

					$current_col=1;
					$current_row=0;
					@actualR=(); #stores actual ratio (i.e. 1/2 instead of 0.5)

					# each value in eStats and cStats is an array with the following data:
					# 0 = num samples, 1 = mean, 2 = standard_deviation, 3 = variance
					# if the sizes of the control and experimental data are not equal something is wrong
					if($data_size != $c_size || $data_size != $variables->{'collapsedDensity'}){
						if ($condition eq ""){$condition="none";}
						if ($c_size eq ""){$c_size="does not exist";}
						my $holder="Comparer data and experiment data are not the same size! Please fix this in your log file and try again.<br/>It could also be that your log file does not contain the comparer data for this plate (probably true if size of comparer below = 0).<br/>Query = $query<br/>Condition = $condition<br/>Plate Number $plate<br/>Size of comparer = $c_size<br/>Size of experiment = $data_size.<br/>".&contact_admin();
						&update_error($holder, $q);
						exit(0);
						#die "$holder";
					}
					else{
						#print "<br/><br/>Average colony size on current plate ( $holder ): $normalization_values->{$plate}->{$query}->{$condition}<br/>";
						for($i=1; $i<=$data_size; $i++){
							if($i>=$variables->{'collapsedRows'} && $i%$variables->{'collapsedRows'}==1){$current_col++; $current_row=0;}
							# the following if statements account for 0 values (you cant divide by 0)
							my $ratio = 1;
							my $logRatio=0;
							if($eStats->[$i-1]->[1]==0){$eStats->[$i-1]->[1]=0.1;}
							# now that the divisor is not 0 we can calculate the ratio
							$ratio = $cStats->[$i-1]->[1]/$eStats->[$i-1]->[1];
							# but wait! if the dividend is 0 then the ratio will be 0, but you cannot take the log of 0!!!
							# the next line protects against that
							if($cStats->[$i-1]->[1]==0){$cStats->[$i-1]->[1]=0.1; $logRatio = log($cStats->[$i-1]->[1]/$eStats->[$i-1]->[1]);}
							else{$logRatio = log($ratio);}
							push (@ratio_data, [$ratio, $logRatio]);

							# set-up rounded ratios...
							$rounded=sprintf("%.2f",$cStats->[$i-1]->[1]).'::'.sprintf("%.2f",$eStats->[$i-1]->[1]);
							$blank_rounded=$fBlankMarker.$rounded.$eBlankMarker;
							$dead_rounded='dead-'.$rounded.'-dead';
							$exclude_rounded='excluded-'.$rounded.'-excluded';
							# mark excluded guys

							if (defined($excludedData->{"$plate,$query,$condition-".($i-1).""})){
								#warn "$plate,$query,$condition $alphabet[$current_row] $current_col";
								push (@actualR, $exclude_rounded);
							}
							# mark deads
							# note, have to mark deads before blanks because blanks can be used for statistical analysis (assuming they are wt blanks)
							# deads on the other hand would skew the stats...
							elsif($cStats->[$i-1]->[1] < $variables->{'death_threshold_cutoff'} && $eStats->[$i-1]->[1] < $variables->{'death_threshold_cutoff'}){
								push @actualR, $dead_rounded;
							}
							# mark blanks
							elsif(!defined ($keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col]) || $keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col] eq "BLANK" || $keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col] eq ""){
								push @actualR, $blank_rounded;
								push (@{$considered_ratios{$query}->{$condition}},$logRatio);
								$log_ratio_sum{$query}->{$condition}+=$logRatio; # sum of all ratios on segregated by query-condition
								$num_orfs_considered{$query}->{$condition}++;

							}
							# everything is ok, allow calculated values to be considered for statistics
							else{
								push @actualR, $rounded;
								push (@{$considered_ratios{$query}->{$condition}},$logRatio);
								$log_ratio_sum{$query}->{$condition}+=$logRatio; # sum of all ratios on segregated by query-condition
								$num_orfs_considered{$query}->{$condition}++;
								#$orfs_considered_total{$keyinfo{$plate}->{$alphabet[$current_row]}[$current_col]}="";
							} #calculate totals
							$current_row++;
						}
					}
					$plateStats->{$plate}->{$query}->{$condition}=();
					$plateStats->{$plate}->{$query}->{$condition}[0]=[@ratio_data]; # all log ratios
					$plateStats->{$plate}->{$query}->{$condition}[1]=[@actualR]; # ratio as comparer::experimental growth averages
#					push(@{$ratios{$query}->{$condition}}, @ratio_data); # build store query-condition ratio stats
				}
			}
		}
	}
	#return(\%num_orfs_considered, \@total_ratio_data, $total_ratio_info);
	return(\%num_orfs_considered, \%log_ratio_sum, \%considered_ratios);
}

sub processRestHeadIDcolumn{
	# relabel the user defined ID column (which can be just about anything) as 'ID column'
	my ($resthead, $id_col) = @_;
	my @resthead = split("\t",$resthead);
	for(my $i=0; $i<@resthead; $i++){	if($resthead[$i] eq $id_col){$resthead[$i] = "ID Column";}}
	return join("\t",@resthead);
}

sub addStandardInfoToHead{
	my ($variables, $head, $resthead)=@_;
	for(my $i=1;$i<=$NUM_REPLICATES{$variables->{'replicates'}};$i++){$head.="Normalized Colony Size $i\t";}
	#	for($i=1;$i<=$NUM_REPLICATES{$variables->{'replicates'}};$i++){
	#		$head.="Normalized comparer Colony Size $i\t";
	#	}
	if ($variables->{'circ_included'}){
		for(my $i=1;$i<=$NUM_REPLICATES{$variables->{'replicates'}};$i++){
			$head.="Colony Circularity $i\t";
		}
	}
	#	if ($variables->{'circ_included'}){
	#		for($i=1;$i<=$NUM_REPLICATES{$variables->{'replicates'}};$i++){
	#			$head.="comparer Colony Circularity $i\t";
	#		}
	#	}
	$resthead = &processRestHeadIDcolumn($resthead, $variables->{'id_col'});
	return $head."$resthead\n";
}

sub setupOutallAndAuxFileHandles{
	my ($variables,$date, $q) = @_;
	# open output files
	my ($out_all, $aux_info);
	eval{open( $out_all, ">$variables->{'save_directory'}/$date-ScreenMillStats-all.txt") || die "crap - ScreenMillStats-all.txt. $!";};
	if($@){&update_error ('There was an issue generating your output files.  '.&try_again_or_contact_admin(),$q); die "Problem creating ScreenMillStats-all.txt: $@";}
	eval{open( $aux_info, ">$variables->{'save_directory'}/$date-ScreenMillStats-auxiliary_information.txt") || die "crap -  ScreenMillStats-auxiliary_information.txt.\n";};
	if($@){&update_error ('There was an issue generating your output files.  '.&try_again_or_contact_admin(),$q); die "Problem creating aux info file: $@";}
	return ($out_all, $aux_info);
}

sub finishSettingUpOutputFiles{
	my ($out_all, $variables, $head, $date, $q) = @_;

	my ($sdl, $suppressor);
	eval{open($sdl, ">$variables->{'save_directory'}/$date-ScreenMillStats-positive-hits.txt") || die "crap - ScreenMillStats-positive-hits.txt.\n";};
	if($@){&update_error ('There was an issue generating your output files.  '.&try_again_or_contact_admin(),$q); die 'Problem creating ScreenMillStats-positive-hits.txt: $@';}
	eval{open($suppressor, ">$variables->{'save_directory'}/$date-ScreenMillStats-suppressors.txt") || die "crap - ScreenMillStats-suppressors.txt.\n";};
	if($@){&update_error ('There was an issue generating your output files.  '.&try_again_or_contact_admin(),$q); die 'Problem creating ScreenMillStats-suppressors.txt: $@';}

	$variables->{'id_col'} = (defined ($variables->{'id_col'})) ? $variables->{'id_col'} : 'n/a';
	my $ignore = ($variables->{'ignoreZeros'}) ? 'Yes' : 'No'; # were zeroes ignored when processing log file?
	$variables->{'statsMethod'} = ($variables->{'statsMethod'} eq 'Mann-Whitney') ? "Mann-Whitney" : $variables->{'statsMethod'};
	my $bonferroni = ($variables->{'bonferroni'}) ? "P-values have been Bonferroni corrected\n" : "";
	my $ref_control = $variables->{'control'}; # remove 0000_ tag used to present controls first
	$ref_control =~ s/^0000_//;
	print $out_all "\nStatistical Method Used: $variables->{'statsMethod'}\n$bonferroni"."Comparer: $ref_control\nID Column: $variables->{'id_col'}\n";
	print $out_all "Data Normalized to plate: $variables->{'normalization_method'}\nIgnore Zeroes?: $ignore";
	print $out_all "\nYellow Highlight cutoff value: $variables->{'death_threshold_cutoff'}\nNumber of Replicates: $variables->{'replicates'}\n";
	print $out_all "* = excluded\n^ = excluded on control\nA P-value / probability value of 0* is < 1.11e-16\n$head";
	print $sdl "\n Your ID Column = $variables->{'id_col'}\n\n$head";
	print $suppressor "\nYour ID Column = $variables->{'id_col'}\n\n$head";
	return ($sdl, $suppressor);

}

sub loadGOinfo{
	use Storable qw(retrieve); # the storable data persistence module
	my $variables = shift;
	# create 2 hashes
	# %go_cat_size is created in the update key files script and contains {key_file_name}->{GO_cat_name}->{plate #}->{row}[col]='yes'
	# %go_cat_size = hash of hashes.  {key_file} --> {GO category} --> {plate #} --> {row}[col]='yes'
	my $go_cat_info=undef;
	if($variables->{'id_col'} && $variables->{'id_col'} eq 'orf'){
		if(!defined($variables->{'go_dir'})){$variables->{'go_dir'}= "../../tools/temp/key_files";}
		$go_cat_info = eval{retrieve("$variables->{'go_dir'}/go_cats.go")};
		if($@){print "Could not determine GO enrichment.<br/>Serious issue with storable, try again or contact administrator.<br/>";$go_cat_info=undef;}
	}
	return $go_cat_info;
}

sub finalizeOutputs{
	my ($out_all, $sdl, $suppressor, $aux_info, $plate_summary, $control_plate_details, $variables, $head) = @_;
	close $out_all;
	close $sdl;
	close $suppressor;
	if($variables->{'normalization_method'} ne 'nothing'){$variables->{'normalization_method'}= "plate $variables->{'normalization_method'}";}
	print $aux_info "\nPLATE INFORMATION:\nPlate values normalize to $variables->{'normalization_method'}. Note that if plates were normalized to 'nothing' the normalization values below are the values data was normalized for display purposes only, they did not influence the statistics calculated.\nQuery\tCondition\tPlate #\tNormalization Value\tYellow highlight cutoff value\n$$plate_summary\n";
	$head = "\nCOMPARER PLATE DETAILS:\n* = excluded\n^ = excluded on control\nQuery\tCondition\tPlate #\tRow\tColumn\tAverage Normalized Size\t";
	for(my $i=1;$i<=$NUM_REPLICATES{$variables->{'replicates'}};$i++){
		$head.="Normalized Colony Size $i\t";
	}
	if ($variables->{'circ_included'}){
		for(my $i=1;$i<=$NUM_REPLICATES{$variables->{'replicates'}};$i++){
			$head.="Colony Circularity $i\t";
		}
	}
	print $aux_info	"$head\n$$control_plate_details\n";
	close $aux_info;

	# if($variables->{'store'}){
	# 	if($sqlite_info->{'sqlite_flag'}){$sqlite_info->{'sd_dh'}->finish;}
	# 	&commitDB($sqlite_info);
	# 	eval{$sqlite_info->{'dbh'}->disconnect();};
	# 	if($@){$sqlite_info->{'log_message'}.="Could not disconnect from database. $@\n";}
	# }
}

# Neven Krogan method to account for 'corn field' effect
sub normalizeOuterRowGrowth{
	use Statistics::Descriptive;
	my ($plateRef, $rc, $normalizationValue) = @_;
	my $density = $rc->{'rows'} * $rc->{'cols'};
	# normalize outer rows based on krogan method

	# first collect all the data for the outer ring of colonies
	# do first column
	my $stat = Statistics::Descriptive::Full->new();
	for(my $pos=1; $pos < ($rc->{'rows'}-1); $pos++){$stat->add_data($plateRef->[$pos]);}
	# do last column
	for(my $pos=($density-$rc->{'rows'}+1); $pos < ($density-1); $pos++){$stat->add_data($plateRef->[$pos]);}
	# do first row
	my $count=0;
	while($count < $rc->{'cols'}){
		my $pos = $count * $rc->{'rows'};
		$stat->add_data($plateRef->[$pos]);
		$count++;
	}
	# do last row
	$count=1;
	while($count <= $rc->{'cols'}){
		my $pos = $count * $rc->{'rows'} - 1;
		$stat->add_data($plateRef->[$pos]);
		$count++;
	}

	# calculate outer ring correction factor, apply it to data
	my $edgeCorrection = ($stat->median() > 0) ? ($normalizationValue / $stat->median()) : 1 ;
	# first column
	for(my $pos=1; $pos < ($rc->{'rows'}-1); $pos++){$plateRef->[$pos] *= $edgeCorrection;}
	# last column
	for(my $pos=($density-$rc->{'rows'}+1); $pos < ($density-1); $pos++){$plateRef->[$pos] *= $edgeCorrection;}
	# first row
	$count=0;
	while($count < $rc->{'cols'}){
		my $pos = $count * $rc->{'rows'};
		$plateRef->[$pos] *= $edgeCorrection;
		$count++;
	}
	# last row
	$count=1;
	while($count <= $rc->{'cols'}){
		my $pos = $count * $rc->{'rows'} - 1 ;
		$plateRef->[$pos] *= $edgeCorrection;
		$count++;
	}

	# collect all the data for the second to the outer most ring of colonies
	# do second column
	$stat = Statistics::Descriptive::Full->new();
	for(my $pos=($rc->{'rows'}+2); $pos < ($rc->{'rows'}*2-2); $pos++){$stat->add_data($plateRef->[$pos]);}
	# do second to last column
	for(my $pos=($density-($rc->{'rows'}*2)-2); $pos < ($density-$rc->{'rows'}-2); $pos++){
		$stat->add_data($plateRef->[$pos]);
	}
	# do second row
	$count=1;
	while($count < $rc->{'cols'}){
		my $pos = $count * $rc->{'rows'} + 1;
		$stat->add_data($plateRef->[$pos]);
		$count++;
	}
	# do second to last row
	$count=2;
	while($count < $rc->{'cols'}){
		my $pos = $count * $rc->{'rows'} - 2;
		$stat->add_data($plateRef->[$pos]);
		$count++;
	}

	# calculate second to the outer most ring correction factor, apply it to data
	$edgeCorrection = ($stat->median() > 0) ? ($normalizationValue / $stat->median()) : 1 ;

	# 2nd column
	for(my $pos=($rc->{'rows'}+2); $pos < ($rc->{'rows'}*2-2); $pos++){$plateRef->[$pos] *= $edgeCorrection;}
	# do second to last column
	for(my $pos=($density-($rc->{'rows'}*2)-2); $pos < ($density-$rc->{'rows'}-2); $pos++){
		$plateRef->[$pos] *= $edgeCorrection;
	}
	# 2nd row
	$count=1;
	while($count < $rc->{'cols'}){
		my $pos = $count * $rc->{'rows'} + 1 ;
		$plateRef->[$pos] *= $edgeCorrection;
		$count++;
	}
	# do second to last row
	$count=2;
	while($count < $rc->{'cols'}){
		my $pos = $count * $rc->{'rows'} - 2 ;
		$plateRef->[$pos] *= $edgeCorrection;
		$count++;
	}
}


sub prettyPrintNumber{
	my $number = shift;
	if(!defined $number){return 0;}
	$number = ($number < 0.001 || $number == 0) ? sprintf('%.2e',$number) : sprintf("%.3f",$number);
	return $number;
}

sub calculateTtest{
	use Statistics::Distributions qw(tprob);
	# data1 and data2 are references to an arrays that contains all the information
	# about two sets of data that we will need to perform the t-test
	my ($data1, $data2) = @_;
	# cannot perform t-test unless the n of both data sets is >= 2
	if($data1->[0]<2 || $data2->[0]<2){return (-1,'n/a - n too small');}
	elsif($data1->[3]==0 || $data2->[3]==0){return (-1,'n/a - cannot calculate, std. dev == 0');}
	# there are 4 data in each array, they correlate to:
	#	[# of samples, mean, standard deviation, variance ]
	#calculate t-values, degrees of freedom and p-values, store p-value in $plate{$plate}->{$query}->{$condition} (since it contains a ref to @ratio_data;)
	# calculate t-test for everything
	#warn $data1->[0] .", ". $data1->[1] .", ". $data1->[2] .", ". $data1->[3] ." ---> ". $data2->[0] .", ". $data2->[1] .", ". $data2->[2] .", ". $data2->[3];

	# add 0.0000001 to a bunch of values to prevent division by 0
	my $tvalue = abs($data1->[1]-$data2->[1]) /
						sqrt( ( $data1->[3]/$data1->[0]) +
									( $data2->[3]/$data2->[0])
								);
	my $df = int(
								(
									(  $data1->[3]/$data1->[0]  ) +
									(  $data2->[3]/$data2->[0]  )
							  )**2 /
								(
									(
										( $data1->[3] / $data1->[0]  )**2 /
											($data1->[0]-1)
									) +
									(
										( $data2->[3] / $data2->[0]  )**2 /
										($data2->[0]-1)
									)
								)
							);
	#warn "$tvalue, $df";
	my $pval=abs(2*&tprob($df, $tvalue)); # multiply by 2 since we are interested in SDLs and suppressors...
	return ($pval, $tvalue);
}

sub calculateOtherStatsAndOutput{
	my ($plateStats, $variables, $excludedData, $originalData, $keyinfo, $resthead,
		$plateSummary, $controlPlateDetails, $date, $q)=@_;
	# assume t-test
	my $statTestReference = \&calculateTtest;
	my $front = "\nQuery\tCondition\tPlate #\tRow\tColumn";
	my $end = "Normalized Growth Ratio (Comparer::Exp)\tGrowth Ratio (Comparer / Exp)\tLog Growth Ratio\t";

	# but if we want the mann whitney theeeeen
	if($variables->{'statsMethod'} eq 'Mann-Whitney'){
		# pvalue is already calculated, so just return it
		$statTestReference = sub{ return ($_[1]->[0], 'n/a'); };
		$front .= "\tMann-Whitney Probability";
	}
	else{$front.="\tT-test P-Value";}# t-test
	my $head= "$front\t$end";

	$head = &addStandardInfoToHead($variables, $head, $resthead);

	my ($out_all, $aux_info) = &setupOutallAndAuxFileHandles($variables, $date, $q);
	my ($sdl, $suppressor) = &finishSettingUpOutputFiles($out_all, $variables, $head, $date, $q);

	my $go_cat_info = &loadGOinfo($variables);
	my (%go_cat_size,%num_orfs_considered);

	# &prepSQLstatQuery($sqlite_info);

	my $fBlankMarker = ($variables->{'key_choice'} eq 'none') ? '' : 'blank-';
	my $eBlankMarker = ($variables->{'key_choice'} eq 'none') ? '' : '-blank';
	my  %sig_ORF_info;

	my @plateOrder;
	{
		no warnings 'numeric';
		@plateOrder = sort {$a cmp $b || $a <=> $b } keys %{$plateStats};
	}

	my $control = $variables->{'control'};
	$control=~ s/0000_//; # strip out 0000_ tag...

	foreach my $plate(@plateOrder){
		foreach my $query(sort keys %{ $plateStats->{$plate} }){
			foreach my $condition(sort keys %{ $plateStats->{$plate}->{$query} }){
				if ($query ne $control){
					my $plateLabel = $variables->{'originalData'}->{$plate}->{$query}->{$condition};
					&update_message("Crunching Stats - Analyzing $plate,$query,$condition", $q);
					# if performing t-test
					# data in $plateStats->{$plate}->{$query}->{$condition} is array of arrays -> each array contains an array that contains the following data:
					# index 0 number of replicates, 1 rep mean, 2 = rep standard_deviation, 3 = rep variance
					# else we are performing the mann-whitney test and the data is again in an array of arrays -> each array contains an array that contains the following data:
					# index 0 pval, 1 rep mean, 2 = rep standard_deviation, 3 = rep variance
					my $ePlateData=$plateStats->{$plate}->{$query}->{$condition};
					my $cPlateData=$plateStats->{$plate}->{$control}->{$condition};
					my $eOriginalSizes=$originalData->{$plate}->{$query}->{$condition}->[0]; # store raw experimental values saved above in the lexical reference $original_data
					my $cOriginalSizes=$originalData->{$plate}->{$control}->{$condition}->[0]; # store raw values saved above in the lexical reference $original_data
					my $eOriginalCircs=$originalData->{$plate}->{$query}->{$condition}->[1]; # store raw experimental circularities saved above in the lexical reference $original_data
					my $cOriginalCircs=$originalData->{$plate}->{$control}->{$condition}->[1]; # store raw control circularities saved above in the lexical reference $original_data
					my $dataSize=@$ePlateData; # number of data on this plate (should be same for all plates)
					my ($currentCol, $currentRow)=(1,0);

					for(my $i=1; $i<=$dataSize; $i++){
						if($i>=$variables->{'collapsedRows'} && $i%$variables->{'collapsedRows'}==1){$currentCol++; $currentRow=0;}

						my ($combo, $condition1);
						if(defined $condition && $condition ne ''){
							$combo = "$plateLabel->{'query'}-$plateLabel->{'condition'}";
							$condition1=$plateLabel->{'condition'};
						}
						else{
							$combo=$plateLabel->{'query'};
							$condition1 = '';
						}
						# generate output string
						my $dummy_orf = $keyinfo->{$plate}->{$alphabet[$currentRow]}[$currentCol];
						if($variables->{'key_choice'} eq 'none'){
							$keyinfo->{$plate}->{$alphabet[$currentRow]}[$currentCol] = '';
							$dummy_orf = 'YLR045C';
						}
						my $output_front= "$plateLabel->{'query'}\t$condition1\t[$plate]\t$alphabet[$currentRow]\t$currentCol\t";
						my $output_end = "\t$eOriginalSizes->[$i-1]\t";
						$output_end.="$eOriginalCircs->[$i-1]\t" if ($variables->{'circ_included'}); # $$c_original_circs[$i-1]\t
						$output_end.="$keyinfo->{$plate}->{$alphabet[$currentRow]}[$currentCol]\n";
						#print "$keyinfo->{$plate}->{$alphabet[$currentRow]}[$currentCol]<br/>";
						# prevent inclusion of blanks and deads...
						# NO LONGER WORRIED ABOUT DEADS OR COMPLETELY EXCLUDED STUFF WITH THIS TEST. PERFORM ALL CALCULATIONS AND THEN JUST MARK THE FINAL OUTPUT

						# control mean :: experimental mean
						my @ratio=();
						$ratio[0] = sprintf("%.2f",$cPlateData->[$i-1]->[1]).'::'.sprintf("%.2f",$ePlateData->[$i-1]->[1]);
						$ratio[1]=1; $ratio[2]=0;
						if(	$ePlateData->[$i-1]->[1] == 0){	$ratio[1]="n/a";	$ratio[2]="n/a";}
						else{
							$ratio[1]=sprintf("%.3f",($cPlateData->[$i-1]->[1] / $ePlateData->[$i-1]->[1]));
							if($cPlateData->[$i-1]->[1]==0){$ratio[2]="n/a";}
							else{$ratio[2]=sprintf("%.2f", log($cPlateData->[$i-1]->[1] / $ePlateData->[$i-1]->[1]));}
						}

						my $pval = 1; # assume data was excluded or 'dead' change this valid if we are dealing with good data
						my $printPval = 'n/a'; # this is the value we will actually print to output files
						my $tvalue = 'n/a';# assume data was excluded or 'dead' change this valid if we are dealing with good data
						my $output="";
						# mark excluded guys, do not calculate stats and do not consider for GO enrichment or output to SDL or suppressor file
						if (defined($excludedData->{"$plate,$query,$condition-".($i-1).""})){
							$ratio[0]='excluded-'.$ratio[0].'-excluded';
							$output="$output_front$printPval\t$ratio[0]\t$ratio[1]\t$ratio[2]$output_end";
						}
						# mark deads, do not calculate stats and do not consider for GO enrichment or output to SDL or suppressor file
						elsif($cPlateData->[$i-1]->[1] < $variables->{'death_threshold_cutoff'} && $ePlateData->[$i-1]->[1] < $variables->{'death_threshold_cutoff'}){
							$ratio[0]='dead-'.$ratio[0].'-dead';
							$output="$output_front$printPval\t$ratio[0]\t$ratio[1]\t$ratio[2]$output_end";
						}
						# mark blanks, calculate stats, but do not consider for GO enrichment or output to SDL or suppressor file
						elsif((!defined ($keyinfo->{$plate}->{$alphabet[$currentRow]}[$currentCol]) || $keyinfo->{$plate}->{$alphabet[$currentRow]}[$currentCol] eq "BLANK" || $dummy_orf eq "") ){
							$ratio[0] = $fBlankMarker.$ratio[0].$eBlankMarker;
							($pval, $tvalue) = $statTestReference->($cPlateData->[$i-1],$ePlateData->[$i-1]); # tvalue is n/a if performing Mann-Whitney
							if($pval < 0){
								$output=$output_front."n/a, perhaps too many replicates were excluded\t$ratio[0]\t$ratio[1]\t$ratio[2]$output_end";
								$pval = 2000; # set to something high so that this guy does not get marked as significant
							}
							else{
								if($variables->{'bonferroni'}){	$pval*=$variables->{'numData'}->{$query}->{$condition};	$pval = 1 if $pval >1;}
								$output="$output_front$pval\t$ratio[0]\t$ratio[1]\t$ratio[2]$output_end";
							}
						}
						else{
						# if not dead or excluded then...
							$num_orfs_considered{$query}->{$condition}++;
							# tvalue is n/a if performing Mann-Whitney
							($pval, $tvalue) = $statTestReference->($cPlateData->[$i-1],$ePlateData->[$i-1]);
							if($pval < 0){
								$output=$output_front."n/a, perhaps too many replicates were excluded\t$ratio[0]\t$ratio[1]\t$ratio[2]$output_end";
								$pval = 2000; # set to something high so that this guy does not get marked as significant
							}
							else{
								if($variables->{'bonferroni'}){	$pval*=$variables->{'numData'}->{$query}->{$condition};	$pval = 1 if $pval >1;}
								$output="$output_front$pval\t$ratio[0]\t$ratio[1]\t$ratio[2]$output_end";
							}
							# NOTE...NO SUPPORT FOR CUSTOM KEY FILES WITH GO INFO YET
							if($go_cat_info && $go_cat_info->{"$variables->{'key_file_name'}.tab"}->{$plate}->{$alphabet[$currentRow]}->{$currentCol}){
								foreach my $aspect(keys %{$go_cat_info->{"$variables->{'key_file_name'}.tab"}->{$plate}->{$alphabet[$currentRow]}->{$currentCol}}){
									foreach my $term(keys %{$go_cat_info->{"$variables->{'key_file_name'}.tab"}->{$plate}->{$alphabet[$currentRow]}->{$currentCol}->{$aspect}}){
										$go_cat_size{"$query-$condition"}->{$aspect}->{$term}++;
									}
								}
							}
							if($pval<=0.05){ # only include those below threshold
								if($dummy_orf =~ /[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c]/){
									$sig_ORF_info{$query}->{$condition}->{$&}=$output;
									# if the control plate mean is greater then the experimental plate mean, then output to sdl file
									if($cPlateData->[$i-1]->[1] >= $ePlateData->[$i-1]->[1]){print $sdl $output;}
									else{print $suppressor $output;}
								}
							}
						}

						# add to SQLite database
						# &pushStatsToDatabase($sqlite_info, $combo, $plate, $alphabet[$currentRow], $currentCol, $pval, $tvalue, "$ratio[0]\t$ratio[1]\t$ratio[2]", $eOriginalSizes->[$i-1]);

						print $out_all $output;
						$currentRow++;
					}
				}
			}
		}
	}
	my $enrichedGO = &printGOEnrichment($aux_info, $go_cat_info, \%sig_ORF_info, \%go_cat_size, \%num_orfs_considered, $head);
	&finalizeOutputs($out_all, $sdl, $suppressor, $aux_info, $plateSummary, $controlPlateDetails, $variables, $head);
	return($enrichedGO);
}

sub crunchNormalStatsAndOutput{
	use Statistics::Distributions qw(uprob);
	# use Modules::Statistics::Multtest qw(qvalue);
	my ($plateStats, $variables, $original_data, $keyinfo, $log_ratio_sum, $resthead, $plate_summary, $control_plate_details, $num_orfs_considered, $considered_ratios, $date, $q)=@_;
	my ( %go_cat_size, %sig_ORF_info, %stats);
			# %go_cat_size contains {query+conditon}->{GO_cat_name}->number of ORFs screened. this hash with therefore be the
			# number of "good guys" total for evaluating if the hits from a screen are enriched in a particular GO or not....

	# setup out_all and aux_info file handles
	my ($out_all, $aux_info) = &setupOutallAndAuxFileHandles($variables, $date, $q);
	if($variables->{'bonferroni'}){
		print $out_all "P-values have been Bonferroni corrected, therefore the significance thresholds have automatically been set to 0.05.\n";
		print $aux_info "Overall Screen Statistics:\nP-values have been Bonferroni corrected, therefore the significance thresholds have automatically been set to 0.05.\nQuery\tCondition\tAverage Log Ratio\tVariance\tStandard Deviation\tP-Value Cut-off For Significance\n";
	}
	else{
		print $out_all "Relevant P-Value Threshold that correlates to a 2:1 Comparer to Experimental log growth ratio:\n";
		print $aux_info "Overall Screen Statistics:\nQuery\tCondition\tAverage Log Ratio\tVariance\tStandard Deviation\tP-Value Cut-off For Significance (default = P-value that correlates to a 2:1 Comparer to Experimental log growth ratio)\n";
	}
	print $out_all "Query\tCondition\tP-Value Cut-off\n";

	# print out general screen stats to files
	foreach my $query(keys %{$num_orfs_considered}){
		foreach my $condition(keys %{$num_orfs_considered->{$query}}){
			if(! defined $log_ratio_sum->{$query}->{$condition} || $log_ratio_sum->{$query}->{$condition}==0){
				&update_error(("Error analyzing the data for the $query-$condition dataset.  This may be because the plate numbers in your log file do not match the plate numbers in the key file your selected.  One reason for this could be that you named your plates improperly.  Plate names should have the following format: \"query,plateNumber,condition.file_extension\".  If the plate names in your log file are not formatted in this manner you may edit them and attempt to run this analysis again.<br/>".&contact_admin()), $q);
				exit(0);
			}
			# in %stats, for each query - condition:
			# 0 index will hold standard deviation, 1 will be the variance, 2 will be the pvalue threshold, 3 will be the log ratio average...
			@{$stats{$query}->{$condition}} = &generateNormalStats($considered_ratios->{$query}->{$condition}, $log_ratio_sum->{$query}->{$condition}, $q);
			my $condition1 = (defined $condition && $condition ne '') ? $condition : '';
			if($variables->{'bonferroni'}){	$stats{$query}->{$condition}[2] = 0.05;}
			print $out_all "$query\t$condition1\t$stats{$query}->{$condition}[2]\n";
			print $aux_info "$query\t$condition1\t$stats{$query}->{$condition}[3]\t$stats{$query}->{$condition}[1]\t$stats{$query}->{$condition}[0]\t$stats{$query}->{$condition}[2]\n";
			#print "<br/>$query-$condition<br/>Average: $stats{$query}->{$condition}[3]<br/>Variance = $stats{$query}->{$condition}[1] <br/>Standard Deviation = $stats{$query}->{$condition}[0]<br/>P-Value Cut-off for significance = $stats{$query}->{$condition}[2]<br/>";
		}
	}

	my $head= "\nQuery\tCondition\tPlate #\tRow\tColumn\tP-Value\tZ-Score\tNormalized Growth Ratio (Comparer::Exp)\tGrowth Ratio (Comparer / Exp)\tLog Growth Ratio\t";
	$head = &addStandardInfoToHead($variables, $head, $resthead);

	my ($sdl, $suppressor) = &finishSettingUpOutputFiles($out_all, $variables, $head, $date, $q);

	my $go_cat_info = &loadGOinfo($variables);

	my $control = $variables->{'control'};
	$control=~ s/0000_//; # strip out 0000_ tag...
	{ # put this in bracket b/c we only want the no warnings to apply for this section
		no warnings 'numeric'; # turn off warnings about numbers (important for sort in next line)
		# sort numeric then by alpha ie 1,2,3,a,b,c
		my %pvalues = ();
		foreach my $plate(sort {$a cmp $b || $a <=> $b } keys %{$plateStats} ){
			foreach my $query(sort keys %{ $plateStats->{$plate} }){
				foreach my $condition(sort keys %{ $plateStats->{$plate}->{$query} }){
					if ($query ne $control){
						# my $experiment_id=undef;
						# if($variables->{'store'}){
						# 	$experiment_id = $variables->{'store_params'}->{'sql_vars'}->{'row_ids'}->{'experiments'}->{$query}->{$condition};
						# 	if(defined $experiment_id){
						# 		# $variables->{'screen_results_sql_sub'} = \&mysql_insert_screen_results;
						# 	}
						# 	else{	$variables->{'screen_results_sql_sub'} = sub{ return 0;};  }
						# }

						my $plateLabel = $variables->{'originalData'}->{$plate}->{$query}->{$condition};
						&update_message("Crunching Stats - Analyzing $plate, $plateLabel->{'query'}, $plateLabel->{'condition'}", $q);
						my $ratio_data=$plateStats->{$plate}->{$query}->{$condition}[0]; # growth ratio and log growth ratio data
						my $actualR_data=$plateStats->{$plate}->{$query}->{$condition}[1]; # growth ratio data formatted in control::experimental
						my $original_sizes=$original_data->{$plate}->{$query}->{$condition}->[0]; # store raw data saved above in the lexical reference $original_data
						my $c_original_sizes=$original_data->{$plate}->{$control}->{$condition}->[0]; # store raw data saved above in the lexical reference $original_data
						my $original_circs=$original_data->{$plate}->{$query}->{$condition}->[1];
						my $c_original_circs=$original_data->{$plate}->{$control}->{$condition}->[1];
						my ($current_col, $current_row)=(1,0);
						#calculate z-scores and p-values, store p-value in $plate{$plate}->{$query}->{$condition} (since it contains a ref to @ratio_data;)
						for(my $i=1; $i<=scalar(@$ratio_data); $i++){
							if($i>=$variables->{'collapsedRows'} && $i%$variables->{'collapsedRows'}==1){$current_col++; $current_row=0;}

							my ($pval,$zscore)=("n/a","n/a");
							my ($combo, $condition1);
							if(defined $condition && $condition ne ''){
								$combo = "$plateLabel->{'query'}-$plateLabel->{'condition'}";
								$condition1=$plateLabel->{'condition'};
							}
							else{
								$combo="$plateLabel->{'query'}";
								$condition1 = '';
							}
							# generate output string
							# check if keyinfo is defined, it may not be if this is a custom key file or if $variables->{'key_choice'} eq 'none'
							if(!defined $keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col]){
								$keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col] = '';
							}


							my $output;
							my $output_front= "$plateLabel->{'query'}\t$condition1\t[$plate]\t$alphabet[$current_row]\t$current_col\t";
							my $output_end="\t$actualR_data->[$i-1]\t" .sprintf("%.2f",$ratio_data->[$i-1]->[0]). "\t" .sprintf("%.5f",$ratio_data->[$i-1]->[1]). "\t$original_sizes->[$i-1]\t"; #$$c_original_sizes[$i-1]\t";
							$output_end.="$original_circs->[$i-1]\t" if ($variables->{'circ_included'}); # $$c_original_circs[$i-1]\t
							$output_end.="$keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col]\n";

							# my @screen_result = (
							# 	$experiment_id,
							# 	$plate,
							# 	$alphabet[$current_row],
							# 	$current_col,
							# 	$pval,
							# 	$zscore,
							# 	$ratio_data->[$i-1]->[0],
							# 	$keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col],
							# 	$colony_sizes_considered->count(),
							# 	$colony_sizes_considered->mean(),
							# 	$colony_circularities_considered->mean(),
							# 	$colony_circularities_considered->variance(),
							# 	$controlData{$plate}->{$condition}->{$current_row}->{$current_col}->mean()
							# );

							# prevent inclusion of blanks and deads...
							if(($keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col] ne "BLANK" || $keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col] ne "")){
								if($actualR_data->[$i-1]=~ /de/){
									# dead colony
									$output="$output_front$pval\t$zscore$output_end";
								}
								if($actualR_data->[$i-1]!~/ex/){ # look for exclusion
									# good colony
									if($go_cat_info && $go_cat_info->{"$variables->{'key_file_name'}.tab"}->{$plate}->{$alphabet[$current_row]}->{$current_col}){
										foreach my $aspect(keys %{$go_cat_info->{"$variables->{'key_file_name'}.tab"}->{$plate}->{$alphabet[$current_row]}->{$current_col}}){
											foreach my $term(keys %{$go_cat_info->{"$variables->{'key_file_name'}.tab"}->{$plate}->{$alphabet[$current_row]}->{$current_col}->{$aspect}}){
												$go_cat_size{"$query-$condition"}->{$aspect}->{$term}++;
											}
										}
									}
									# calculate z-score ([value - average] / std_dev)
									$zscore=($$ratio_data[$i-1]->[1]-$stats{$query}->{$condition}[3])/$stats{$query}->{$condition}[0];
									$pval=2*uprob(abs($zscore)); # use z-score to calculate p-value, multiply by 2 since we are interested in SDLs and suppressors...

									# push(@{$pvalues{"$query,$condition"}->[0]},$pval);

									if($variables->{'bonferroni'}){	$pval*=$variables->{'numData'}->{$query}->{$condition}; if($pval>1){$pval=1;}	}
									$zscore=sprintf("%.5f",$zscore);
									$output="$output_front$pval\t$zscore$output_end";
									if($pval<=$stats{$query}->{$condition}[2]){ # only include those below threshold that have not been excluded..
										if($keyinfo->{$plate}->{$alphabet[$current_row]}[$current_col] =~ /[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c]/ || $variables->{'key_choice'} eq 'none'){
											$sig_ORF_info{$query}->{$condition}->{$&}=$output;
											if($zscore>0){print $sdl $output;}
											else{print $suppressor $output;}
										}
									}
								}
								else{
									# excluded
									$output="$output_front$pval\t$zscore$output_end";
								}
							}
							else{
								# blank
								$output="$output_front$pval\t$zscore$output_end";
							}

							# add to SQLite database
							# &pushStatsToDatabase($sqlite_info, $combo, $plate, $alphabet[$current_row], $current_col, $pval, $zscore, $actualR_data->[$i-1], $original_sizes->[$i-1]);

							print $out_all $output;
							$current_row++;
						}

						# warn Dumper &Statistics::Multtest::qvalue(\@pvalues);
					}
				}
			}
		}
		# foreach my $queryCondition(keys %pvalues){
			# $pvalues{$queryCondition}->[1] = &Statistics::Multtest::qvalue($pvalues{$queryCondition}->[0]);
		# }
	}
	my $enrichedGO = &printGOEnrichment($aux_info, $go_cat_info, \%sig_ORF_info, \%go_cat_size, $num_orfs_considered, $head);

	&finalizeOutputs($out_all, $sdl, $suppressor, $aux_info, $plate_summary, $control_plate_details, $variables, $head);

	return(\%stats,$enrichedGO);
}

sub printGOEnrichment{
	use Statistics::Hypergeometric qw(cum_hyperg_pval_info); # customized
	my ($aux_info, $go_flag, $sig_ORF_info, $go_cat_size, $num_orfs_considered, $head) = @_;
	#warn Dumper($go_cat_size);
	my %go_term_index;
	$go_term_index{'P'} = &indexArray('go biological process', (split /\t/, "\L$head"));
	$go_term_index{'F'} = &indexArray('go molecular function', (split /\t/, "\L$head"));
	$go_term_index{'C'} = &indexArray('go cellular component', (split /\t/, "\L$head"));

	my $enrichedGO='';
	if($go_flag){
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
		# gene_count = number of hits for a particular gene-condition combination
		# total_count = total number of hits in entire experiment...
		print $aux_info "\n\nGO Enrichment Details:\n";
		print $aux_info "Query\tCondition\tGO Aspect\tGO Term\tP-Value\tUnder/Over Represented\tScreened ORF(s) in Term\n";
		my (%go_cats_in_hits_per_gene,%gene_count, %orfs_in_cat);
		foreach my $gene(keys %{$sig_ORF_info}){
			foreach my $condition(keys %{$sig_ORF_info->{$gene}}){
				foreach my $orf(keys %{ $sig_ORF_info->{$gene}->{$condition} }){
					#my @temp= split( /\t/,$sig_ORF_info->{$gene}->{$condition}->{$orf});
					$gene_count{$gene}->{$condition}++;
					foreach my $aspect(keys %go_term_index){
						# warn "->$gene, $condition, $orf --> $aspect -> $go_term_index{$aspect}  --> $sig_ORF_info->{$gene}->{$condition}->{$orf} \n";
						$sig_ORF_info->{$gene}->{$condition}->{$orf} =~ s/"+//g; # strip quotes
						if($sig_ORF_info->{$gene}->{$condition}->{$orf}){
							my @temp = (split /\t/,$sig_ORF_info->{$gene}->{$condition}->{$orf});
							# warn scalar(@temp). "--> $temp[$go_term_index{$aspect}]\n";
							# print "<br/>";
							#warn $temp[$go_term_index{$aspect}];
							if($temp[$go_term_index{$aspect}]){
								foreach my $cat(split /, /, $temp[$go_term_index{$aspect}]){
									# print Dumper($orfs_in_cat{$aspect}->{$gene}->{$condition}->{$cat});
									# print "<br/>";
									push(@{$orfs_in_cat{$aspect}->{$gene}->{$condition}->{$cat}}, $orf);
									$go_cats_in_hits_per_gene{$aspect}->{$gene}->{$condition}->{$cat}++;
									# print $go_cats_in_hits_per_gene{$aspect}->{$gene}->{$condition}->{$cat};
									# print "<br/>";
								}
							}
						}
					}
				}
			}
			# warn "\n\n\n\n\n\n$gene";
			# warn Dumper(\%go_cats_in_hits_per_gene);
			# warn "\n\n";
			# warn Dumper(\%orfs_in_cat);
			my %hits;
			foreach my $aspect(keys %go_cats_in_hits_per_gene){
				foreach my $query(keys %{$go_cats_in_hits_per_gene{$aspect}}){
					foreach my $condition(keys %{$go_cats_in_hits_per_gene{$aspect}->{$query}}){
						my $minSig = 0.05 / $gene_count{$query}->{$condition};
						foreach my $cat(keys %{$go_cats_in_hits_per_gene{$aspect}->{$query}->{$condition}}){
							# print "cat=$cat, query = $query-$condition,  $aspect, ",$go_cat_size->{"$query-$condition"}->{$aspect}->{$cat} ,"<br/>";
							if($go_cat_size->{"$query-$condition"}->{$aspect}->{$cat} && $go_cats_in_hits_per_gene{$aspect}->{$query}->{$condition}->{$cat} && $gene_count{$query}->{$condition} && $num_orfs_considered->{$query}->{$condition}){
								my ($HD_pval, $resultStr) = &cum_hyperg_pval_info($go_cats_in_hits_per_gene{$aspect}->{$query}->{$condition}->{$cat}, $go_cat_size->{"$query-$condition"}->{$aspect}->{$cat}, $gene_count{$query}->{$condition}, $num_orfs_considered->{$query}->{$condition});
								if($HD_pval<$minSig){
									$HD_pval = &prettyPrintNumber($HD_pval);
									my $condition1 = (defined $condition && $condition ne '') ? $condition : '';
									my @resultStr = split(/:/,$resultStr);
									push(@{$hits{"$query\t$condition1"}->{"$HD_pval"}},"$query\t$condition1\t$aspect\t$cat\t$HD_pval\t$resultStr[0]\t".join("\t",@{$orfs_in_cat{$aspect}->{$query}->{$condition}->{$cat}}));
								}
							}
						}
					}
				}
			}
			# sort results, print to file
			# warn Dumper (\%hits);
			foreach my $gene(sort {$a cmp $b} keys %hits){
				foreach my $pval(sort {$a<=>$b} keys %{$hits{$gene}}){
					foreach my $desc(@{$hits{$gene}->{$pval}}){
						print $aux_info "$desc\n";
						my @data = split("\t",$desc);
						$enrichedGO.= "<tr><td>$data[0]</td><td>$data[1]</td><td>$data[4]</td><td>$data[2]</td><td>$data[3]</td><td>$data[5]</td></tr>";
					}
				}
			}
		}
		if($enrichedGO ne ''){ $enrichedGO="<table class='borders'><tr><th>Query</th><th>Condition</th><th>P-Value</th><th>Aspect</th><th>GO Term</th><th>Under or Over Represented</th></tr>$enrichedGO</table>";}
	}
	else{$enrichedGO="<table class='borders'><tr><th>NO GO enrichment analysis performed.</th></tr></table>";}
	return $enrichedGO;
}

# Commits changes to database
# takes a reference to a hash that contains database parameters, assumes that 'sqlite_flag' is true if
# everything has worked up to this point.  Also assumes that the database handle is 'dbh'
sub commitDB{
	my $db_info=shift;
	if($db_info->{'sqlite_flag'}){
		eval{$db_info->{'dbh'}->commit();};
		if($@){$db_info->{'log_message'}.="Could not commit changes...rolling back. $@\n";	&rollback_now($db_info);}
	}
}

# if error occurs rollsback all changes to database (ie restores database to the state it was in before this program was run)
# takes a reference to a hash that contains database parameters, assumes that the database handle is 'dbh'
sub rollback_now{
	my $db_info=shift;
	eval{$db_info->{'dbh'}->rollback();};
	if($@){$db_info->{'log_message'}.="Commit failed and was unable to rollback changes, everything has gone to shit. $@\n"; }
}

# take an array and an item to find in array, will return index number of item if it is found...
# uses pop therefore works best when looking for items at end of arrays
sub indexArray(@){
	1 while $_[0] ne pop;
	$#_;
}

# deletes directory fed to it, as well as all files within it
sub deleteSession{
	my $file;
	my $dir = shift;
	opendir (DH,"$dir");
	while ($file = readdir DH) {	unlink "$dir/$file";	}
	rmdir("$dir");
}

# this is an SV engine function
sub checkSelectedSets{
	my ($variables, $q, $acs, $dinfo, $mode, %added)=@_;
	use Storable qw(store retrieve);
	my(%ss, @p, $sets, $selected,$plate);

	if( -e "$variables->{'save_directory'}/selected_sets.dat"){
		%ss = eval{%{retrieve("$variables->{'save_directory'}/selected_sets.dat")}};
		if($@){
			&update_error ('There was an issue generating your output file. '.&try_again_or_contact_admin(),$q, 'one_extra');
			die "Serious error from Storable with selected_sets.dat: $@";
		}
	}
	if(defined $q->param("selected_sets")){
		foreach(split/~~>/, $q->param("selected_sets")){
			@p = split/~/; # 0 = plate, 1 = query, 2 = condition, 3 = position
			if(@p){
				$p[2] = ($p[2] =~/^-$/) ? '' : lc($p[2]);
				$p[1] = lc($p[1]);
				if($p[3]=~/(^[a-zA-Z]{1,2})(\d{1,2}$)/ &&  # checks that position is one or 2 word characters followed by 1 or 2 number chars, stores them into $1 and $2, respectively
						$acs->{$p[0]}->{$p[1]}->{$p[2]}){ # checks that plate,query,condition combo is valid
					if(! defined $ss{$p[0]}->{$p[1]}->{$p[2]}->{$p[3]}){
						$ss{$p[0]}->{$p[1]}->{$p[2]}->{$p[3]}=$dinfo->{$p[0]}->{$p[1]}->{$p[2]}->{$1}[$2];
					}
					$added{$p[0]}->{$p[1]}->{$p[2]}->{$p[3]}=1;
				}
			}
		}

		# check if any items need to be removed from %ss.  Grep out all the selected sets from the current_plates and see if they exist in the %added hash
		# if they do then we are in business, otherwise delete it from the hash %ss
		foreach my $plateInfo(@{$variables->{'plates_on_page'}->[$variables->{'from_page'}]}){
			my $plate = $plateInfo->{'plateNum'};
			my $query = $plateInfo->{'query'};
			my $condition = $plateInfo->{'condition'};
			foreach my $selected(keys %{$ss{$plate}->{$query}->{$condition}}){
				# warn "selected = $plate,$query,$condition --> $selected\n";
				if(! defined $added{$plate}->{$query}->{$condition}->{$selected}){
					delete $ss{$plate}->{$query}->{$condition}->{$selected};
					# warn "$plate,$query,$condition --> $selected --> deleted!\n";
				}
			}
		}
		eval{store(\%ss, "$variables->{'save_directory'}/selected_sets.dat")};
		if($@){
			&update_error ('There was an issue storing your selected sets.  '.&try_again_or_contact_admin(),$q, 'one_extra');
			die "Serious error from Storable storing selected_sets.dat: $@";
		}
	}
	if($mode eq 'all'){return \%ss;}
	elsif($mode eq 'out'){
		$dinfo= eval{retrieve("$variables->{'save_directory'}/out_all.dat")}; # out_all.dat contains ALLLLLLLLL data from original ScreenMillStats-all.txt data file
		if($@){
			&update_error('There was an issue retrieving your temporary data.  '.&try_again_or_contact_admin(),$q, 'one_extra');
			die "Serious error from Storable storing selected_sets.dat: $@";
		}
		my($i,$j,@output);
		#my @headers = ("Plate #", "Query","Condition", "Position", "ORF", "query", "P-Value", "Z-Score", "Normalized Ratio (Comparer::Experimental)",
		#								"Calculated Log Ratio (Comparer vs. Experimental)", "Original Exp. Colony Sizes", "Description", "Go Terms", "GO Feature Type", "Other Information");
		my $headers=$dinfo->{"header"};

		my $workbook = Spreadsheet::WriteExcel->new("$variables->{'save_directory'}/SV-EngineResults.xls");
		my $sheet1 = $workbook->add_worksheet("hits");
		my $header_index= -1;
		$sheet1->activate();
		$j=0;

		my $norm_format=$workbook->add_format();
		my $syn_growth_defect_format=$workbook->add_format();
			 $syn_growth_defect_format->set_bg_color(44); # light blue
		my $suppress_format=$workbook->add_format();
		   $suppress_format->set_bg_color(43); # light yellow

		my $syn_growth_defect_formath=$workbook->add_format();
			 $syn_growth_defect_formath->set_bg_color(44); # light blue
			 $syn_growth_defect_formath->set_bold();
			 $syn_growth_defect_formath->set_size(12);
		my $suppress_formath=$workbook->add_format();
			 $suppress_formath->set_bold();
			 $suppress_formath->set_bg_color(43); # light yellow
			 $suppress_formath->set_size(12);

		my $greaterThan=1;
		for($i=0; $i<=$#{$headers}; $i++){
			if("\L$headers->[$i]" eq 'ratio' || "\L$headers->[$i]" eq 'growth ratio (comparer / exp)'){
				$header_index=$i;
				$greaterThan = 1;
				$i=$#{$headers}+1;
			}
			elsif("\L$headers->[$i]" eq 'z-score' || "\L$headers->[$i]" eq 'log growth ratio' || "\L$headers->[$i]" eq 'calculated log ratio (comparer::exp)'){
				$header_index=$i;
				$greaterThan = 0;
				$i=$#{$headers}+1;
			}
		}

		if($header_index >= 0){
			$sheet1->write(0, 0, "Synthetic Growth Defects", $syn_growth_defect_formath);
			$sheet1->write_blank(0, 1,                            $syn_growth_defect_formath);
			$sheet1->write_blank(0, 2,                            $syn_growth_defect_formath);
			$sheet1->write(1, 0, "Suppressors", $suppress_formath);
			$sheet1->write_blank(1, 1,                            $suppress_formath);
			$sheet1->write_blank(1, 2,                            $suppress_formath);
			$j=3;
		}

		my $format = $workbook->add_format();
		        $format->set_bold();
		        $format->set_size(12);
		        $format->set_align('center');
		for($i=0; $i<=$#{$headers}; $i++){$sheet1->write($j, $i, "$headers->[$i]", $format);}
		$j++;

		my $count = 0;
		foreach my $plate(keys %ss){
			foreach my $query(keys %{$ss{$plate}}){
				foreach my $condition(keys %{$ss{$plate}->{$query}}){
					foreach my $selected(keys %{$ss{$plate}->{$query}->{$condition}}){
						$selected=~/(^[a-zA-Z]{1,2})(\d{1,2}$)/; # capture the row and column positions
						$count++;
						@output = @{$dinfo->{$plate}->{$query}->{$condition}->{$1}[$2]};

						$format = $norm_format;
						if($header_index >= 0){
							if(&is_numeric($output[$header_index]) && $output[$header_index] > $greaterThan){$format=$syn_growth_defect_format;}
							else{$format=$suppress_format;}
						}
						for($i=0; $i<=$#output; $i++){$sheet1->write($j, $i, "$output[$i]",$format);}
						$j++;
					}
				}
			}
		}
		$workbook->close();
		if($count > 0){
			my @temp = split("/",$variables->{'save_directory'});
			&update_done("<center><a href=\"/$RELATIVE_ROOT/screen_mill/download/$temp[$#temp]?f=SV-EngineResults.xls\">Click here to download your selected sets</a></center>", "Finished generating Excel file!", $q, 'one_extra');
		}
		else{
			if(-e "$variables->{'save_directory'}/SV-EngineResults.xls"){	unlink "$variables->{'save_directory'}/SV-EngineResults.xls";	}
			&update_error('<div>You have not selected any data to download.<br/>'.&try_again_or_contact_admin(),$q, 'one_extra');
		}
		return 1;
	}
	return 0;
}

sub generateNormalStats{
	use Statistics::Distributions qw(uprob);
	my ($values, $sum, $q) = @_;
	my($average,$var,$std_dev, $i, $pthresh);
	$average=$sum/@{$values};
	$var=0;
	for(my $i=0; $i<@{$values}; $i++){$var+=($values->[$i]-$average)**2;}
	$var=$var/($#{$values});
	if($var<=0){
		$i = "ERROR!!!<br/>The calculated variance is less then or equal to 0.<br/>This is impossible assuming everything calculated beforehand worked.<br/>Program terminated.<br/>".&contact_admin();
		&update_error($i, $q);
		exit;
		#die "Calculated standard deviation == 0.  Impossible";
	}
	$std_dev=&prettyPrintNumber(sqrt($var));
	# calculate p-value threshold based on a log ratio of 2:1
	# log(2) = 0.693147180559945 = natural log ratio corresponding to twice as much growth in comparer strain as compared to comparer
	# ((0.693147180559945-averave)/std_dev) = Z-score of this ratio for this data set
	$pthresh=&prettyPrintNumber((2*uprob(abs((0.693147180559945-$average)/$std_dev))));
	# warn "$std_dev, $var, $pthresh, $average";
	# exit;
	return($std_dev, $var, $pthresh, $average);
}

sub validateKeyChoice{
	my($q, $variables)=@_;
	if(! defined $DENSITY_REPLICATES{$variables->{'key_choice'}}){
		&update_error("Invalid key choice entered. Key choice entered = $variables->{'key_choice'}.<br/>".&contact_admin(), $q);
		exit;
		#die "Invalid key choice entered. Key choice entered = $variables->{'key_choice'}. $!\n";
	}
	elsif($variables->{'key_choice'} eq 'custom' || $variables->{'key_choice'} eq 'none'){  # if no OR custom key file then...
		# # verify # replicates entered
		my $reps =$q->param("replicates");
		if(!$NUM_REPLICATES{$reps}){
			&update_error("Invalid replicate choice entered. Replicate choice entered = $reps.<br/>".&contact_admin(), $q);
			exit;
			#die "Invalid replicate choice entered. Replicate choice entered = $reps. $!\n";
		}
		else{$DENSITY_REPLICATES{$variables->{'key_choice'}}[1]="$reps";$variables->{'c_replicates'}=$reps;$variables->{'replicates'}=$reps;}
		my $density=$q->param("density");
		if(!$POSSIBLE_DENSITIES{$density}){
			&update_error("Invalid density choice entered. Density choice entered = $density.<br/>".&contact_admin(), $q);
			exit;
			#die "Invalid density choice entered. density choice entered = $density. $!\n";
		}
		else{$DENSITY_REPLICATES{$variables->{'key_choice'}}[0]="$density";$variables->{'c_density'}=$density;$variables->{'density'}=$density;}
		if($variables->{'key_choice'} eq 'none'){my %keyInfo; return (\%keyInfo,'');}
		return &setupKeyFile($variables, $q); # send file handle, user dir, and $q to function.
	}
	else{
		$variables->{'id_col'}='orf';
		$variables->{'key_file_name'}=$DENSITY_REPLICATES{$variables->{'key_choice'}}[2];
		my $keyinfo = eval{retrieve("$variables->{'key_dir'}/$variables->{'key_file_name'}.dat")};
		if($@ || !$keyinfo){
			#&update_error ('There was an issue retrieving your data, try again or contact administrator.',$q);
			#warn "Could not retrieve stored key data structure from $variables->{'key_dir'}/"."$variables->{'key_file_name'}.dat:: $!. Will try to create .dat file";
			return &setupKeyFile($variables, $q);
		}
		return ($keyinfo, '');
	}
}

sub saveDRprogress{
	use Storable qw(store retrieve); # the storable data persistence module
	my ($variables, $dynamicVariables, $plateData, $normalization_values, $queries, $q) = @_;
	&setupDynamicVariables($normalization_values, $dynamicVariables, $q, $variables);
	delete($dynamicVariables->{'starting'}) if defined $dynamicVariables->{'starting'};
	#*************** start storing data structures in $variables->{'save_directory'} ********************
	my $frozen=eval {store($variables, "$variables->{'save_directory'}/variables.dat")};
	if($@){ warn 'Serious error from Storable, storing %variables: '.$@.'<br/>';}
	$frozen=eval {store($plateData, "$variables->{'save_directory'}/plate_data.dat")};
	if($@){ warn 'Serious error from Storable, storing %plateData: '.$@.'<br/>';}
	$frozen=eval {store($normalization_values, "$variables->{'save_directory'}/normalization_values.dat")};
	if($@){ warn 'Serious error from Storable, storing %normalization_values: '.$@.'<br/>';}
	$frozen=eval {store($queries, "$variables->{'save_directory'}/queries.dat")};
	if($@){ warn 'Serious error from Storable, storing @queries: '.$@.'<br/>';}
	$frozen=eval {store($dynamicVariables, "$variables->{'save_directory'}/dynamicVariables.dat")};
	if($@){ warn 'Serious error from Storable, storing %dynamicVariables: '.$@.'<br/>';}
	#*************** end storing data structures in $variables{'save_directory'} ********************
	return 1;
}


sub setSession{
	use CGI::Session;
	use CGI::Session::MySQL;
	my($c_name, $v, $q, $displayFlash)=@_;
	$displayFlash = 1 if (! defined $displayFlash);
	my $user_directory = $v->{'save_directory'};
	my ($log, $session, $sid,$dbh)=(undef,undef,undef,undef);
	# If you want to store the session data in other table than "sessions", before creating the session object you need to set the special variable $CGI::Session::MySQL::TABLE_NAME to the name of the table:
	# $CGI::Session::MySQL::TABLE_NAME = 'my_sessions';
	# make connection to database
	$dbh = &connectToMySQL($q);
	if(! defined($dbh) ){
		if($displayFlash){
			&update_error("Error setting user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
			die "Could connect to database $! Could not connect to mysql database.  $DBI::errstr";
		}
		else{
			warn "Could connect to database $! Could not connect to mysql database.  $DBI::errstr";
			return 0;
		}
	}
	# warn Dumper($q);
	# warn "\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n\n";
	# 1st param = data source name (DSN) / driver
	# The second argument is session id to be initialized.
	# If it's undef, it will force CGI::Session to create a new session.
	# Instead of passing a session id, you can also pass a CGI.pm object, or any other object that can implement either of cookie()
	# or param() methods. In this case, the library will try to retrieve the session id from either CGISESSID cookie or
	# CGISESSID CGI parameter (query string)
	#
	# set session
	my $oc_name=$c_name;
	$c_name=~ s/_setup//;
	CGI::Session->name($c_name);
	# warn $c_name;
	$sid = $q->cookie($c_name) || undef;
	# warn $sid;
	eval{$session = new CGI::Session("driver:MySQL", $sid, {Handle => $dbh});};
	if($@){
		if($displayFlash){
			&update_error("Error setting user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
			die "Initialize Session.  $CGI::Session->errstr";
		}
		else{
			# warn "Initialize Session error.  $CGI::Session->errstr";
			return 0;
		}
	}
	# if sid is defined then the cookie already exists, retrieve user_dir. Else, store user_directory
	if($sid && $sid ne $session->id && $oc_name=~/_setup/){
		# delete everything in user_direcory
		warn "Deleting directory contents... $session->id --> $oc_name\n";
	}
	else{
		eval {
			# warn "Creating new cookie!!!!  --> $c_name --> ",$session->id;
			$session->param("user_directory", $user_directory) if $user_directory;
			$session->param(-name, $c_name);
			$session->name($c_name);
			# warn "done";
			#	warn "$session->header();";
			#	my $cookie = new CGI::Cookie(-name=>$c_name, -value=>$session->id, );
			#	$cookie->bake;
			#print $q->header(-cookie=>$cookie);
		};
		if($@) {
			if($displayFlash){
				&update_error("Error setting user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
				die "Initialize Session #2.  $CGI::Session->errstr";
			}
			else{	return 0;		}
		}
	}
	if(! defined $session->param("user_directory")){
		$session->param("user_directory", $user_directory) if $user_directory;
		$session->param(-name, $c_name);
		$session->name($c_name);
	}

	# use Data::Dumper;
	# warn Dumper($v);
	# warn Dumper($session);
	my ($id, $guy);
	if(defined $session->param("user_directory")){
		$guy = $session->param("user_directory");
		$id = $guy;
		$id =~ s/$v->{'base_upload_dir'}\///ig;
		my @temp = split(/\//, $id);
		$id = $temp[0];
	}
	if(! defined $id || $id != $v->{'user'}){
		use Data::Dumper;
	  warn Dumper $session;
	  warn Dumper $v;
	  warn "id = $id, user = $v->{'user'}";
	  warn "session timeout";

		$session->clear;
		$session->delete();
		my $cookie = $q->cookie ('login');
		my $ck = new CGI::Cookie(-name=>'login',-value=>'',-expires => '-1d');
	  print $q->header(-cookie=>$ck);
		&jsRedirect("Error setting user session or your session as timed out. Redirecting to login page. ", $q);
	}
	$q->{'.header_printed'}=1;
	print $session->header();

	$session->close();
	return $guy;
}

# validate user data...
# user_id and a super secret alpha numeric value are stored in a cookie on the users computer, these are also stored in a table in the database called perl bridge
# make sure these match up to validate user...
sub validateUser{
	use DBI;
	my ($variables, $q, $displayFlash) = @_;
	$displayFlash = 1 if (! defined $displayFlash);

	my @cookies = $q->cookie();
	if(!defined $q->cookie('auth_token') ){
		if($displayFlash){
			&update_error('There was an error with validating your login credentials. Please logout of the website and then try again.', $q);
		}
		else{
			if(!$q->{'.header_printed'}){	print $q->header();}
			print "500 error";
		}
		warn "auth_token cookie not defined!";
		return 0;
	}
	my $theCookie = $q->cookie('auth_token');# retrieve cookie
	my ($dbh, $exist_check);
	$dbh = &connectToMySQL();
	# validate that cookie values match those in db...
	if(! defined($dbh) ){
		if($displayFlash){
			&update_error("Error setting user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
		}
		else{
			if(!$q->{'.header_printed'}){	print $q->header();}
			print "500 error";
		}
		warn "Could connect to database $! Could not connect to mysql database.  $DBI::errstr";
		return 0;
	}
	eval{
		my @sql_values = ($theCookie);
		$exist_check = $dbh->selectall_arrayref(<<SQL, undef, @sql_values);
		SELECT * FROM `users` WHERE auth_token = ?
SQL
	};
	if($@ || !@$exist_check){
		&update_error('There was an error with validating your login credentials. Please logout of the website and then try again.', $q);
		my $user = $variables->{'user'} ? $variables->{'user'} : '';
		my $ss = $variables->{'super_secret'} ? $variables->{'super_secret'} : '';
		warn "User error (id = $variables->{'user'}, super secret = $ss, token = $theCookie): $! -- $@";
		return 0;
	}
	elsif(@{$exist_check} > 1){
		if($displayFlash){
			&update_error('There was an error with validating your login credentials. Please logout of the website and then try again.', $q);
		}
		else{
			if(!$q->{'.header_printed'}){	print $q->header();}
			print "500 error";
		}
		my $user = $variables->{'user'} ? $variables->{'user'} : '';
		my $ss = $variables->{'super_secret'} ? $variables->{'super_secret'} : '';
		warn "User error - too many? (id = $variables->{'user'}, super secret = $ss, token = $theCookie): $! -- $@";
		warn Dumper $exist_check;
		return 0;
	}
	# if it has already been saved, validate that user id matches previously stored user id...
	if($variables->{'user'} && $variables->{'super_secret'}){
		if($variables->{'user'} ne 'someVal' || $variables->{'super_secret'} ne $theCookie){
			if($displayFlash){
				&update_error('There was an error with validating your login credentials. Please logout of the website and then try again', $q);
			}
			else{
				if(!$q->{'.header_printed'}){	print $q->header();}
				print "500 error";
			}
			warn "User error (id = $variables->{'user'}, super secret = $variables->{'super_secret'}) cookie (id = someVal, ss = $theCookie)";
			return 0;
		}
	}
	else{
		$variables->{'user'} = $exist_check->[0][0];
		$variables->{'super_secret'} = $theCookie;
	}
	# validate proper user / super secret values (probably redundent)
	if($variables->{'user'} !~ m/^[0-9]+/){ # could have done \w
		#&update_error('There is something wrong with your user_id.  Please contact the administrator.', $q);
		warn "User error, invalid values (id = $variables->{'user'}, super secret = $variables->{'super_secret'}): $!";
		if($displayFlash){&update_error(&generic_message(), $q);}
		else{
			if(!$q->{'.header_printed'}){	print $q->header();}
			print "500 error";
		}
		return 0;
	}
	return 1;
}

# temporary directory where we will store stuff
sub getBaseDirInfo{
	my ($v, $module, $q, $comingFrom) = @_;
	$v->{'base_dir'}='../tools/../data/user_data';
	if($module eq 'dr' || $module eq 'sv'){	$v->{'base_dir'}='../../tools/../data/user_data';	}
	die 'Directory setup error '. __FILE__.' line '.__LINE__ if !&verifyDir($q,$v->{'base_dir'},$comingFrom);
	$module = "/".$module;
	$v->{'base_dir'} .= $module;
	die 'Directory setup error '. __FILE__.' line '.__LINE__ if !&verifyDir($q,$v->{'base_dir'},$comingFrom);
	$v->{'base_upload_dir'} = "$v->{'base_dir'}/user_directory";
	die 'Directory setup error '. __FILE__.' line '.__LINE__ if !&verifyDir($q,$v->{'base_upload_dir'},$comingFrom);
	return 1;
}

sub static_asset_path{
	my $base = '/'.$RELATIVE_ROOT;
	return {'images' => "$base/assets", 'stylesheets' => "$base/assets", 'javascripts' => "$base/assets", 'base' => $base};
}

# verify that a give directory exists, if it does not, create it.
sub verifyDir {
	my($q,$dir,$comingFrom,$msg)=@_;
	if(! -d $dir){
		$comingFrom = 'flash' if(!$comingFrom);
		eval{mkdir($dir, 0755) || die "Could not create directory $dir: $!";};
		if($@){
			use Cwd;
			my $cwd = cwd();
			if($comingFrom eq 'flash'){&update_error ('There was an issue generating your temporary files. '.&try_again_or_contact_admin(),$q);	}
			$msg = 'Could not create user directory: ' if(!$msg);
			warn 'Could not create user directory: '.$@.'. Current dir: '.$cwd;
			return 0;
		}
	}
	return 1;
}

sub getArrayMedian{
	# ignore param will ignore values below a certain threshold
	my ($array,$threshold) = @_;
	my @sorted;
	if(!defined $threshold){@sorted = sort { $a <=> $b } @{$array};}
	else{@sorted = sort { $a <=> $b } grep {$_ > $threshold} @{$array};}
  my $midPoint = $#sorted / 2;
  my $median = $sorted[int $midPoint];
  if ($midPoint != int $midPoint) {
  	$median = ($median + $sorted[int ($midPoint + 1)]) / 2;
  }
	return $median;
}

sub getNonZeroArrayMedian{
	my $array = shift;
	my @sorted = sort { $a <=> $b } @{$array};
	my $tenPercent = $#sorted*0.1;
	my $midPoint = $sorted[$tenPercent]+$sorted[($#sorted-$tenPercent)];
	my $threshold = $midPoint*0.1;  # currently threshold is the mean of the values at 10% and 90% of the array size
	@sorted = grep {$_ > $threshold} @sorted;
	#warn "threshold = $threshold\n";
	return &getArrayMedian(\@sorted); # grep out zero values...
}
#########################################
# NO LONGER USED
########################################
# given a density, number of row, cols, and number of replicates will return the letter position of the colony in question
# position is by column...ie given 4 replicates...
#		1		3		=		A		C
# 	2		4				B		D
sub getPosition{
	my($r,$c,$reps,$pos)=@_;
	#$pos++; # since pos starts at 0...
	my $curCol = int($pos/$r);
	my $curRow = $pos-($curCol *$r);
	$curCol++;
	# should now have row and column coordinates of colony (starting at 1)
	if($reps eq '2h'){if($curCol%2==0){return 'B';} else{return 'A';}} # can only be A or B
	if($reps eq '2v'){if($curRow%2==0){return 'B';} else{return 'A';}} # can only be A or B
	elsif($reps eq '4'){ # A, B, C, D
		my $modCol = $curCol%2;	# if this == 0 we are at position C or D, if 1 at A or B
		my $modRow = $curRow%2; # if this == 0 we are at position B or D, if 1 at A or C
		if( $modRow) { # we are at position A or C
			if($modCol) { return ($curRow, $curCol, 'A');}
			else { return ($curRow, $curCol, 'C');}
		}
		else{
			if( $modCol) {return ($curRow, $curCol, 'B');}
			else{return ($curRow, $curCol, 'D');}
		}
	}
	else{return "Can not determine.";}
	return 1;
}

sub is_numeric{
	no warnings;
	use warnings FATAL => 'numeric';
	return defined eval { $_[ 0] == 0 };
}


#################################################################
# subroutine to trim off the white space, carriage returns, pipes, and commas from both ends of each string or array
sub trimErroneousCharactersAtEnds {
	my $guy = shift;
	return if !defined $guy;
	my $type = (ref(\$guy) eq 'REF') ? ref($guy) : ref(\$guy);
	if ( $type eq 'ARRAY') { # Reference to an array
		foreach(@{$guy}) {  #for each element in @{$guy}
			s/\s+$//g;
			s/,+$//g;
			s/[\s+|\r+|\015\012+|\012+|\n+|,+]$//g;  #replace one or more spaces at the end of it with nothing (deleting them)
			s/\s+^//g;
			s/,+^//g;
			s/^[\s+|\r+|\015\012+|\012+|\n+|,+]//g;  #replace one or more spaces at the beginning of it with nothing (deleting them)
		}
	}
	elsif ( $type eq 'SCALAR' ) { # Reference to a scalar
		$guy=~ s/\s+$//g;
		$guy=~ s/\r+$//g;
		$guy=~ s/\n+$//g;
		$guy=~ s/\012+$//g;
		$guy=~ s/\015\012+$//g;
		$guy=~ s/,+$//g;

		$guy=~ s/^\s+//g;
		$guy=~ s/^\r+//g;
		$guy=~ s/^\n+//g;
		$guy=~ s/^\012+//g;
		$guy=~ s/^\015\012+//g;
		$guy=~ s/^,+//g;
	}
	return $guy;
}


1;