#!/usr/bin/perl -w

# check to see if colony size tooo big...
# add key info on hover,
# 2013-03-26 fixed a bug with encoding special characters using inspiration from this post:
# http://stackoverflow.com/questions/1970660/how-can-i-guess-the-encoding-of-a-string-in-perl

# ******************************************************
# Program created in winter 2006
# Authored by: John Dittmar
# this program is designed to read in colony size values, and arrange them in a grid according to their position on a plate
# instead of displaying the numeric value of the colony size, an image will be displayed and its size will be scaled based on
# how it's colony size relates to the average colony growth on the plate
# ******************************************************

# a note about exclusion...
# if a user manually reloads a page they will lose all automatic exclusion and all user selected exclusion...


# NOTE
# only data structures stored in the files queries.dat and plate_data.dat have 0000_ prepended to the front of query names....this is used to ensure that
# control (aka comparer) plates are presented to the user first....



BEGIN {
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
	use CGI qw/-unique_headers :standard/;
	$CGI::HEADERS_ONCE = 1;
}

use strict;
my $size_limit = 1;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 1 MB limit

use Storable qw(store retrieve); # the storable data persistence module
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use Modules::ScreenAnalysis qw(:review);
use Modules::JSON::JSON;
use HTML::Entities;
use Encode qw(decode_utf8 encode HTMLCREF);

my $q=new CGI;
my %variables;
unless(&initialize($q, $size_limit)){&update_error(&generic_message()."<br/>".&return_to_dr(),$q);}
if(&validateUser(\%variables,$q) != 1){&update_error(&generic_message()."<br/>".&return_to_dr(),$q);} # validate user

my $asset_prefix = &static_asset_path();
# temporary directory where we will store stuff
# set '$variables{base_upload_dir'} and $variables{'base_dir'}
&getBaseDirInfo(\%variables,'dr',$q);

my $upload_dir=&setSession('dr_engine', \%variables, $q);
if(!$upload_dir){
	&update_error("Error with user session, please return to the <em>DR Engine</em> setup page and re-enter your information. You may also log out and back into the website. Note that this website requires cookies to be enabled in your browser in order to work properly.".&try_again_or_contact_admin(), $q);
	die "Could not set user session $!";
}

# setup an alphabet array so that rows can be associated with the proper letter designation
my @alphabet=("A".."ZZ");

# the variables hash will hold a bunch of static variables while this program is being performed so that they do not have to be passed via forms
# $variables contains: density, control, replicates, justAnalysis, project_id, user, key_choice, lib_screened, pre_screen_reps,
# matingT, gal_leu, sec_gal_leu, final
my $variables= eval{retrieve("$upload_dir/variables.dat")};
if($@){
	&update_error(&generic_message()."<br/>".&return_to_dr(),$q);
	die "Serious error from Storable with variables.dat: $@";
}
elsif(!$variables){
	&update_error(&generic_message()."<br/>".&return_to_dr(),$q);
	die "I/O error from Storable with variables.dat: $!";
}

if($variables->{'save_directory'} ne $upload_dir){
	&update_error(&generic_message()."<br/>".&return_to_dr(),$q);
	die "The upload directory calculated ($upload_dir) does not match your earlier stored upload directory ($variables->{'save_directory'}).  Quiting.";
}

my $queries= eval{retrieve("$upload_dir/queries.dat")};
if($@){&update_error(&generic_message()."<br/>".&return_to_dr(),$q); die "Serious error from Storable with queries.dat: $@";}
elsif(!$queries){&update_error(&generic_message()."<br/>".&return_to_dr(),$q); die "I/O error from Storable with queries.dat: $!";}

my $html;
my $reset=0;
my $page_num=$q->param("page_num");

