#!/usr/bin/perl -w

# ******************************************************
# Screen Validation Engine
# Program created on 21 - June - 2008
# Authored by: John Dittmar
# ******************************************************

BEGIN {
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
	use CGI qw/:standard/;
	$CGI::HEADERS_ONCE = 1;
	$|=1;
}

use strict;
use lib '/home/rothstei/perl5/lib/perl5';
use lib '..';
my $size_limit = 20;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 20 MB limit

use Storable qw(store retrieve); # the storable data persistence module
use Modules::ScreenAnalysis qw(:sv_engine);
use Modules::JSON::JSON;
use Encode qw(decode_utf8 encode HTMLCREF);
my $asset_prefix = &static_asset_path();
my $q=new CGI;
my %variables;
unless(&initialize($q, $size_limit)){exit;}
unless(&validateUser(\%variables,$q)){exit;} # validate user

my (@conditions, $data, $ratio, $count, $i, $j, $p,$c, $dead_flag, $onOff, $holder, $exclude_flag,
		$highlightCheck, $selected_sets,$properties, $chosen_sets, $from_page,$current_page);

# temporary directory where we will store stuff
# set '$variables{base_upload_dir'} and $variables{'base_dir'}
&getBaseDirInfo(\%variables,'sv',$q);
# retreive current working directory (the temporary directory specific to this user where data structures are stored via storable)
my $upload_dir=&setSession('sv_engine', \%variables, $q);

