#!/usr/bin/perl -w

BEGIN {
	$|++;
	# this code will print errors to a log file
	my $log;
	use CGI::Carp qw(carpout);
	open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}

# useful Perl commands
	# my $username = getpwuid( $< );
	# warn $username; # user currently executing the perl script
	# use Cwd;
	# warn "current dir = ".getcwd;

############################## Cutoff Linked to Interaction Knowledge #########################
#
#
#
#
#use diagnostics;
use strict; # use strict warnings
use clikModule qw(:clik); # use my module and only load routines in analysis
use Modules::ScreenAnalysis qw(:clik); # use my module and only load routines in analysis
use Benchmark; # bench mark running time -> used for debugging
use lib '/home/rothstei/perl5/lib/perl5';
&setupCLIK();

my $size_limit = 10;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 10 MB limit
my %variables;
unless(&initialize($q, $size_limit)){&exitProgram("Issue uploading your data. Please ensure that you are uploading a text file with a .txt file extension.<br/>");}
unless(&validateUser(\%variables,$q,0)){&exitProgram("Error validating your user credentials please logout and back-in to the Rothstein Lab website and try again.<br/>", "Error validating user credentials". __FILE__." line ".__LINE__);} # validate user

my $asset_prefix = &static_asset_path();

# temporary directory where we will store stuff
# set $variables{'base_save_directory'} and $variables{'base_dir'}
&getBaseDirInfo(\%variables, 'clik', $q, 'noFlash');

#$variables{'base_upload_dir'} = "$variables{'base_upload_dir'}/images";
# generate user specific directories

my $t = &directory_setup(\%variables, $q, 'noFlash');