# if this is the first page, set flags and collect and experiment details to store
if($page_num eq 'FIRST_PAGE'){
	$page_num = 1;
	$reset=1;
	if($variables->{'store'}){
		$variables->{'store_params'}->{'comparer_pwj'}->{'conditions'}=();
		$variables->{'store_params'}->{'sets_to_save'}=();
		my @qc = $q->param('save_this_qc');
		my $temp_control = $variables->{'control'};
		$temp_control =~ s/0000_//;
		foreach my $qc_combo(@qc){
			#  id == 0, pwj == 1, user entered query == 2, user corrected condition == 3, original condition = 4
			my @qc_combo = split(',',$qc_combo);
			$qc_combo[4] = '' if(!defined $qc_combo[4]);
			if(defined $variables->{'store_params'}->{'conditions'}->{$qc_combo[4]}){
				if($qc_combo[3] ne $variables->{'store_params'}->{'conditions'}->{$qc_combo[4]}){
					&update_error("An error occurred while validating one of your query condition combos ($qc_combo)!<br/>Original condition '$qc_combo[4]' is associated with more then 1 user inputted condition ('$variables->{'store_params'}->{'conditions'}->{$qc_combo[4]}' and '$qc_combo[3]') - only 1 is allowed. This is case sensitive.".&return_to_dr(),$q);	exit(0);
				}
			}
			$variables->{'store_params'}->{'conditions'}->{$qc_combo[4]}=$qc_combo[3];
			if(lc($qc_combo[2]) eq lc($temp_control)){
				$variables->{'store_params'}->{'comparer_pwj'}->{'pwj'} = $qc_combo[1];
			}

			if(defined $queries->{$qc_combo[2]} && $qc_combo[0] =~ /^[0-9]+$/ && $qc_combo[1] =~ /^pwj[0-9]{1,8}$/i ){
				push(@{$variables->{'store_params'}->{'sets_to_save'}}, {'id'=>$qc_combo[0],'query'=>$qc_combo[2],'pwj'=>$qc_combo[1],'condition'=>$qc_combo[3], 'original_condition'=>$qc_combo[4] });
			}
			else{	&update_error("An error occurred while validating one of your query condition combos ($qc_combo)!<br/>".&return_to_dr(),$q);	exit(0);}
		}
	}
	# remove any duplicates, which could happen if the user reloads the page a couple of times
	# this is probably unnecessary since this array is initialized in the loop each time, but whatever.
	my %seen;
	my @temp = grep { !$seen{$_}++ } @{$variables->{'store_params'}->{'sets_to_save'}};
	@{$variables->{'store_params'}->{'sets_to_save'}} = @temp;

}

if($page_num !~ m/^([0-9]+|analysis)$/i){
	&update_error(&generic_message()."<br/>".&return_to_dr(),$q);
	die "Current page number is not an integer or is out of bounds.<br/>Page number = $page_num.";
}

if($page_num =~ /^Analysis$/){
	# no need to decode here since we are not doing anything with these params, just passing them along
	print '	<script src="'.$asset_prefix->{"javascripts"}.'/jquery.min.js" type="text/javascript"></script>
					<form onsubmit="hideStuff(); return true;" action="'.$asset_prefix->{"base"}.'/cgi-bin/dr_engine/final.cgi" id="finalAnalysis" name="finalAnalysis" method = "post">
					<input type="hidden" id="excludeList3" name="exclusionList" value="'.$q->param("exclusionList").'">
					<input type="hidden" id="killedPlates3" name="killedPlateList" value="'.$q->param("killedPlateList").'">
					<input type="hidden" id="page_num3" name="page_num" value="Analysis">
					<script type="text/javascript">document.finalAnalysis.submit();</script>
					</form>';
	exit(0);
}

#print "$upload_dir --> <br/>$variables{'upload_dir'}<br/>-->";
my $plate_data= eval{retrieve("$upload_dir/plate_data.dat")};
if($@){&update_error(&generic_message()."<br/>".&return_to_dr(),$q); die "Serious error from Storable with plate_data.dat: $@";}
elsif(!$plate_data){&update_error(&generic_message()."<br/>".&return_to_dr(),$q); die "I/O error from Storable with plate_data.dat: $!";}
my $normalization_values= eval{retrieve("$upload_dir/normalization_values.dat")};
if($@){&update_error(&generic_message()."<br/>".&return_to_dr(),$q); die "Serious error from Storable with normalization_values.dat: $@";}
elsif(!$normalization_values){&update_error(&generic_message()."<br/>".&return_to_dr(),$q); die "I/O error from Storable with normalization_values.dat: $!";}