if(!$upload_dir){
	print $q->header(); # the "magic line" that tells the WWW that we are an HTML document
	&update_error("Error with user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
	die "Could not set user session $!";
}

# verify that the page we came from is correct
my $referer=$ENV{HTTP_REFERER};

# if($referer !~'http://www.rothsteinlab.com/$asset_prefix->{'base'}/screen_mill/dr_engine' && $referer !~'http://www.rothsteinlab.com/$asset_prefix->{'base'}/cgi-bin/dr_engine.cgi'  && $referer !~'http://www.rothsteinlab.com/$asset_prefix->{'base'}/cgi-bin/dr_restore_session.cgi'  && $referer !~ 'http://rothsteinlab.com/$asset_prefix->{'base'}/screen_mill/dr_engine' && $referer !~'http://rothsteinlab.com/$asset_prefix->{'base'}/cgi-bin/dr_engine.cgi' && $referer !~ 'http://rothsteinlab.com/$asset_prefix->{'base'}/cgi-bin/dr_engine.cgi'){
# 	&update_error(&generic_message()."<br/>".&return_to_dr(),$q);
# 	die "Entered page through invalid means:$referer. $!\n";
# }

$current_page = ($q->param("current_page")) ? $q->param("current_page") : 0 ;
if($current_page!~/^([0-9]*)$/){
	&update_error("You seem to be trying to access a page that does not exist. You may only attempt to access valid page values.<br/>".&contact_admin(), $q);
	die "Invalid page entered: $current_page.\n";
}
my $dp = $current_page+1; # current page starts at 0
print <<EOM;
<html><head>
<title>ScreenMill - Screen Visualization</title>
<script src="$asset_prefix->{'javascripts'}/jquery.min.js" type="text/javascript"></script>
<script src="$asset_prefix->{'javascripts'}/dr_engine/sv_engine.js" type="text/javascript"></script>
<link href="$asset_prefix->{'stylesheets'}/dr_engine/sv_engine.css" media="screen" rel="Stylesheet" type="text/css" />
<script type="text/javascript">
	parent.document.title="ScreenMill - Screen Visualization Engine - Page $dp";
</script>
EOM

&initialize($q, $size_limit);

my @alphabet=("A".."ZZ");

my $warning='';
my $plates_per_page = 2;
my($data_plate, $normalization_values, $dinfo);
&update_message('Processing Data...', $q);
my $variables= eval{retrieve("$upload_dir/variables.dat")};
if($@){&update_error('There was an issue retrieving your data. '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with variables.dat: $@";}
elsif(!$variables){&update_error ('There was an issue retrieving your data. '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with variables.dat: $!";}
if($variables->{'save_directory'} ne $upload_dir){
	&update_error('Error finding temporary directory.  '.&try_again_or_contact_admin(), $q);
	die "The upload directory calculated ($upload_dir) does not match your earlier stored upload directory ($variables->{'save_directory'}).";
}
$variables->{'reviewed'}->{$variables->{'from_page'}}=1;

if($current_page > $variables->{'num_pages'}){
	&update_error("Invalid page entered.<br/>Page entered = $current_page but there are only $variables->{'num_pages'} pages available to display.<br/>You may only attempt to access valid page values.<br/>".&contact_admin(), $q);
	die "Invalid page entered: $current_page, num_pages = $variables->{'num_pages'}.\n";
}
if($variables->{'processing_choice'} eq 'log_file'){
	$normalization_values= eval{retrieve("$upload_dir/normalization_values.dat")};
	if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with normalization_values.dat: $@";}
	elsif(!$normalization_values){&update_error ('There was an issue retrieving your data  '.&try_again_or_contact_admin(),$q); die "I/O error from Storable with normalization_values.dat: $!";}
}
$data_plate= eval{retrieve("$upload_dir/plate_data.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with plate_data.dat: $@";}
elsif(!$data_plate){&update_error ('There was an issue retrieving your data  '.&try_again_or_contact_admin(),$q);  die "I/O error from Storable with plate_data.dat: $!";}
$dinfo= eval{retrieve("$upload_dir/out_all_shorty.dat")};
if($@){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q); die "Serious error from Storable with out_all.dat: $@";}
elsif(!$dinfo){&update_error ('There was an issue retrieving your data.  '.&try_again_or_contact_admin(),$q);  die "I/O error from Storable with out_all.dat: $!";}

# render page with new threshold for selected set...
if($q->param("combo")){
	$holder=$q->param('combo');
	$holder="\L$holder";
	my ($query,$condition) = (split( /,/,$holder))[0,1];
	$condition = defined($condition) ? $condition : '';
	if(defined $variables->{'orig_pthresh'}->{$query}->{$condition}){
		if($q->param("pthresh")<0  || $q->param("pthresh") !~/^([+-]?)(?=\d|\.\d)\d*(\.\d*)?([Ee]([+-]?\d+))?$/){
			$data=$q->param('pthresh');
			$condition = ($condition eq '-' || $condition eq '') ? 'n/a' : $condition;
			&update_error("Invalid P-value threshold value (p-value threshold = $data, query = $query, condition = $condition).<br/>Page not rendered with new threshold for set: query = $query, condition = $condition<br/>", $q);
			die "Invalid P-value threshold value (p-value threshold = $data, query = $query, condition = $condition).\nPage not rendered with new threshold for set query = $query, condition = $condition";
		}
		$variables->{'pthresh'}->{$query}->{$condition}=$q->param("pthresh");
		$variables->{'num_sigs'}->{$query}->{$condition}=0;
		$variables->{"hit_list"}->{$query}->{$condition}={};

		foreach my $plate(keys %{$dinfo}){
			for($i=1; $i<=$variables->{'cols'}; $i++){
				for ($j=0; $j<$variables->{'rows'}; $j++){
					if(&is_numeric($dinfo->{$plate}->{$query}->{$condition}->{$alphabet[$j]}[$i]->[1]) && $dinfo->{$plate}->{$query}->{$condition}->{$alphabet[$j]}[$i]->[1] <= $variables->{'pthresh'}->{$query}->{$condition}){
						$variables->{'num_sigs'}->{$query}->{$condition}++;
						$variables->{"hit_list"}->{$query}->{$condition}->{$plate}.='<li>'.$dinfo->{$plate}->{$query}->{$condition}->{$alphabet[$j]}[$i]->[0]." ($plate - $alphabet[$j]$i)</li>";
					}
					$variables->{'sample_size'}->{$query}->{$condition}++;
				}
			}
		}
	}
	else{
		$warning = "<br/><br/><div class='warning'>ERROR. Could not re-render webpage with new threshold.  ".&try_again_or_contact_admin()."</div>";
		warn "could not re-render webpage with new threshold. query = $query --> condition = $condition,  original thresh = $variables->{'orig_pthresh'}->{$query}->{$condition}";
	}
}
$selected_sets=&checkSelectedSets($variables, $q, $normalization_values, $dinfo, 'all');
$variables->{'from_page'}=$current_page;


foreach $c(sort keys %{$variables->{'conditions'}}){push @conditions, $c;}
my $x=0; # position from left
my $y=0; #position from top
my $px='px';
my $css_width=($variables->{'width'}-2);
my $css_height=($variables->{'height'}-2);
my $css_span=($variables->{'span'}+3);

my $w1=($variables->{'width'}-1);

&update_message('Rendering Layout...', $q);
print <<EOM;
<style type="text/css">
.highlight span {
  list-style-type: none;
  position: absolute;
  left:0;
  width:$css_width$px;
  height:$css_height$px;
  border: 2px solid transparent;
  z-index:5;
}

.highlight a {
  /*visibility: hidden;*/
  list-style-type: none;
  position: absolute;
  left:$css_span;
  width:$css_width$px;
  height:$css_height$px;
  z-index:4;
  border: 2px solid transparent;
  /*background: url(..$asset_prefix->{'base'}/images/comparison/25w.png);*/
}
EOM
$css_width+=2;
$css_height+=2;
print <<EOM;
.highlight em {
  visibility: visible;
  list-style-type: none;
  position: absolute;
  left:0;
  width:$css_width$px;
	height:$css_height$px;
  font-size: xx-small;
  text-align: center;
  vertical-align: middle;
  color: black;
  text-decoration: none;
}
.highlight b{
  visibility: visible;
  list-style-type: none;
  position: absolute;
  left:$css_span;
  width:$css_width$px;
  height:$css_height$px;
  font-size: xx-small;
  text-align: center;
  vertical-align: middle;
  color: black;
  text-decoration: none;
}
.highlight li:hover {
	height:auto;
	width:$css_span$px;
}
.highlight li:hover div{
	font-size:1.0em;
	font-weight:bold;
	overflow:visible;
 	display: block;
 	text-align:left;
 	vertical-align: top;
 	color: black;
 	background-color: #F4F4F4;
	position: absolute;
 	border: 1px solid #BCBCBC;
 	padding: 5px;
 	margin-left:$w1$px;
 	margin-right:$variables->{'width'};
	z-index:3;
 }
EOM

if($variables->{'processing_choice'} eq 'log_file'){
	for($i=1; $i<=$variables->{'cols'}; $i++) {
		for ($j=0; $j<$variables->{'rows'}; $j++){
			$x = ($variables->{'width'})*($i-1);
			$y=($variables->{'height'})*$j-2;
			print "."."$alphabet[$j]$i"." { left: ".$x."px; top: ".$y."px; width:".($variables->{'width'})."px; height:".($variables->{'height'})."px; }\n";
			$x+=$css_span;
			#print "#"."$alphabet[$j]$i"."R"." { left: ".$x."px; top: $y"."px;}\n";
		}
	}
}
else{
	for($i=1; $i<=$variables->{'cols'}; $i++) {
		for ($j=0; $j<$variables->{'rows'}; $j++){
			$x = $variables->{'imageX'}/$variables->{'cols'}*($i-1);
			$y=$variables->{'imageY'}/$variables->{'rows'}*$j;
			print "."."$alphabet[$j]$i"." { left: ".($x-1)."px; top: ".($y-1)."px; width:".($variables->{'width'}+2)."px; height:".($variables->{'height'}+2)."px; }\n";
			$x+=$variables->{'imageX'};
			#print "#"."$alphabet[$j]$i"."R"." { left: ".$x."px; top: $y"."px;}\n";
		}
	}
}
print <<HEAD;
</style></head>
<body id="imageComparisonBody" style="width:100%;top:0px;margin:0px;padding:0px 8px 0px 8px;" return false;">
HEAD

print <<MENU_STUFF;
	<div id=layout style="margin:0px;display:none;">
		<div class="sv_links">
			<ul style="margin:5px;padding:2px 2px 2px 15px;">
				<li onclick="showHideDivs('SummaryDiv', 'TopRightDiv');">Show Selected Sets (this page)</li>
				<li onclick="showHideDivs('pthreshDiv', 'TopRightDiv');">Adjust P-Value Threshold</li>
				<li onclick="showHideDivs('hitListDiv', 'TopRightDiv');">Show Hit List</li>
			</ul>
		</div>
		<div id="pthreshDiv" class="TopRightDiv" style="display:none;">
			<u style="color:blue;" class="sv_close"></u>
    	<div id="pthreshHead" class="TopRightDivHead">Adjust P-Value Threshold</div>
			<div class=content>
			<form action="$asset_prefix->{'base'}/cgi-bin/sv_engine/main.cgi" method="post" id="changePval" name="changePval">
	      <ul style="list-style-image: url($asset_prefix->{'images'}/css/arrow-bullet.png);; color:black;">
					<li>
						Threshold to change:<br/><small>(Current Threshold)</small>:<br/>
						<SELECT class="formSelect" style="display:inline;background:#ffff99;padding-bottom:5px;" name="toChange" id="comboToChange">
							<OPTION VALUE="filler" SELECTED>Select a condition:
MENU_STUFF
foreach my $plateInfo(@{$variables->{'plates_on_page'}->[$current_page]}){
	my $query =$plateInfo->{'query'}; # in the pthresh structure the query and condition are lowercase
	my $condition = $plateInfo->{'condition'};
	if(! defined $variables->{'pthresh'}->{$query}->{$condition}){
		$variables->{'pthresh'}->{$query}->{$condition} = 0.05 / $variables->{'sample_size'}->{$query}->{$condition};
	}
	my $plateLabel = $variables->{'originalData'}->{$plateInfo->{'plateNum'}}->{$query}->{$condition};
	my $label = ($condition && $condition ne '' && $condition ne '-') ? "$plateLabel->{'query'}, $plateLabel->{'condition'}" : $plateLabel->{'query'};
	print "<option value='$query,$condition'>$label (",$variables->{'pthresh'}->{$query}->{$condition},")" if($variables->{'pthresh'}->{$query}->{$condition} =~ /^[+-]?([0-9]*\.?[0-9]+|[0-9]+\.?[0-9]*)([eE][+-]?[0-9]+)?$/);
	# above is a regular expression that matches numbers. Integers or decimal numbers with or without the exponential form.
}
print <<MENU_STUFF;
						</select>
					</li><li>
						Desired Threshold:<br/>
							<SELECT class="formSelect" style="padding-left:15px; display:inline;background:#ffff99;" id="front_pval" name="front_val" disabled>
							<OPTION VALUE="filler" SELECTED>-
							<OPTION VALUE="1">1
							<OPTION VALUE="2">2
							<OPTION VALUE="3">3
							<OPTION VALUE="4">4
							<OPTION VALUE="5">5
							<OPTION VALUE="6">6
							<OPTION VALUE="7">7
							<OPTION VALUE="8">8
							<OPTION VALUE="9">9
						</SELECT> x 10^
						<SELECT class="formSelect" style="background:#ffff99;" id="end_pval" name="end_val" disabled>
							<OPTION VALUE="filler" SELECTED>-
							<OPTION VALUE="-1">-1
							<OPTION VALUE="-2">-2
							<OPTION VALUE="-3">-3
							<OPTION VALUE="-4">-4
	 						<OPTION VALUE="-5">-5
							<OPTION VALUE="-6">-6
							<OPTION VALUE="-7">-7
							<OPTION VALUE="-8">-8
							<OPTION VALUE="-9">-9
						</SELECT>
					</li>
				</ul>
MENU_STUFF

print <<MENU_STUFF;
				<input type="hidden" name="selected_sets" id="chosen_sets2" class="chosen_sets" value="" />
				<input type="hidden" name="combo" id="combo" value="" />
				<input type="hidden" id="current_page_displayed1" name="current_page"  value="$current_page" />
				<input type="hidden" name="pthresh" id="adjusted_pthresh" value="" /><br/>
				<input type="submit" value="Re-Render Page"/>
			</form>
			</div>
    </div>
		<div id="PlateNumber">
			<b>Jump To Page: </b><select name="jpage" id="jump">
MENU_STUFF

$count=0;
foreach my $plates(@{$variables->{'plates_on_page'}}){
	if(@{$plates}){
		my $page='';
		my $options='';
		my $pageReviewed = 1;
		foreach my $plateInfo(@{$plates}){
			my $plateLabel = $variables->{'originalData'}->{$plateInfo->{'plateNum'}}->{$plateInfo->{'query'}}->{$plateInfo->{'condition'}};
			if(defined $plateInfo->{'condition'} && $plateInfo->{'condition'} ne '-' && $plateInfo->{'condition'} ne ''){
				$page.="[ $plateLabel->{'plateNum'}, $plateLabel->{'query'}, $plateLabel->{'condition'} ] ~ ";
			}
			else{
				$page.="[ $plateLabel->{'plateNum'}, $plateLabel->{'query'} ] ~ ";
			}
			if(! defined $variables->{'plates_reviewed'}->{"$plateInfo->{'plateNum'},$plateInfo->{'query'},$plateInfo->{'condition'}"}){
				$pageReviewed=0;
			}
		}
		chop($page);chop($page); # remove trailing ~
	 	$page=~s/, -/, /g if $page=~/, -/; # remove condition if it is null ( dash indicates null condition)
	 	if($pageReviewed){$page.= " &#10003;";}
		if($variables->{'reviewed'}->{$count}){$options = "class=reviewed";}
		if($count==$current_page){print "<option value='$count' selected='SELECTED' $options>".($count+1).") $page";}
		else{print "<option value='$count' $options>".($count+1).") $page\n";}
		print "</option>";
		$count++;
	}
}
$warning = "$warning<br/>" if ($warning ne '');

print <<LEGEND;
		</select>
		<button type="button" id="plateJumpButton" disabled="disabled">Go</button>
	</div><br/>
	$warning
	<ul id="toc">
LEGEND

$count=0;
foreach my $plateInfo(@{$variables->{'plates_on_page'}->[$current_page]}){
	my $q = $plateInfo->{'query'};
	my $c = $plateInfo->{'condition'};
	my $p = $plateInfo->{'plateNum'};
	my $plateLabel = $variables->{'originalData'}->{$p}->{$q}->{$c};
	my $combo = (defined $c && $c ne '-' && $c ne '') ? "$plateLabel->{'query'}, $p, $plateLabel->{'condition'}" : "$plateLabel->{'query'}, $p";
	if($count<1){print "<li id='p$count' class='current'><span onclick=\"show_plate('p$count');\">$combo</span></li>";}
	else{print "<li id='p$count'><span onclick=\"show_plate('p$count');\">$combo</span></li>";}
	$count++;
}
print "</ul><div id=plates>";

my ($sets)=('');
my ($blank_flag);
my $oControl = $variables->{'control'};
$oControl =~ s/0000_//;
my $style='block';

my $oLabelTags='';
$oLabelTags.='<label>P-Value:</label>' if $variables->{'statCols'}->{'pValue'};
$oLabelTags.='<label>Z-score:</label>' if $variables->{'statCols'}->{'zScore'};
$oLabelTags.='<label>Calculated Log Growth Ratio:</label>' if $variables->{'statCols'}->{'calcLogRatio'};
$oLabelTags.='<label>Normalized Growth Ratio:</label>' if $variables->{'statCols'}->{'normRatio'};
$oLabelTags.='<label>Growth Ratio Values:</label>' if $variables->{'statCols'}->{'normGrowthRatio'};
my @platesDisplayed=();
foreach my $plateInfo(@{$variables->{'plates_on_page'}->[$current_page]}){
	my $condition = $plateInfo->{'condition'};
	my $query = $plateInfo->{'query'};
	my $plate = $plateInfo->{'plateNum'};
	my $plateLabel = $variables->{'originalData'}->{$plate}->{$query}->{$condition};
	$variables->{'plates_reviewed'}->{"$plate,$query,$condition"}=1;
	my $jsLabel = "$plateLabel->{'query'},$plateLabel->{'plateNum'},$plateLabel->{'condition'}";
	$jsLabel =~ s/\"/&#34;/g; # escape double quotes
	$jsLabel =~ s/\'/&#39;/g; # escape single quotes
	# escape everything else and push to array
	push(@platesDisplayed,encode('ascii', decode_utf8($jsLabel), HTMLCREF));

	my $combo = (defined $condition && $condition ne '-' && $condition ne '') ? "$plateLabel->{'query'}, $plate, $plateLabel->{'condition'}" : "$plateLabel->{'query'}, $plate";

	&update_message("$combo...", $q);
	print '
		<div class="pthresh" style="display:'.$style.';" id="p'.(scalar(@platesDisplayed)-1).'_pthresh">
		Current P-Value Threshold for significance: ';
	if($variables->{"pthresh"}->{$query}->{$condition} < 0.00001){
		printf('%.3e',$variables->{"pthresh"}->{$query}->{$condition});
	}
	else{printf('%.3g',$variables->{"pthresh"}->{$query}->{$condition});}
	print
		'<br/>
		Significant hits at this threshold (across all plates): '.$variables->{"num_sigs"}->{$query}->{$condition}.'
		out of '.$variables->{"sample_size"}->{$query}->{$condition}.' (';
	printf("%.2f" ,($variables->{"num_sigs"}->{$query}->{$condition}/ $variables->{"sample_size"}->{$query}->{$condition})*100);
	print '%)</div>';

	print '<TABLE style="display:'.$style.';" id="p'.(scalar(@platesDisplayed)-1).'_sub" class="plate_tab"><tr>
				<th valign=top>';
	print '<div class="highlight">'."";

	$style='none';

	if($variables->{'processing_choice'} eq 'log_file'){
		if(! defined ($normalization_values->{$plate}->{$query}->{$condition}) || !defined($normalization_values->{$plate}->{$oControl}->{$condition})){
			&update_error("Could not find plate average for the plate '$plate, $oControl, $condition' or '$plate, $query, $condition'.  ".&try_again_or_contact_admin(), $q);
			die "Could not find plate average for the plate '$plate, $oControl, $condition' or '$plate, $query, $condition'.";
		}
		if(!$data_plate->{$plate}->{$variables->{'control'}}->{$condition}->[0] || !$data_plate->{$plate}->{$query}->{$condition}->[0]){
			&update_error("Could not find data associated with '$plate, $oControl, $condition' or '$plate, $query, $condition'.  ".&try_again_or_contact_admin(), $q);
			die "Could not find data associated with '$plate, $oControl, $condition' or '$plate, $query, $condition'.";
		}
		print &printComparisonCartoon($data_plate->{$plate}->{$variables->{'control'}}->{$condition}->[0], $variables, $plate, $oControl, $condition, $normalization_values->{$plate}->{$oControl}->{$condition});
	}
	else{print "<img src=\"$data_plate->{$plate}->{$variables->{'control'}}->{$condition}\"  width=\"$variables->{'imageX'}\" height=\"$variables->{'imageY'}\" />\n";}
	# print overlay info
	print "<ul>\n";
	for($i=1; $i<=$variables->{'cols'}; $i++) {
		for ($j=0; $j<$variables->{'rows'}; $j++){
			my $labelTags = $oLabelTags;

			$properties=$dinfo->{$plate}->{$query}->{$condition}->{$alphabet[$j]}[$i];
			# properties is a reference to an array with the following indices:
			# 0 = id, 1 = p-value, 2 = Z-score, 3 = Normalized ratio (control::experimental), 4 = log ratio

			my $ratios=""; # stores ratios of other conditions
			foreach my $co(@conditions){
				if($co ne $condition && defined $dinfo->{$plate}->{$query}->{$co}){
					$ratio = $dinfo->{$plate}->{$query}->{$co}->{$alphabet[$j]}[$i]->[3];
					if($ratio=~/blank/ || $ratio=~/excluded/ || $ratio=~/dead/){$ratio=~s/^\D+|\D+$//ig; }#$ratio=~s/blank-|-blank|excluded-|-excluded|dead-|-dead//ig;}
					$ratio = sprintf("%.3f", (split/::/,$ratio)[0])."::".sprintf("%.3f", (split/::/,$ratio)[1]);
					$ratios .= "<br/>$ratio - $co";
				}
			}
			$dead_flag=0;
			$blank_flag=0;
			$exclude_flag=0;
			$ratio = $properties->[3];
			#if((split/::/,$properties->[4])[0] < 0.3 && (split/::/,$properties->[4])[1] < 0.3){$dead_flag=1;}
			if($ratio=~/blank/){$blank_flag=1;$ratio=~s/blank-|-blank//ig;}
			elsif($ratio=~/excluded/){$exclude_flag=1;$ratio=~s/excluded-|-excluded//ig;}
			elsif($ratio=~/dead/){$dead_flag=1; $ratio=~s/dead-|-dead//ig;} # the content of index 1 is the normalized ratio stuff and should be marked is necessary

			# build on mouse over popup text...
			my $pval = $properties->[1];
			my $alt='';
			$alt.="<span>$pval</span>" if $variables->{'statCols'}->{'pValue'};
			$alt.="<span>$properties->[2]</span>" if $variables->{'statCols'}->{'zScore'};
			$alt.="<span>$properties->[4]</span>" if $variables->{'statCols'}->{'calcLogRatio'};
			$alt.="<span>$properties->[5]</span>" if $variables->{'statCols'}->{'normGrowthRatio'};
			if ($variables->{'statCols'}->{'normRatio'}){
				$alt.="<span>".sprintf("%.3f", (split/::/,$ratio)[0])."::".sprintf("%.3f", (split/::/,$ratio)[1])."</span>";
				if($ratios && $ratios ne ""){$alt.="<span>$ratios</span>";$labelTags.="<label>Normalized Ratio(s) from other conditions:</label>";}
			}

			$alt="$alphabet[$j]$i - $properties->[0]<br/><div class=a>$labelTags</div><div class=b>$alt</div>";
		#	if($properties->[1] ne '-'){$alt="$properties->[1] - $properties->[0]<br/>$alt";}
		#	else{$alt="$properties->[0]<br/>$alt";}
			#$alt="$properties->[0]<br/>$alt";
			# need to strip out quotes, otherwise function calls do not work
			# probably should strip out other stuff as well for security
			$alt=~ tr/"//d; # strip out double quotes
			$alt=~ tr/'//d; # strip out single quotes

			$onOff="off"; # initialize to not selected
			$highlightCheck=''; # initialize to not selected
			if($selected_sets->{$plate}->{$query}->{$condition}->{"$alphabet[$j]$i"}){ # if this set has been selected
				$highlightCheck='style="background-color:blue;"';  # assign the appropriate css
				if($condition ne '' && $condition ne '-'){ # and based on the value of $c, append to the visible and non-visible lists of selected sets
					$chosen_sets.="~~>$plate~$query~$condition~$alphabet[$j]$i";
					$sets.="<li>$query, $plate, $condition, $alphabet[$j]$i</li>";
				}
				else{
					$sets.="<li>$query, $plate, $alphabet[$j]$i</li>";
					$chosen_sets.="~~>$plate~$query~-~$alphabet[$j]$i";
				}
				$onOff="on" # $onOff now set to 'on' to indicate to the javascript that this set is selected.
			}
			# if this is a blank spot on the plate label it as such
			if($blank_flag){
				print "<li style=\"width:".($css_span).";\" class=\"$alphabet[$j]$i\"><em class='bl'></em><b class='bl'></b><span> </span><a> </a><div>$alphabet[$j]$i - $alt</div></li>\n";
			}
			# if this set has been marked for exclusion, highlight it in green
			elsif($exclude_flag){print "<li onclick=\"AddRemoveSets(this, 'p".(scalar(@platesDisplayed)-1)."');\" style=\"width:".($css_span).";\" id=\"p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i:$onOff\" class=\"$alphabet[$j]$i\"><em $highlightCheck class='ex'></em><b $highlightCheck class='ex'></b><span id=\"SPAN-p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i\"></span><a id=\"A-p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i\"></a><div>$alt</div></li>\n";}
			# if both the control and experimental plates are 'dead' at this position, highlight it orange
			elsif($dead_flag){print "<li onclick=\"AddRemoveSets(this, 'p".(scalar(@platesDisplayed)-1)."');\" style=\"width:".($css_span).";\" id=\"p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i:$onOff\" class=\"$alphabet[$j]$i\"><em class='de' $highlightCheck></em><b class='de' $highlightCheck></b><span id=\"SPAN-p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i\"></span><a id=\"A-p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i\"></a><div>$alt</div></li>\n";}
			# if p-value is less then the p-value threshold highlight it red
			elsif(is_numeric($pval) && $pval<=$variables->{'pthresh'}->{$query}->{$condition}){print "<li onclick=\"AddRemoveSets(this, 'p".(scalar(@platesDisplayed)-1)."');\" style=\"width:".($css_span).";\" id=\"p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i:$onOff\" class=\"$alphabet[$j]$i\"><em class='sig' $highlightCheck></em><b class='sig' $highlightCheck></b><span id=\"SPAN-p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i\"></span><a id=\"A-p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i\"></a><div>$alt</div></li>\n";}
			# else we are in the normal condition so no highlighting
			else{print "<li  onclick=\"AddRemoveSets(this, 'p".(scalar(@platesDisplayed)-1)."');\" style=\"width:".($css_span).";\" id=\"p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i:$onOff\" class=\"$alphabet[$j]$i\"><em class='ok' $highlightCheck></em><b class='ok' $highlightCheck></b><span id=\"SPAN-p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i\"></span><a id=\"A-p".(scalar(@platesDisplayed)-1)."-$alphabet[$j]$i\"></a><div>$alt</div></li>\n";}
		}
	}
	print '</ul>';
	if($variables->{'processing_choice'} eq 'pictures'){
		if($condition eq "" || $condition eq "-"){print "<h3 style=\"text-align:center;\">$variables->{'control'}, $plate</h3></th>\n";}
		else{print "<h3 style=\"text-align:center;\">$variables->{'control'}, $plate, $condition</center></h3></th>\n";}
		print "<th>\n";
		print "</div>\n";
		print "<img src=\"${$data_plate->{$plate}->{$query}->{$condition}}\"  width=\"$variables->{'imageX'}\" height=\"$variables->{'imageY'}\" />\n";
		if($condition eq "" || $condition eq "-"){print "<h3 style=\"text-align:center;\">$query, $plate</h3></th>\n";}
		else{print "<h3 style=\"text-align:center;padding:2px;background:#CFD7FF;\">$query, $plate, $condition</center></h3></th>\n";}
		print "</tr>\n";
	}
	else{
		print '</th><th valign=top>';
		print &printComparisonCartoon($data_plate->{$plate}->{$query}->{$condition}->[0], $variables, $plate, $query, $condition, $normalization_values->{$plate}->{$query}->{$condition});
	}
	print '
	</div></th></tr></table>';
}

$current_page++;

eval {store($variables, "$variables->{'save_directory'}/variables.dat")};
if($@){ die 'Serious error from Storable, storing %variables: '.$@.'\n';}
my $submit;
unless($current_page == $variables->{'num_pages'}){ $submit = '<center><input type="submit" value="Next Plate" onclick="parent.setupFlash(true, \'Generating Comparison Cartoons...\');" /></center></form>';}
else{ $submit = '</form><br/>';}
$chosen_sets = $chosen_sets ? $chosen_sets : '';
print <<SELECTED_SETS;
<form name="imagelayout" action="$asset_prefix->{'base'}/cgi-bin/sv_engine/main.cgi" method="post" style ="clear:both;">
<input type="hidden" name="selected_sets" id="chosen_sets" value="$chosen_sets" />
<input type="hidden" id="current_page_displayed" name="current_page"  value="$current_page" />
$submit
<form name="generateOutput" id="generateOutput" action="$asset_prefix->{'base'}/cgi-bin/sv_engine/excelOutput.cgi" method="post" target="outputFileLink" style="display:inline;">
	<input type="hidden" name="selected_sets" id="chosen_sets1" value="" />
	<center><input type="submit" value="Click here to retrieve your selected colony sets" /></center><br/>
</form>
	</div>
	<div id="SummaryDiv" class="TopRightDiv" style="display:none;">
		<u onclick="this.parentNode.style.display='none';" style="color:blue;" class="sv_close"></u>
		<div id="SummaryHead" class="TopRightDivHead">Selected Sets</div>
		<div class="menu_content">
			<ul style="list-style-image: url($asset_prefix->{'images'}/css/arrow-bullet.png); color:black;" id="Visible_list">$sets</ul>
		</div>
	</div>
SELECTED_SETS

$count=0;
foreach my $plateInfo(@{$variables->{'plates_on_page'}->[($current_page-1)]}){
		my $pval;
		if($variables->{"pthresh"}->{$plateInfo->{query}}->{$plateInfo->{condition}} < 0.00001){
			$pval= sprintf('%.3e',$variables->{"pthresh"}->{$plateInfo->{query}}->{$plateInfo->{condition}});
		}
		else{$pval=sprintf('%.3g',$variables->{"pthresh"}->{$plateInfo->{query}}->{$plateInfo->{condition}});}
		$plateInfo->{condition} = '' if !defined ($plateInfo->{condition});
		my $plateLabel = $variables->{'originalData'}->{$plateInfo->{plateNum}}->{$plateInfo->{query}}->{$plateInfo->{condition}};

		my $printPlateInfo = $plateLabel->{query};
		if($plateInfo->{condition} ne ''){
			$printPlateInfo.= ', '.$plateLabel->{condition};
		}
		my $html = '';
		foreach my $plate(sort {$a<=>$b} keys %{$variables->{'hit_list'}->{$plateInfo->{query}}->{$plateInfo->{condition}}}){
			$html .= $variables->{'hit_list'}->{$plateInfo->{query}}->{$plateInfo->{condition}}->{$plate};
		}
print <<MENUITEM;
		<div id="hitListDiv-p$count" class="TopRightDiv" style="display:none;">
			<u onclick="this.parentNode.style.display='none';" style="color:blue;float:right;" class="sv_close"></u>
			<div id="hitListDivHead" class="TopRightDivHead" style="font-size:1.0em;">
				$printPlateInfo<br/>
		  	P-value < $pval <br/> <small>&rArr; Identifier (Plate - Position)</small>
			</div>
			<div class="menu_content">
				<ul>
					$html
				</ul>
			</div>
		</div>
MENUITEM
	$count++;
}


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
my $html = 'var plateIndices = $.parseJSON(\''.$json->encode(\%platesDisplayed).'\');
						var plateIndicesRev = $.parseJSON(\''.$json->encode(\%platesDisplayedHash).'\');';
print <<OUTPUT;
	<br/><br/><br/><br/><br/><br/>
</div><iframe name="outputFileLink" style="border:0px solid black;width:0px;height:0px;"></iframe>
<script type="text/javascript">
$html
</script>
<br/><br/></body></html>
OUTPUT