if(!defined $t || !defined $variables{'save_directory'} || $variables{'user'} !~ /^[0-9]+$/){
	&exitProgram("Error setting up temporary files. ".&try_again_or_contact_admin(), $variables{'save_directory'}.' --> '. __FILE__.' line '.__LINE__);
}
# set user session
if(!&setSession('clik', \%variables, $q, 0) ){
	&exitProgram("Error setting user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), "Could not set user session $! --> $variables{'save_directory'}");
}
$q->{'.header_printed'}=1;

$variables{'imageDir'} = "../temp/images";
&verifyDir($q, $variables{'imageDir'});
$variables{'imageDir'} = "../temp/images/$variables{'user'}/";
&verifyDir($q, $variables{'imageDir'});

# check if we are creating a custom clik group
if(defined($q->param('custom')) && $q->param('custom') eq 'true' ){
	&calcCustomCLIK(\%variables);
	exit(0);
}

# check if we are calculating the stats for a clik group
if(defined($q->param('orderedGroupStats')) && $q->param('orderedGroupStats') eq 'true' ){
	&calculateCLIKgroupStats(\%variables);
	exit(0);
}

# check if we are calculating the stats for a random clik group
if(defined($q->param('randomStats')) && $q->param('randomStats') eq 'true' ){
	my $randomBench = new Benchmark;
	#&calcRandomORFStats(\%variables);
	&calcRandomGraphStats(\%variables);
	#&calcRandomGraphStatsNew(\%variables);
	my $endRandom = new Benchmark;
	# warn "Time taken to do random stuff was ", timestr(timediff($endRandom, $randomBench), 'all'), " seconds";
	exit(0);
}

if(my $pid = fork){
	print $q->header();
	print "so far, so good"; # need this line - the js on the clik webpage looks for this to ensure everything is running as expected.
}
else{
	BEGIN {
		# this code will print errors to a log file
		my $log;
		$|++;
		use CGI::Carp qw(carpout);
		open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
		carpout($log);
	}
	use strict; # use strict warnings
	use clikModule qw(:clik); # use my module and only load routines in analysis

	if(!$q->param("sessionID")){&exitProgram("No data uploaded", 'No data uploaded --> '. __FILE__.' line '.__LINE__);}
	elsif($q->param("sessionID") =~ /\W/g){&exitProgram("Bad session please try again or logout and log back in", 'Bad session--> '. __FILE__.' line '.__LINE__);}

	# ********************************************************************************************************
	# ********************************************************************************************************
	# GLOBAL VARIABLE DECLARATIONS (see clikModule.pm)
	# ********************************************************************************************************
	# ********************************************************************************************************
	my $graphData = &gData();
	$graphData->{'authenticity_token'} = $q->param('authenticity_token');
	($graphData->{'imageDir'},$graphData->{'imageDirCount'}) = &generateUserDir("../temp/images/$variables{'user'}/");
	$graphData->{'dirNumber'} = $variables{'dirNumber'};

	$graphData->{'dataDir'} = $variables{'save_directory'};
	$graphData->{'imageBase'} = $asset_prefix->{'base'};
	$graphData->{'imageDownloadDir'} = "$graphData->{'imageBase'}/cgi-bin/download.cgi?dir1=$variables{'user'}&dir2=$graphData->{'imageDirCount'}";

	my $inputData = &inputData();

	my $organismInfo = &organismInfo();

	# ********************************************************************************************************
	# ********************************************************************************************************
	# END GLOBAL VARIABLE DECLARATIONS
	# ********************************************************************************************************

	my $head =<<HEAD;
	<html>
	 	<head>
		<!-- <script src="//ajax.googleapis.com/ajax/libs/jquery/1.8.3/jquery.min.js"></script> -->
		<script src='$asset_prefix->{'javascripts'}/jquery.min.js' type='text/javascript'></script>
		<script src='$asset_prefix->{'javascripts'}/convertORFsJQ.js' type='text/javascript'></script>
		<script src='$asset_prefix->{'javascripts'}/public/commonJQ.js' type='text/javascript'></script>
		<script src='$asset_prefix->{'javascripts'}/clik/clik.js' type='text/javascript'></script>
		<script src="$asset_prefix->{'javascripts'}/clik/Event.js" type="text/javascript" ></script>
		<script src="$asset_prefix->{'javascripts'}/clik/Magnifier.js" type="text/javascript" ></script>
		<script src='$asset_prefix->{'javascripts'}/validationJQ.js' type='text/javascript'></script>
		<link href='$asset_prefix->{'stylesheets'}/validation.css' media='screen' rel='Stylesheet' type='text/css' />
		<link href='$asset_prefix->{'stylesheets'}/field_hints.css' media='screen' rel='Stylesheet' type='text/css' />
		<link href='$asset_prefix->{'stylesheets'}/public/tags.css' media='screen' rel='Stylesheet' type='text/css' />
		<link href='$asset_prefix->{'stylesheets'}/clik/clik.css' media='screen' rel='Stylesheet' type='text/css' />
		<link  href="$asset_prefix->{'stylesheets'}/clik/magnifier.css" rel="stylesheet" type="text/css">
		<style type="text/css">
			.error{color: #FF3300;font-weight: bold;padding: 5px;}
			.href{color:blue; text-decoration:underline;cursor:pointer;}
HEAD


	my $preStart = new Benchmark;
	# ********************************************************************************
	# ********************************************************************************
	###################  PROCESS  AND VALIDATE INPUT FROM WEB FORM ###################
	# ********************************************************************************
	# ********************************************************************************

	# rankData is a hash with the following Keys:
	# 'orderedORFnames'=> an array with the index corresponds to rank and values are ORFs names
	# 'orderedValues'=> an array containing the values associated with each ORF
	# 'ranksOfORFs'=> a hash with ORFs as keys and their corresponding ordered rank values as....values
	# 'randomRankOfORFs'=> same as above but with randomly assigned ranks
	&progressHook(0, "Uploading input data");

	my $rankData =	&processInputData($organismInfo, $graphData, $inputData);

	my %outputs;

	my $start = new Benchmark;
	#warn "Time taken to load data was ", timestr(timediff($start, $preStart), 'all'), " seconds";
	my $benchmarkData = "<br/>Time taken to load data was ". timestr(timediff($start, $preStart), 'all'). " seconds<br/>";

	&progressHook(10, "Calculating Interaction matrix");
	# ********************************************************************************
	# ********************************************************************************
	############################## END GET INPUT FROM WEB FORM #######################
	# ********************************************************************************
	# ********************************************************************************

	# figure out interactions among ranked orfs
	# interaction count is a data structure in which the final value of each key is a count
	# it contains the following keys
	# 			$interactionCounts{'sources'}->{$source}
	#													counts the number of times a particular source was found in the bioGrid file
	# 			$interactionCounts{'orfs'}->{$interactorA}->{$interactorB}->{$interactionType}->{$source}
	#													counts the number of times a particular A to B interaction was found in the bioGrid file,
	#													also hold the interaction type and source data for a given interaction
	# 			$interactionCounts->{'systems'}->{$system}
	#													counts the number of times a particular system, aka interaction type, was found in the bioGrid file
	my ($interactionCounts, $trimInfo, $interactionTypeMsg) = &calculateInteractions($inputData, $rankData, $organismInfo);

	if(! defined $interactionCounts->{'orfs'} || keys %{$interactionCounts->{'orfs'}} == 0){&exitProgram("NO GENES FOUND WITHIN YOUR DATASET!!!! NO GRAPH GENERATED!", "no interactions found.". __FILE__.' line '.__LINE__);}
	$graphData->{'minMembers'} = $rankData->{'size'}**0.5/2;
	if($inputData->{'binWidth'} eq 'auto'){
		&progressHook(20, "Estimating optimal bin size");
		my $roi = &calculateMaxROI($rankData,$interactionCounts);
		my $fileEndName = '_clikGraph'.$inputData->{'binWidth'}.'bw.png';
		&progressHook(25, "Refining optimal bin size.");
		$inputData->{'binWidth'} = sprintf("%.2f",&refineROI($rankData,$interactionCounts, $roi));
		my $newFileEndName = '_clikGraph'.$inputData->{'binWidth'}.'bw.png';
		$graphData->{'imageFileName'} =~ s/$fileEndName/$newFileEndName/;
	}
	my $one = new Benchmark;
	$benchmarkData .= "<br/>Time taken to Calculating Interaction matrix (calculateInteractions) was ". timestr(timediff($one, $start), 'all'). " seconds<br/>";


	# initialize graph
	# imageScaler = amount to divide plot points by to scale the image to the appropriate size
	if($rankData->{'size'} > $graphData->{'maxPlotWidth'}){$graphData->{'imageScaler'} = ($rankData->{'size'} / $graphData->{'maxPlotWidth'});}
	elsif($rankData->{'size'} < $graphData->{'minPlotWidth'}){$graphData->{'imageScaler'} = ($rankData->{'size'} / $graphData->{'minPlotWidth'});}
	#$graphData->{'imageScaler'}=1;
	$graphData->{'plotWidth'}   = $rankData->{'size'} / $graphData->{'imageScaler'};
	$graphData->{'imageWidth'}  = $graphData->{'plotWidth'}+$graphData->{'leftBorderOffset'};
	$graphData->{'imageHeight'} = $graphData->{'plotWidth'}+$graphData->{'bottomBorderOffset'}+$graphData->{'topBorderOffset'};
	$graphData->{'imgObject'}   = GD::Simple->new($graphData->{'imageWidth'}+1,$graphData->{'imageHeight'});
	# done initializing graph


	# determine x and y coordinates of scatter-plot
	# plot data is a hash with the following keys:
	#			$plotData->{'numberOfBins'} == total number of data bins possible
	#			$plotData->{'binWidth'} == width of each bin --> note that $inputData->{'binWidth'} contains user input value for binWidth but this is only an approximation
	#																	in order to divide the plot evenly (i.e. there is an integer value for the number of bins that divide up the plot area) this
	#																	value will be altered slightly and stored in $plotData->{'binWidth'}
	#			$plotData->{'halfWidth'} == 50% of binWidth
	#			$plotData->{'binArea'} == area of bins
	#			$plotData->{'plotPoints'}->{$bin}->{'x'} == an array with all of the x plot point values in the current bin
	#			$plotData->{'plotPoints'}->{$bin}->{'y'} == an array with all of the corresponding y plot point values in the current bin
	#			$plotData->{'plotPoints'}->{$bin}->{'count'} == a scalar containing the total number of data in the current bin
	# 		$plotData->{'randomPlotPoints'}->{$bin}->{'x'} == same as above but with randomized data
	#			$plotData->{'randomPlotPoints'}->{$bin}->{'y'} == same as above but with randomized data
	#			$plotData->{'randomPlotPoints'}->{$bin}->{'count'} == a scalar containing the total number of data in the current bin
	#			$interactionCounts->{'totalInteractions'} == total number of interactions in the dataset
	&progressHook(30, "Calculating Plot Points");
	my $plotData = &calculatePlotPoints($interactionCounts, $rankData, $inputData,$graphData);
	if($interactionCounts->{'totalInteractions'} < 1){
		&exitProgram("NO INTERACTIONS FOUND WITHIN YOUR DATASET!!!! NO GRAPH GENERATED!");
	}
	$trimInfo =~ s/\n/<br\/\>/gi; # replace unix line breaks with html

	# ********************************************************
	# START DETERMINING DATA POINT DENSITIES / PLOTTING

	# calculate density of each point by determining the number of data points within its immediate vicinity
	# do this by centering a virtual bin over a given point and determining the amount of data within it
	#
	# densityValues is a hash with the following info:
	#						$densityValues->{'ordered'}->{$curX}->{$curY} == an array containing all the density values at a given x and y value
	#																														used density as the first key so we can easily sort by density later
	#						$densityValues->{'orderedDenMax'} == maximum density calculated from ordered data
	#						$densityValues->{'randomDenMax'} == maximum density calculated from random data
	#						$densityValues->{'orderedMean'} == mean of all densities calculated for ordered data
	#						$densityValues->{'randomMean'} == mean of all densities calculated for ordered data
	#						$densityValues->{'orderedStdDev'} == stdDev of all densities calculated for ordered data
	#						$densityValues->{'randomStdDev'} == stdDev of all densities calculated for ordered data
	#			Note that the line that calculated the following data was commented out of the calculatePointDensity function:
	#						$densityValues->{'random'}->{$density}->{$curX} == same as above but for random

	&progressHook(40, "Calculating point densities");
	my $densityValues = &calculatePointDensity($inputData, $interactionCounts, $rankData, $plotData, $graphData);

	# END DETERMINING DATA POINT DENSITIES
	# ********************************************************

	my $stats .= <<OUT;
	<hr/>
	<div style='font-size:1.2em;' id='clikContainer'><div id='generalClikInfoContainer'>
	<div id='generalClikInfo'>
	$interactionTypeMsg
	<strong>Note: You may hover over any identifier with your mouse cursor to learn its rank [if 'noise reduction' occurred, ranks have been recalculated to account for the missing gene(s)].</strong><br/><br/>
	$trimInfo
	Number of genes considered: $rankData->{'size'}<br/>
	Number of interactions: $interactionCounts->{'totalInteractions'}<br/>
	Number of bins = $plotData->{'numberOfBins'} <br/>
OUT
	$stats.="Number of bins containing data (interactions): ";
	$stats.=scalar(keys %{$plotData->{'plotPoints'}});
	$stats.= "<br/>Organization bin width (obw): ";
	$stats.= sprintf("%.2f",$plotData->{'binWidth'});
	$stats.= "<br/>Point density area [(obw*2)^2]: ";
	$stats.= sprintf("%.2f",$plotData->{'binArea'});
	$stats .= "<br/>95th percentile value = ";
	$stats .= sprintf("%.5f", $densityValues->{'densityCorrection'});
	$stats .= " (any bin with a density > than this value is considered significant.)</div>";
	my $midpoint1 = new Benchmark;
	# calculate difference, report
	#warn "Time taken for 1st loop was ", timestr(timediff($midpoint1, $start), 'all'), " seconds";
	$benchmarkData .= "<br/>Time taken for 1st loop (calculatePlotPoints) was ". timestr(timediff($midpoint1, $one), 'all'). " seconds<br/>";


	my $percentagePerBin = (($densityValues->{'orderedDenMax'}*$plotData->{'binArea'}) / $interactionCounts->{'totalInteractions'}) * 100;
	$stats .= "<div class='orderedRandomStats'>";
	$stats .= "<b><u>Ordered</u></b> maximum density: ";
	$stats .= sprintf("%.4f", $densityValues->{'orderedDenMax'});
	$stats .= ", # interactions <b>";
	$stats .= sprintf("%.2f", ($densityValues->{'orderedDenMax'}*$plotData->{'binArea'}));
	$stats .= "</b>, % of data: ";
	$stats .= sprintf("%.3f", $percentagePerBin);
	$stats .= "%<br/>Ordered mean: ";
	$stats .= sprintf("%.5f", $densityValues->{'orderedMean'});
	$stats .= "<br/>Ordered standard deviation: ";
	$stats .= sprintf("%.5f",$densityValues->{'orderedStdDev'});
	#$stats .= "<br/># of interactions in 'significant' bins: $densityValues->{'orderedDenCount'}";

	$percentagePerBin = (($densityValues->{'randomDenMax'}*$plotData->{'binArea'}) / $interactionCounts->{'totalInteractions'}) * 100;
	$stats .= "</div><div class='orderedRandomStats'><b><u>Random</u></b> maximum density ";
	$stats .= sprintf("%.4f", $densityValues->{'randomDenMax'});
	$stats .= ", # interactions <b>";
	$stats .= sprintf("%.3f", ($densityValues->{'randomDenMax'}*$plotData->{'binArea'}));
	$stats .= "</b>, % of data: ";
	$stats .= sprintf("%.3f", $percentagePerBin);
	$stats .= "%<br/>Random mean: ";
	$stats .= sprintf("%.5f", $densityValues->{'randomMean'});
	$stats .= "<br/>Random standard deviation: ";
	$stats .= sprintf("%.5f", $densityValues->{'randomStdDev'});
	#$stats .= "<br/># of interactions in 'significant' bins: $densityValues->{'randomDenCount'}";
	$stats.="</div></div><br/>";


	my $midpoint2 = new Benchmark;
	# calculate difference, report
	#warn "Time taken for 2nd loop was ", timestr(timediff($midpoint2, $midpoint1), 'all'), " seconds";
	$benchmarkData .= "<br/>Time taken for 2nd loop (calculatePointDensity) was ". timestr(timediff($midpoint2, $midpoint1), 'all'). " seconds";

	# need to store density values prior to next sub routine, as it is iterated over in a destructive manner.
	eval{Storable::store($densityValues, "$graphData->{'dataDir'}/densityValues.dat")};
	if($@){	&exitProgram("Problem storing CLIK data. Please contact the administrator.", "Serious error from Storable storing densityValues.dat: $@");	}

	# initialize image
	# ********************************************************
	# START PLOTTING DATA POINTS!!!

	&progressHook(80, "Plotting 2d Histogram");
	my ($output, $fhOutput, $minDensity, $scaler, $clikGroupsDefined, $bm) = &plot2dHistogram($graphData, $rankData, $densityValues, $interactionCounts, $plotData, $inputData, $variables{'dirNumber'});

	eval{Storable::store($graphData, "$graphData->{'dataDir'}/graphData.dat")};
	if($@){	&exitProgram("Problem storing CLIK data. Please contact the administrator.", "Serious error from Storable storing graphData.dat: $@");	}

	eval{Storable::store($inputData, "$graphData->{'dataDir'}/inputData.dat")};
	if($@){	&exitProgram("Problem storing CLIK data. Please contact the administrator.", "Serious error from Storable storing inputData.dat: $@");	}

	$rankData->{'geneDisplaySub'}=undef;
	eval{Storable::store($rankData, "$graphData->{'dataDir'}/rankData.dat")};
	if($@){	&exitProgram("Problem storing CLIK data. Please contact the administrator.", "Serious error from Storable storing rankData.dat: $@");	}

	eval{Storable::store($interactionCounts, "$graphData->{'dataDir'}/interactionCounts.dat")};
	if($@){	&exitProgram("Problem storing CLIK data. Please contact the administrator.", "Serious error from Storable storing interactionCounts.dat: $@");	}

	eval{Storable::store($plotData, "$graphData->{'dataDir'}/plotData.dat")};
	if($@){	&exitProgram("Problem storing CLIK data. Please contact the administrator.", "Serious error from Storable storing plotData.dat: $@");	}

	$plotData=(); # clear plot data

	$densityValues=(); # clear out densityValues
	# dones

	my $midpoint3 = new Benchmark;
	# calculate difference, report
	#warn "Time taken for 3rd loop was ", timestr(timediff($midpoint3, $midpoint2), 'all'), " seconds";
	$benchmarkData .= "<br/>Time taken for 3rd loop (plot2dHistogram) was ". timestr(timediff($midpoint3, $midpoint2), 'all'). " seconds $bm";


	# plot graph axes
	&progressHook(90, "Printing CLIK Graph");
	&printGraphAxis($rankData, $graphData);
	my $size = $rankData->{'size'}; # needed for &printImage
	my $organism = $rankData->{'organism'};
	$rankData=undef;

	my $midpoint4 = new Benchmark;
	# calculate difference, report
	#warn "Time taken for 4th loop was ", timestr(timediff($midpoint4, $midpoint3), 'all'), " seconds";
	$benchmarkData .= "<br/>Time taken for 4th loop was ". timestr(timediff($midpoint4, $midpoint3), 'all'). " seconds";
	$stats .= "<br/><a href=\"$graphData->{'imageDownloadDir'}&file=".CGI::escape("$graphData->{'imageFileName'}")."\" class='ext_link'>Download Image</a><br/>";
#	$stats .= "<a href=\"/$asset_prefix->{'base'}/cgi-bin/download.cgi?dir1=$variables{'user'}&dir2=$graphData->{'imageDirCount'}&file=".CGI::escape("$graphData->{'imageFileName'}-CLIK_groups.txt")."\" class='ext_link'>Download CLIK group data</a><br/><br/>";


	# my $zip = Archive::Zip->new();
	# # Add a file from disk
	# my $file_member = $zip->addFile( "$graphData->{'imageDir'}$graphData->{'imageFileName'}-orderedDensities.txt", "$graphData->{'imageFileName'}-orderedDensities.txt" );
	# $file_member = $zip->addFile( "$graphData->{'imageDir'}$graphData->{'imageFileName'}-randomDensities.txt", "$graphData->{'imageFileName'}-randomDensities.txt" );
	# # Save the Zip file
	# unless ( $zip->writeToFileNamed("$graphData->{'imageDir'}$graphData->{'imageFileName'}-densities.zip") == AZ_OK ) {
	# 	&exitProgram('There was an issue generating your output files, please try again later.', 'zip file write error'. __FILE__.' line '.__LINE__);
	# }
	# $stats .=  "<a href=\"download.cgi?ID=".CGI::escape("$variables{'user'}/$graphData->{'imageFileName'}-densities.zip")."\" class='ext_link'>Download Point Density Data (random and ordered)</a><br/>";
	# unlink "$graphData->{'imageDir'}$graphData->{'imageFileName'}-orderedDensities.txt";
	# unlink "$graphData->{'imageDir'}$graphData->{'imageFileName'}-randomDensities.txt";

	#my $zip1 = Archive::Zip->new();
	# Add a file from disk
	#my $file_member1 = $zip1->addFile( "$graphData->{'imageDir'}$graphData->{'imageFileName'}-orderedPlotBinData.txt", "$graphData->{'imageFileName'}-orderedPlotBinData.txt" );
	#$file_member1 = $zip1->addFile( "$graphData->{'imageDir'}$graphData->{'imageFileName'}-randomPlotBinData.txt", "$graphData->{'imageFileName'}-randomPlotBinData.txt" );
	# Save the Zip file
	# unless ( $zip1->writeToFileNamed("$graphData->{'imageDir'}$graphData->{'imageFileName'}-binCounts.zip") == AZ_OK ) {
	# 	&exitProgram('There was an issue generating your output files, please try again later.', 'zip file write error'. __FILE__.' line '.__LINE__);
	# }
	# $stats .=  "<a href=\"download.cgi?ID=".CGI::escape("$variables{'user'}/$graphData->{'imageFileName'}-binCounts.zip")."\" class='ext_link'>Download bin counts (random and ordered)</a><br/><br/>";
	# unlink "$graphData->{'imageDir'}$graphData->{'imageFileName'}-orderedPlotBinData.txt";
	# unlink "$graphData->{'imageDir'}$graphData->{'imageFileName'}-randomPlotBinData.txt";

	# print out graph legend
	$stats .=  "<br/><strong><div style='clear:both;float:left;width:880px'><div style='float:left;'><---- Fewer interactions</div><div style='float:right;'>More interactions ----></div></div></strong><br style='clear:both' />";

	$stats .=  "<span title='".sprintf('%.3f',$minDensity)."' class='key $graphData->{'orderedColor'}->[1] first'></span>";
	for(my $i=2; $i<@{$graphData->{'orderedColor'}}-1; $i++){
		$stats .=  "<span title='".sprintf('%.3f',($minDensity+($scaler*($i-1))))."' class='key $graphData->{'orderedColor'}->[$i]'></span>";
	}
	$stats .=  "<span title='".sprintf('%.3f',($minDensity+($scaler*(@{$graphData->{'orderedColor'}}-2))))."' class='key $graphData->{'orderedColor'}->[@{$graphData->{'orderedColor'}}-1] last'></span>";

	$stats .= '<br/><br/>';
	# print image
	$stats .= &printImage($graphData, $size);


	$stats .= &printCustomCLIKenrichmentForm($variables{'dirNumber'}, $inputData->{'numberOfBootStraps'}, $organism);


	$head .= &overlayClikData($graphData);
	$head .= "</style></head><body>";
	# warn Dumper(\%sigValues);
	# end timer

	$stats =~ s/\n+//gi;
	$stats.= "\n<br style='clear:both;'/><div style='margin-top:20px;'>";
	if($clikGroupsDefined){
		$stats.= "<button onclick=\"\$('.lightgray').toggle();calcHeight();\">Click me to toggle display of gray elements below</button><br/><br/>";
	}
	$stats.= "\n<button onclick=\"\$('#allORFs').toggle();calcHeight();\">Click me to toggle view of the rank order list inputted</button><br/><br/>";
	if($organism =~ /cerevisiae/i){
		$stats.= "\n<button onclick=\"orfsToGeneNames();\">Click me to convert ORFs to Gene Names</button><br/><br/>\n";
	}
	$stats.= '</div>';

	my $midpoint5 = new Benchmark;
	# calculate difference, report
	#warn "Time taken for 5th loop was ", timestr(timediff($midpoint5, $midpoint4), 'all'), " seconds";
	$benchmarkData .= "<br/>Time taken for 5th loop (printing graph to browser) was ". timestr(timediff($midpoint5, $midpoint4), 'all'). " seconds";

	my $end = new Benchmark;
	# calculate difference, report
	#warn "Time taken for entire program was ", timestr(timediff($end, $start), 'all'), " seconds";
	$benchmarkData .= "<br/>Time taken for entire program was ". timestr(timediff($end, $start), 'all'). " seconds";

	$output = "$head $stats $output $benchmarkData '</div></html>";

	my $fh;
	open ($fh, ">$graphData->{'imageDir'}$graphData->{'imageFileName'}-CLIK_groups.txt") || die "could not open clik group output file: $!";
	print $fh $fhOutput;
	$stats =~ s/\<br\/\>/\n/gi; # replace html line breaks with unix
	$stats =~ s/\<[A-Z]\>|\<\/[A-Z]\>//gi; # strip out simple html tags
	print $fh $stats;
	close $fh;
  # warn "$variables{'user'}/$graphData->{'imageDirCount'}";
	&progressHook("$variables{'user'}/$graphData->{'imageDirCount'}", "printToBrowserExit:$output");

	exit(0);


	###################################################################################################
	#                                     END OF MAIN
	###################################################################################################

	###################################################################################################
	#                                     SUBROUTINES - IN ALPHABETICAL ORDER
	###################################################################################################

	# process input data....
	sub processInputData{
		my ($organismInfo, $gData, $iData) = @_;

		my $inputLog='';
		my $errorLog='';
		# what organism are we dealing with?

		$iData->{'organismInteractionInfo'} = $q->param('organism') ? $q->param('organism') : 'n/a' ;
		if(! defined $organismInfo->{$iData->{'organismInteractionInfo'}}){
			$errorLog .= "Illegal organism selected. You selected $iData->{'organismInteractionInfo'}, acceptable organisms are listed below:<br/>";
			foreach(sort keys %{$organismInfo}){
				$_ =~ s/_/ /gi;
				$_=ucfirst($_);
				$errorLog .= "<i>$_</i><br/>";
			}
			&exitProgram($errorLog, "Wrong organism entered: $iData->{'organismInteractionInfo'} ". __FILE__." line ".__LINE__);
		}

		#	data set label for the image - this will replace the initial file name
		$gData->{'dataSetLabel'} = $q->param('dataSetLabel');
		# strip out spaces
		if($gData->{'dataSetLabel'}){
			$gData->{'dataSetLabel'}=~s/^\s+//;
			$gData->{'dataSetLabel'}=~s/\s+$//;
		}
		else{$gData->{'dataSetLabel'}='';}

		my ($inputFileName,$rankData);

		my $organism = $organismInfo->{$iData->{'organismInteractionInfo'}}->{'shortName'};
		# if using human, figure out the type of gene id the user inputted.
		if($organism =~ /hsapien/i){
			$iData->{'geneIDformat'}= $q->param('idType');
			unless($iData->{'geneIDformat'} eq 'ensembl' || $iData->{'geneIDformat'} eq 'geneName'){&exitProgram("Invalid input for gene id!");}
		}

		# give president to manually entered lists...if both are present only list will be used
		# also, only accept manually entered lists for organisms other than Scerevisiae
		if($q->param('ids') || $organism !~ /cerevisiae/i){
			if(!$q->param('ids')){&exitProgram("You must enter gene ids into the box labeled 'Input your own'");}

			$inputFileName = 'rankList';
			my $orfListInfo;

			# split data, remove blanks and anything less than 3 characters or greater than 20
			my @data = grep{/^[A-Za-z0-9]{3,20}$/} (split(/\015\012|\r+|\012+|\n+|,\s+|\s+|\s+\|\s+|\|/ , uc($q->param('ids')) ));
			if(defined $iData->{'geneIDformat'} && $iData->{'geneIDformat'} ne 'ensembl' && $iData->{'organismInteractionInfo'} =~ /preppi/i){
				($rankData, $orfListInfo) = &convertHumanORFsToEnsembl(\@data, $iData->{'geneIDformat'});
			}
			else{
				($rankData, $orfListInfo) = &readORF_list(\@data, $organismInfo->{$iData->{'organismInteractionInfo'}});
			}
			$inputLog .= $orfListInfo;
		}
		# else assume it is screenMill file
		elsif($q->param('millFile')){
			$inputFileName = $q->param('millFile');
			my $sortBy = lc($q->param('sortBy'));
			if($sortBy ne 'z-score' && $sortBy ne 'p-value' ){$sortBy = 'z-score';}
			my $conditionCombo = defined($q->param('conditionCombo')) ? lc($q->param('conditionCombo')) : '';
			my $orfListInfo;
			($rankData, $orfListInfo) = &readSceenMillFile($inputFileName, $sortBy, $conditionCombo);
			# if $orfListInfo eq 'combosFound' more than 1 query-condition combo was found and we need to ask the user
			# which one they would like to analyze - if this is the case combo data is stored in $rankData
			if($orfListInfo eq 'combosFound'){&progressHook(0, "combos:".join(":", keys %{$rankData})); exit;	}
			$inputFileName =~m/^.*(\\|\/)(.*)/; # strip the remote path and keep the filename
			#if($gData->{'dataSetLabel'} ne ''){$inputFileName = "$gData->{'dataSetLabel'}_$inputFileName";}
			$inputFileName =~ s/\.+|\s+|\++|\&+|\*+|\^+|\%+|\$+|\#+|\@+|\?+|\!+|\\+|\/+/_/g; # replace special characters with underscores
			$inputLog .= "$orfListInfo<br/>Input filename = $inputFileName<br/><br/>";
			$gData->{'xLabel'} = 'Z-Score';
		}
		else{	&exitProgram("You must input some data!");	}

		$rankData->{'organism'} = $organism;

		&setupORFoutputSub($rankData);

		# check for minimum number of ORFS
		if(scalar(@{$rankData->{'orderedORFnames'}}) <= $iData->{'minNumberOfORFs'}){
			&exitProgram("Too few valid identifiers (genes) in dataset to properly analyze ( < $iData->{'minNumberOfORFs'} valid identifiers found)!", "Too few valid identifiers in dataset to properly analyze ( < $iData->{'minNumberOfORFs'} valid identifiers found)!");
		}
		# make sure we do not have TOOOOO much data to analyze
		if(scalar(@{$rankData->{'orderedORFnames'}}) > $iData->{'maxAmountOfData'}){
			&exitProgram("Too much data to analyze. You can analyze a maximum of $iData->{'maxAmountOfData'} items (you entered ".scalar(@{$rankData->{'orderedORFnames'}}).").", "Too much data to analyze. You can analyze a maximum of $iData->{'maxAmountOfData'} items (you entered ".scalar(@{$rankData->{'orderedORFnames'}}).").");
		}

		# OUTPUT FILENAME...
		$gData->{'imageFileName'}=$inputFileName;
		# load in to %interactionToConsider the interaction the user selected on the previous page that they would like to consider in their data analysis
		my $interactionCount=0;

		# expSystemType == is the interaction type (e.g. genetic or physical)
		# warn Dumper $q;
		#
		# check if we are using data from BioGRID, if so, load acceptable interaction choices
		my $useBioGrid = 0;

		my $acceptableInteractions = ();

		foreach my $db(@{$organismInfo->{$iData->{'organismInteractionInfo'}}->{'useThese'}}){
			# should only be one database type that has multiple sources of interaction data, so this
			# if statement should be run at max 1 time.
			if($organismInfo->{$db}->{'dataBaseType'} =~ /biogrid|droidb/i){
				$acceptableInteractions = &acceptableInteractions($organismInfo->{$db}->{'dataDir'}, $organismInfo->{$db}->{'shortName'});
				foreach my $expSysType(keys %{$acceptableInteractions}){
					if($q->param($expSysType)){
						foreach($q->param($expSysType)){
							if(defined $acceptableInteractions->{uc($expSysType)}->{uc($_)}){
								$interactionCount++;
								$iData->{'interactionsToConsider'}->{uc($expSysType)}->{uc($_)}=$acceptableInteractions->{uc($expSysType)}->{uc($_)};
							}
						}
					}
				}
			}
			# every other dataset has, basically, only 1 type of interaction
			else{$interactionCount++;}
		}
		$iData->{'interactionsToConsiderCount'} = $interactionCount;
		if($interactionCount < 1){	&exitProgram("You must select at least one valid interaction type using the check boxes above.");	}

		#	ensure promiscuousCutoff is a valid positive integer...
		$iData->{'promiscuousCutoff'}= $q->param('promiscuousCutoff');
		unless($iData->{'promiscuousCutoff'} =~/^(0)$|^([1-9][0-9]*)$/){&exitProgram("Invalid input for promiscuous cutoff!");}
		$gData->{'imageFileName'} .= "_NR$iData->{'promiscuousCutoff'}";

		#	ensure numberOfBootStraps is a valid positive integer...
		$iData->{'numberOfBootStraps'} = 0;
		if(defined $q->param('networkConnectionsBS') && $q->param('networkConnectionsBS') eq 'yes'){
			$iData->{'numberOfBootStraps'} = &validatePositiveIntCGI('numBootStrapping', '# to bootstrap');
		}

		$iData->{'complexDataset'}=0;
		if(defined $q->param('complexData') && $q->param('networkConnectionsBS') eq 'complexData'){
			#	ensure complexDataset is a valid, if it does not eq benschop it will default to baryshnikova...
			if(defined $q->param('complexDataset')){
				$iData->{'complexDataset'} = $q->param('complexDataset');
				$iData->{'complexDataset'} = 'baryshnikova' if($iData->{'complexDataset'} ne 'benschop');
			}
		}

		#	enable automatic noise reduction?
		$iData->{'interactionNormalization'}= $q->param('interactionNormalization');
		if(!$iData->{'interactionNormalization'} || $iData->{'interactionNormalization'} != 1){$iData->{'interactionNormalization'}=0;}
		else{$gData->{'imageFileName'} .= "_autoNR";}

		# enable multiple evidence multiplication
		$iData->{'accumulateScores'}= $q->param('accumulateScores');
		if(!$iData->{'accumulateScores'} || $iData->{'accumulateScores'} != 1){$iData->{'accumulateScores'}=0;}
		else{$gData->{'imageFileName'} .= "_multiEvidence";}

		# should we consider data as is?
		#	should we only count reciprocal interactions? (i.e. only count interaction if A->B and B->A exists)
		#	should we force all interaction to be reciprocal (i.e. if A -> B then B -> A)
		if($q->param('reciprocal')){
			if($q->param('reciprocal') eq 'asIs'){
				$iData->{'reciprocal'}=0;
				$iData->{'forceReciprocal'}=0;
			}
			elsif($q->param('reciprocal') eq 'forceRecip'){
				$iData->{'reciprocal'}=0;
				$iData->{'forceReciprocal'}=1;
				$gData->{'imageFileName'} .= "_fRecip";
			}
			elsif($q->param('reciprocal') eq 'onlyRecip'){
				$iData->{'reciprocal'}=1;
				$iData->{'forceReciprocal'}=0;
				$gData->{'imageFileName'} .= "_onlyReciprocal";
			}
			else{&exitProgram("Invalid reciprocal parameter value. Acceptable values are: 'asIs', 'forceRecip', or 'onlyRecip'");}
		}
		else{&exitProgram("Could not find reciprocal parameter.");}

		#	should we use a permutation test to determine CLIK group significance?
		$iData->{'permutation'} = $q->param('permutation');
		if(!$iData->{'permutation'} || $iData->{'permutation'} != 1){$iData->{'permutation'}=0;}

		$iData->{'autoScaleDensityColors'} = $q->param('scaleDensity');
		$iData->{'startScale'} = 0;
		$iData->{'endScale'} = 0;
		if($iData->{'autoScaleDensityColors'} eq 'no' && defined $q->param('startScale') && defined $q->param('endScale')){
			$iData->{'startScale'} = $q->param('startScale');
			$iData->{'endScale'} = $q->param('endScale');
			unless($iData->{'startScale'} =~/^[-+]?[0-9]+(\.[0-9]+)?$/ && $iData->{'startScale'} =~/^[-+]?[0-9]+(\.[0-9]+)?$/){
				&exitProgram("Invalid input for start and end density scaling values! Values must be valid decimal numbers.");
			}
		}
		else{	$iData->{'autoScaleDensityColors'} = 'yes';	}

		#	should we count some interactions higher than others if they exist multiple times in the database
		# $iData->{'accumulateScores'} = $q->param('accumulateScores');
		# if(!$iData->{'accumulateScores'} || $iData->{'accumulateScores'} != 1){$iData->{'accumulateScores'}=0;}
		# else{$gData->{'imageFileName'} .= "_accumulateScores";}
		# ********************************************************************************************************

		$gData->{'imageFileName'} .= '_'.$organismInfo->{$iData->{'organismInteractionInfo'}}->{'dataBaseType'};

		#	ensure binWidth is a valid positive integer...
		$iData->{'binWidth'} = $q->param('binWidth');
		unless($iData->{'binWidth'} =~/^(0)$|^([1-9][0-9]*)$/ || $iData->{'binWidth'} eq 'auto'){&exitProgram("Invalid input for binWidth!", $iData->{'binWidth'}.' --> '. __FILE__.' line '.__LINE__);}
		if($iData->{'binWidth'} ne 'auto'){$iData->{'binWidth'} = $iData->{'binWidth'} / 2;}
		$gData->{'imageFileName'}.="_".$iData->{'binWidth'}.'bw.png';

		return $rankData;
	}

	sub generateUserDir{
		my ($baseDir) = @_;
		unless(-d $baseDir){
			# find out what we can name this new directory (by figure out what is already there, or not there)
			eval{mkdir($baseDir, 0755) || die "Could not create directory $baseDir: $!";};
			if($@){
				use Cwd;
				my $cwd = cwd();
				&exitProgram("Problem creating user directory. Please contact the administrator.", "$@. Current dir = $cwd.");
			}
		}
		unlink(<../temp/*.html>);
		unlink(<../temp/images/error/*.html>);
		opendir(DIR, "$baseDir/");
		my @files = grep {
											-d "$baseDir/$_"  # is a directory
											&&	!/^\./	# does not begin with a period
											} readdir(DIR);
		close DIR;
		foreach my $file(@files){
			# remove directories older than 5 days...
			if(-M "$baseDir/$file" > 5){
				rmdir "$baseDir/$file";
			}
		}

		my $count = scalar(@files);
		my $limit=100;
		COUNTER:while(-d "$baseDir$count"){
			$count++;$limit--;
			if($limit<0){&exitProgram("Problem creating user directory. Please contact the administrator.", "Can't find valid image directory!");	}
		}
		$baseDir.="$count/";
		eval{mkdir($baseDir, 0755) || die "Could not create directory $baseDir: $!";};
		if($@){&exitProgram("Problem creating user directory. Please contact the administrator.", "$@");	}

		return ($baseDir,$count);

	}
	# SUB ROUTINES NOT CURRENTLY IN USE:
	################################### NOISE REDUCTION I : noisy query interactions A -> #
	#
	#
	# sub removeCasualEncounters {
	# 	my $interactionsHashRef = shift;
	# 	my $rankedORFsListRef = shift;
	# 	my $cutoff = shift;
	# 	my %encounterHash = ();
	# 	my @valueList = ();
	# 	#open (my $DEBUG, ">debug.txt") || die "could not open the debug file for writing\n";
	#
	# 	foreach my $A (@{$rankedORFsListRef}) {#   A's ->
	# 		#print "$A\t";
	# 		my $count = scalar keys %{${$interactionsHashRef}{$A}};
	# 		if ($count > $cutoff) {
	# 			$encounterHash{$A} = $count;  # put size of list into hash of ORFs in list
	# 			delete $interactionsHashRef->{$A};
	# 			#print $DEBUG "$A\t$count\n";
	# 		}
	# 	} # end foreac
	# #	close $DEBUG;
	# }
	#
	#
	# ################################### NOISE REDUCTION II : noisy queries & reciprocals
	# #															A -> #,  # -> A
	# #
	# sub scrubCasualEncounters {
	# 	my $interactionsHashRef = shift;
	# 	my $rankedORFsListRef = shift;
	# 	my $cutoff = shift;
	# 	my %encounterHash = ();
	# 	my @valueList = ();
	# 	#open (my $DEBUG, ">debug.txt") || die "could not open the debug file for writing\n";
	#
	# 	###  First run through BIOGRID hash structure is to ID and remove noisy queries.
	# 	###  Query IDs are then used in second pass to remove interactions where the noisy
	# 	###  ORF is detected as the 'B' ORF in an A->B pair
	#
	# 	foreach my $A (@{$rankedORFsListRef}) {#   A's ->
	# 		#print "$A\t";
	# 		my $count = scalar keys %{${$interactionsHashRef}{$A}};
	# 		if ($count > $cutoff) {
	# 			$encounterHash{$A} = $count;  # put size of list into hash of ORFs in list
	# 			delete $interactionsHashRef->{$A};
	# 			#print $DEBUG "$A\t$count\n";
	# 		}
	# 	} # end foreach
	#
	# 	###  Second level of noise reduction
	# 	foreach my $A (keys %{$interactionsHashRef}) {
	# 		foreach my $B (keys %{$interactionsHashRef->{$A}}) {
	# 			if ($encounterHash{$B}) {	delete $interactionsHashRef ->{$A} ->{$B};	}
	# 		} # end foreach
	# 	} # end foreach
	#
	# 	#close $DEBUG;
	# }
	#
	#
	# ################################### NOISE REDUCTION III : remove noisy ORFs from ordered list
	# #
	# #
	# sub listNoisyQueries {
	# 	my $interactionsHashRef = shift;
	# 	my $cutoff = shift;
	# 	my %encounterHash = ();
	# 	foreach my $A (keys %$interactionsHashRef) {
	# 		my $count = scalar keys %{${$interactionsHashRef}{$A}};
	# 		if ($count > $cutoff) {$encounterHash{$A} = $count;	}
	# 	}
	# 	return \%encounterHash;
	# }
	#
	#
	#
	#
	# # returns file from ftp site...1st argument = file location, 2nd=short file name, 3rd = what to do if file is not found (if this == die, kill program else just set error message)
	# sub getFile{
	# 	my $url=shift;
	# 	my $short=shift;
	# 	my $should_i_die=shift;
		# my @months = qw(Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);
		# my ($second, $minute, $hour, $dayOfMonth, $month, $yearOffset, $dayOfWeek, $dayOfYear, $daylightSavings) = localtime();
		# my $year = 1900 + $yearOffset;
		# $month++;

		# # GO feature file
		# my %GOdata = ('url' => 'http://downloads.yeastgenome.org/chromosomal_feature/SGD_features.tab',
		# 							'ageBeforeUpdate' => '7', # age, in days between local copy of file and one of FTP site before we update the local copy
		# 							'ORFindex' => '10', # there may be multiple items in this column, separated by '|', the ORF is the first
		# 							'aspectIndex' => '8'
		# 						);
	# 	my ($content);
	# 	# begin retrieving file
	# 	print "Downloading file from $url...\n";
	# 	unless(defined ($content=get($url))){
	# 		# file could not be retrieved from FTP address...
	# 		if($should_i_die eq "die"){
	# 			send_result("Error retrieving $url\n");
	# 			die "Error retrieving $url. $!\n";
	# 		}
	# 		else{print "Error retrieving $url --> will not update info from this file.\n";}
	# 		return undef;
	# 	}
	# 	print "$short downloaded successfully!!!\n\n";
	# 	return($content);
	# 	# could also split here and return reference to resulting array....
	# }
	#
	#
	# sub drawDataBins{
	# 	my ($img, $numberofBinRows, $binWidth) = @_;
	# 	$img->bgcolor(undef);
	# 	$img->penSize(1);
	# 	for(my $i=0;$i<10000;$i++){
	# 		my $x1 =(int($i/$numberofBinRows)*$binWidth);
	# 		my $y1 = ($i%$numberofBinRows)*$binWidth;
	# 		my $x2 =$x1+$binWidth;
	# 		my $y2 = $y1+$binWidth;
	# 		#warn "bin = $i -- $x1,$y1 -- $x2,$y2 -- mod = ".($i%$numberofBinRows)."\n";
	# 		$img->fgcolor('black');
	# 		$img->rectangle($x1,$y1,$x2,$y2);
	# 		$img->moveTo($x1,$y1);
	# 		$img->fgcolor('red');
	# 		$img->string($i);
	# 	}
	# }



	################################### TRAVERSE_SUM
	#
	# 	This subroutine recursively follows a complex data structure and sums the values
	# 	it finds in any arrays or hashes that it encounters. Hash or array limbs to a
	# 	data tree are detected by a ref call, but other refs (CODE, GLOB, SCALAR & REF)
	# 	are ignored.  May want to build in handling of scalars at some point. This borrows
	# 	heavily from Data::Dumper - but I could not figure out how to make Data::Dumper do the
	# 	same job.
	#
	# sub traverse_sum {
	# #	print "@_\n";
	# 	my $y=shift;
	# 	my @list;
	# 	my $sum;
	#
	# 	if (ref $y eq 'HASH') {
	# 		@list = keys (%{$y});
	# 		foreach my $element (@list) {
	#
	# 			if (ref $y->{$element})  {	$sum += traverse_sum ($y->{$element});	}
	# 			elsif (looks_like_number($y->{$element})) {	$sum += $y->{$element};	} # else it is not a ref or a number
	# 		} # end foreach
	# 	} #end if
	#
	# 	elsif (ref $y eq 'ARRAY') {
	# 		@list = @{$y};
	# 		foreach my $element (@list) {
	# 			if (ref $element) {	$sum += traverse_sum ($element);	}
	# 			elsif (looks_like_number($element)) {	$sum += $element;		}
	# 		} # end foreach
	# 	} # end elsif
	#
	# 	return $sum;
	# } # end sub
	#
	#
	#
	#
	#
	# # Calculates the kernel density estimate (probability density function) at x
	# sub gauss_pdf {
	#   my ( $pointA,  $pointB, $width ) = @_;
	#   my $z = &eDistance($pointA->[0],$pointA->[1],$pointB->[0],$pointB->[1])/$width;
	#   return exp(-0.5*$z*$z)/( $width*sqrt( 2.0*3.14159265358979323846 ) );
	# }
	#
	#
	#
	# # function : eDistance
	# # inputs:
	# # x1,y1 -> one coordinate
	# # x2,y2 -> another coordinate
	# # returns:
	# # Euclidean distance between 2 points
	# # purpose:
	# # calculates Euclidean distance between 2 Cartesian coordinates
	# sub eDistance{
	# 	my ($x1,$y1,$x2,$y2) = @_;
	# 	return sqrt( ($x1-$x2)**2+($y1-$y2)**2);
	# }
	#
	#
	#
	#
	#
	# sub default_bandwidth {
	#   my ( $self ) = @_;
	# 	# sum_cnt = sum of the weights, can assume equal weights and give this a value of 1 by default.
	# 	# sum x = sum of positions times their weights
	# 	# sum x2 = sum of positions**2 times their weights
	#   if( $self->{sum_cnt} == 0 ) { return undef; }
	#
	#   my $x  = $self->{sum_x}/$self->{sum_cnt};
	#   my $x2 = $self->{sum_x2}/$self->{sum_cnt};
	#   my $sigma = sqrt( $x2 - $x**2 );
	#
	#   # This is the optimal bandwidth if the point distribution is Gaussian.
	#   # (Applied Smoothing Techniques for Data Analysis
	#   # by Adrian W, Bowman & Adelchi Azzalini (1997)) */
	#   return $sigma * ( (3.0*$self->{sum_cnt}/4.0)**(-1.0/5.0) );
	# }



	# sub splice_2D {
	# 	my ($two_dArray, $x_lo, $x_hi, $y_lo, $y_hi) = @_;
	# 	return map {[ @{ $two_dArray->[$_] } [ $y_lo .. $y_hi ] ]} $x_lo .. $x_hi;
	# }
	#
	#


	# ################################### MIN
	# #
	# #
	# sub min{
	# 	my($a,$b)=@_;
	# 	if($a<$b){return $a;}
	# 	return $b;
	# }
	exit(0);
}
exit(0);