my $dynamicVariables;

if(-e "$upload_dir/dynamicVariables.dat"){
	$dynamicVariables= eval{retrieve("$upload_dir/dynamicVariables.dat")};
	if($@){
		&update_error(&generic_message()."<br/>".&return_to_dr(),$q);
		die "Serious error from Storable with dynamicVariables.dat: $@";
	}
	elsif(!$dynamicVariables){&update_error(&generic_message()."<br/>".&return_to_dr(),$q); die "I/O error from Storable with dynamicVariables.dat: $!";}
}

# set from page to old current page
$dynamicVariables->{'from_page'} = (defined $dynamicVariables->{'current_page'}) ? $dynamicVariables->{'current_page'} : $page_num-1;
# set current page to page_num
$dynamicVariables->{'current_page'} = $page_num;
# add plates from previous page to $dynamicVariables->{'plates_reviewed'}
# if we are here then we printed out the plate without errors, so add it to the review list
{
	no warnings 'numeric';
	if(defined $dynamicVariables->{'from_page'} && $dynamicVariables->{'from_page'} ne '' && $dynamicVariables->{'from_page'} > 0 && $dynamicVariables->{'current_page'} != $dynamicVariables->{'from_page'}){
		my $start=(($dynamicVariables->{'from_page'}-1)*$variables->{'num_to_display'});
		my $limit = ($#{$variables->{'plate_order'}}+1)<($start+$variables->{'num_to_display'}) ? ($#{$variables->{'plate_order'}}+1) : ($start+$variables->{'num_to_display'});
		for(my $p=$start; $p<$limit; $p++){
			my $plateInfo=${$variables->{'plate_order'}}[$p];
			my $query = $plateInfo->{'query'};
			$query=~ s/^0000_// if $query eq $variables->{'control'}; # remove 0000_ tag used to present controls first
			$dynamicVariables->{'plates_reviewed'}->{"$plateInfo->{'plateNum'},$query,$plateInfo->{'condition'}"}=1;
		}
	}
}

my $percent_done;
my $number_plates_reviewed=keys %{$dynamicVariables->{'plates_reviewed'}};
if ($number_plates_reviewed==0){$percent_done=0;}
else{$percent_done=($number_plates_reviewed/$variables->{'total_number_plates'})*100;}

# note that the int() function just returns the integer portion of a number, in order to get the ceiling of a number we can add 0.9999 to it and then use the int() function on it
my $num_pages = (@{$variables->{'plate_order'}} < $variables->{'num_to_display'}) ? 1 : int((@{$variables->{'plate_order'}}/$variables->{'num_to_display'})+0.9999);
if($page_num>$num_pages || $page_num<0){
	&update_error(&generic_message()."<br/>".&return_to_dr(),$q);
	die "Current page number is not an integer or is out of bounds.<br/>Page number = $page_num. Limit = $num_pages.";
}



#  ************************************************************************************************************
#  ************************************* START SETUP OF DYNAMIC VARIABLES *************************************
#  ************************************************************************************************************
#  dynamic variables change as we review the plates
#  dynamic variables are the following keys -->
# 'excludeList' -> list of excluded colonies delimited by '*-*' with details delimited by '-->'
# 'plates_reviewed' -> hash of plates reviewed thus far = hash  e.g. --> $dv->{'plates_reviewed'}->{"$plate,$query,$condition"}
# 'excluded_plates' -> list of excluded plates delimited by '*-*' with details delimited by ','

# these variables may change each time this program is run...
# validate last set of dynamic variables passed to this program
#
# saving progress will also save the dynamic variables

# if the http referrer is not dr_engine/main.cgi then there are no colonies to check for exclusion and we are
# likely just entering the analysis process. In this case setting $dynamicVariables->{'starting'} to 1 will
# prevent the function "setupDynamicVariables" from doing anything. After this $dynamicVariables->{'starting'} is immediately
# deleted
if($ENV{HTTP_REFERER} !~ /cgi\-bin\/dr_engine\/main\.cgi/i){	$dynamicVariables->{'starting'}=1;}
else{	delete($dynamicVariables->{'starting'}) if defined $dynamicVariables->{'starting'};}


&saveDRprogress($variables, $dynamicVariables, $plate_data, $normalization_values, $queries, $q);
#  ************************************************************************************************************
#  ************************************** END SETUP OF DYNAMIC VARIABLES **************************************
#  ************************************************************************************************************
my $excluded_plates="";
foreach(keys %{$dynamicVariables->{'excluded_plates'}}){
	if("0000_$_" =~ /^0000_1512/){
		$excluded_plates.="$_*-*";
	}
	else{$excluded_plates="$_*-*$excluded_plates";}
}
$excluded_plates =~ s/^[\*\-\*]+|[\*\-\*]+$//ig; # chop off leading and trailing *-*


my $options= &setupOptions($variables->{'plate_order'},$page_num,$num_pages,$variables->{'num_to_display'},$dynamicVariables->{'plates_reviewed'});
&setupReviewLoadingPage($q,$variables->{'cell_size'}+5,$upload_dir,$number_plates_reviewed,$variables->{'total_number_plates'},$percent_done,$options,$page_num,$options, $excluded_plates);

my ($plate, $query, $condition, $holder, @current_excluded, $data, $iterations, $ratio_cutoff);
my $exclude_list="";
$ratio_cutoff =  ($variables->{'death_threshold_cutoff'})*$variables->{'cell_size'};
# start and limit will help define the plates that we will be viewing on the current page
my $start=(($page_num-1)*$variables->{'num_to_display'});
my $limit = ($#{$variables->{'plate_order'}}+1)<($start+$variables->{'num_to_display'}) ? ($#{$variables->{'plate_order'}}+1) : ($start+$variables->{'num_to_display'});
my $ref_control = $variables->{'control'};
$ref_control=~ s/^0000_//;

# hold the labels of the plates that have been displayed on the current page. This array will then
# be used to construct a javascript array
my @platesDisplayed = ();
for(my $p=$start; $p<$limit; $p++){
	my $plateInfo=${$variables->{'plate_order'}}[$p];
	my $query = $plateInfo->{'query'};
	$query=~ s/^0000_// if $query eq $variables->{'control'}; # remove 0000_ tag used to present controls first

	my $plateLabel = $variables->{'originalData'}->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}};

	# get the jsLabel, escape the appropriate characters and then push to array
	# in the js special characters can be unescaped via something like:
	# $("<div/>").html(plateIndices[0]).text()
	my $jsLabel = "$plateLabel->{'query'},$plateLabel->{'plateNum'},$plateLabel->{'condition'}";
	$jsLabel =~ s/\"/&#34;/g; # escape double quotes
	$jsLabel =~ s/\'/&#39;/g; # escape single quotes
	# escape everything else and push to array
	push(@platesDisplayed,encode('ascii', decode_utf8($jsLabel), HTMLCREF));

	if(!defined $plateInfo->{'condition'} || $plateInfo->{'condition'} eq '' || $plateInfo->{'condition'} eq '-'){&update_message("$plateLabel->{'plateNum'}, $plateLabel->{'query'}", $q);}
	else{&update_message("$plateLabel->{'plateNum'}, $plateLabel->{'query'}, $plateLabel->{'condition'}", $q);}
	$data = $plate_data->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}}->[0] ? $plate_data->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}}->[0] : $plate_data->{$plateInfo->{'plateNum'}}->{"0000_$query"}->{$plateInfo->{'condition'}}->[0];


	if($reset){delete($dynamicVariables->{'excluded_colonies'}->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}});}
	# *********************************************************************************************
	# ********************* START SEARCHING FOR GENERAL GROWTH ISSUES (GLOBAL) ********************
	# *********************************************************************************************

	my $runGlobal=1;
	if($variables->{'runGlobalExclusion'}==0 || (defined $dynamicVariables->{'plates_reviewed'}->{"$plateInfo->{'plateNum'},$query,$plateInfo->{'condition'}"} && $dynamicVariables->{'plates_reviewed'}->{"$plateInfo->{'plateNum'},$query,$plateInfo->{'condition'}"} == 1)){
		$runGlobal=0;
	}
	# if exclusion data structure does not exists for this plate, query, condition combo, then initialize it!
	if(!$dynamicVariables->{'excluded_colonies'}->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}}){$dynamicVariables->{'excluded_colonies'}->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}}={};}
	# if the user has elected to run global exclusion

	if($runGlobal){
		&checkForGlobalExclusion(
			$data, # reference to an array that contains all the data for a given plate, condition, and query combo
			$dynamicVariables->{'excluded_colonies'}->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}},
			($normalization_values->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}}*$variables->{'death_threshold_cutoff'}),
			$variables->{'density'},
			$variables->{'rows'},
			$variables->{'cols'},
			$plateLabel,
			$q);
	}

	# *******************************************************************************************
	# ********************* END SEARCHING FOR GENERAL GROWTH ISSUES (GLOBAL) ********************
	# *******************************************************************************************

	# check for replicate exclusion...print cartoon
	$exclude_list.= &printReviewCartoon($data,
																			$dynamicVariables,
																			$ref_control,
																			$plateInfo->{'plateNum'},
																			$query,
																			$plateInfo->{'condition'},
																			$variables,
																			$ratio_cutoff,
												 							$normalization_values->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}},
												 							\@current_excluded,
												 							'analysis',
												 							$q,
												 							(scalar(@platesDisplayed)-1));
}

my $message='Loading...';
my $value = "Goto next page";
if($variables->{'lastPage'} != $dynamicVariables->{'current_page'}){
	$html.=  '<form id="next_plates" return true;" action="'.$asset_prefix->{"base"}.'/cgi-bin/dr_engine/main.cgi" name="next_plates" method = "post">';
	$message='Generating Cartoon Renderings...';
}
else{
	$html.=  '<form action="'.$asset_prefix->{"base"}.'/cgi-bin/dr_engine/final.cgi" name="finalAnalysis" id="finalAnalysis" method = "post">';
	$message='Performing Final Analysis...';
	$value = 'This is the last page of plate to review. Click here to finalize analysis.'
}
$html.=  '
<input type="hidden" id="excludeList" name="exclusionList" value="">
<input type="hidden" id="killedPlates" name="killedPlateList" value="">
<input type="hidden" name="page_num" value='.($page_num+1).'>
<input type="submit" class="commit" onclick="parent.setupFlash(true, \''.$message.'\');" value="'.$value.'">
</form>';
if(scalar(@platesDisplayed)==0){
	$html.=  '<script type="text/javascript">document.finalAnalysis.submit();parent.setupFlash(true, \'$message\');</script>';$html.=  'You will be automatically redirected to the next page shortly.  If you are not redirected within few seconds please click the button above'; }
$variables->{'control'}=~ s/0000_//; # remove 0000_ tag used to present controls first
$html.=  '<script src="'.$asset_prefix->{"javascripts"}.'/topMenuJQ.js" type="text/javascript"></script>';

# $control_excluded only contains complete sets (ie. if replicate = 4, then 4) of control colonies for a strain
# iterate over these guys in the javascript, changing the control query name to an experimental one, and then,
# instead of sending this query to the excludeColonies (ec) function, just manually change it's background color.
# this can be done since we do not need to track it in any other lists.  However, NEed to make sure that if a colony
# is excluded on control (pink) is selected to be manually excluded (turning it red), that if that colony is chosen
# to be re-included, it returns to pink and not white....
# in the old version of this program this was not supported...

#$dynamicVariables->{'from_page'} = $page_num;


delete($dynamicVariables->{'starting'}) if defined $dynamicVariables->{'starting'};
eval {store($dynamicVariables, "$upload_dir/dynamicVariables.dat")};
if($@){ warn 'Serious error from Storable, storing $dynamicVariables: '.$@.'<br/>';}
eval {store(\@current_excluded, "$upload_dir/current_excluded.dat")};
if($@){ warn 'Serious error from Storable, storing @current_excluded: '.$@.'<br/>';}
&update_message("Rendering Webpage", $q);

my $json = JSON->new;
$json = $json->utf8;
# generate reverse lookup for @platesDisplayed
# also convert prepend indices in array with 'p' (b/c html ids cannot start with a number)
# and then store in hash
my %platesDisplayedHash = ();
my %platesDisplayed = ();
for (my $i = 0; $i < @platesDisplayed; $i++) {
	$platesDisplayed{"p$i"}=$platesDisplayed[$i];
	$platesDisplayedHash{$platesDisplayed[$i]}="p$i";
}

$html.=  '
<iframe name="reset_reset" style="display:none;"></iframe>
<script type="text/javascript">
var control = "'.$variables->{'control'}.'";
var plateRows = parseInt('.$variables->{'rows'}.');
var plateRows2 = plateRows * 2;
var plateRows3 = plateRows * 3;
var replicates = "'.$variables->{'replicates'}.'";
var numReps = parseInt('.$Modules::ScreenAnalysis::NUM_REPLICATES{$variables->{'replicates'}}.');
var plateIndices = $.parseJSON(\''.$json->encode(\%platesDisplayed).'\');
var plateIndicesRev = $.parseJSON(\''.$json->encode(\%platesDisplayedHash).'\');
// passing the text to a dummy html element and then retreiving it will convert any character references (e.g. &#924;)
// to the corresponding utf-8 character (e.g. μ)
var dummy = document.createElement("textarea");
dummy.innerHTML = "'.(join "!-!", keys %{$queries}).'";
var queries = dummy.value.split("!-!");
parent.killElement(parent.document.getElementById(\'exclusionTableWrapper\'));
parent.addMenu("'.$exclude_list.'", plateIndicesRev);
</script>';

print encode('ascii', decode_utf8($html), HTMLCREF);


#warn "$exclude_list";
# check if we are still in an iframe, if not, redirect to one...
print '
<form action="/'.$asset_prefix->{"base"}.'/screen_mill/dr_engine" name="reset_iframe" id="reset_iframe" method = "post">
<input type="hidden" name="page_num" value="'.$page_num.'">
<input type="hidden" name="reset" value="true">
</form>';
print <<OUT;
<script type="text/javascript">
var reg = new RegExp('/screen_mill/dr_engine');
if(!reg.test(parent.location.href)){document.reset_iframe.submit();}
</script>
</div><span id="fullyLoaded"></span></body></html>
OUT

exit(0);
sub setupOptions{
	my($po,$pn,$np,$ntd,$pr)=@_; # plate_order, $page_num, $num_pages, $variables->{'num_to_display'}, $plates_reviewed
	my $count=1;
	my $count1=1;
	my $review_flag=0;
	my $options="<option disabled>Select:</option>";
	# had to copy the array, if I did not do this my foreach loop would be 'foreach my $plate(@{$po})'
	# but when I did this it seemed as if $plate was a reference and when I stripped out the 0000_ tag
	# in $plate, it would alter the $po array as well.  This messed up the program....stupid references
	my @a = @{$po};
	foreach my $plateInfo(@a){
		my $query = $plateInfo->{'query'};
		my $plate = $plateInfo->{'plateNum'};
		my $condition = $plateInfo->{'condition'};
		$query=~ s/0000_//;
		$review_flag++ if $pr->{"$plate,$query,$condition"};
		if($count/$ntd == 1){
			$options.="<option ";
			my $text = $count1;
			if(!($pn  =~ /Analysis/)){if($count1 == $pn){$options.=" disabled";}
			elsif($count1 == ($pn+1)){$options.=" selected=\"selected\"";}}
			$options.= " value='$count1'";
			if($review_flag>=$ntd){ $count1 = "$count1 &#10003;"}
			$options.=  ">$count1</option>";
			$count1++;
			$count=0;
			$review_flag=0;
		}
		$count++;
	}
	if($count <= $ntd && scalar(@a)%$ntd != 0 ){
		$options.="<option ";
		if(!($pn  =~ /Analysis/)){if($count1 == $pn){$options.=" disabled";}
		elsif($count1 == ($pn+1)){$options.=" selected=\"selected\"";}}
		if($review_flag>=($count-1)){$options.=" class=reviewed";}
		$options.=  ">$count1</option>";
	}
	if($pn  !~ /Analysis/){if($pn == $np){$options.="<option selected>Analysis</option>";}else{$options.="<option>Analysis</option>";}}
	else{$options.="<option selected>Analysis</option>";}
	return $options;
}
