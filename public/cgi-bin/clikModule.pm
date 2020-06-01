# FOR INTERNAL ANCHORS TO WORK
# determine top position of iFrame
# determine top position of anchor relative to iFrame
# add values together, use scrollTo function

package clikModule;
use strict;
use base qw(Exporter);
use lib '/home/rothstei/perl5/lib/perl5';
#use Data::Dumper; # used for debugging
use Benchmark; # bench mark running time -> used for debugging
use LWP::Simple qw(get); # needed to retrieve website,  would love to use this to download biogrid files...
use Storable qw(store retrieve); # to store / retrieve data structures on disk
use GD::Simple; # for graphics stuff
use Archive::Zip qw( :ERROR_CODES :CONSTANTS ); # required to create zip files
use File::Find; # for managing temp files
use CGI qw(:standard); # web stuff

our @EXPORT = qw( $q gData acceptableInteractions organismInfo inputData trimNoisyItems validateGoodTextFile calcRandomORFStats
									trimErroneousCharacters exitProgram fisher_yates_shuffle cum_hyperg_pval_info readSceenMillFile calcRandomGraphStats
									readORF_list printImage printAxis printGraphAxis plot2dHistogram overlayClikData
									line_break_check calculatePointDensity bookkeeper calculateInteractions refineROI setupORFoutputSub
									calculatePlotPoints bootStrapToClikGroup progressHook calculateWindowInteractionDensity calculateMaxROI
									calculateCLIKgroupStats validatePositiveIntCGI calcRandomGraphStatsNew convertHumanORFsToEnsembl); # access these using 'use Modules::clikModule'
our @EXPORT_OK = qw(gData acceptableInteractions organismInfo inputData trimNoisyItems validateGoodTextFile calcRandomORFStats
										trimErroneousCharacters exitProgram fisher_yates_shuffle cum_hyperg_pval_info readSceenMillFile calcRandomGraphStats
										readORF_list printCustomCLIKenrichmentForm printImage printAxis printGraphAxis plot2dHistogram overlayClikData
										calcCustomCLIK saveStructures loadStructures line_break_check setupORFoutputSub
										calculatePointDensity bookkeeper calculateInteractions calculatePlotPoints setupCLIK bootStrapToClikGroup progressHook
										calculateCLIKgroupStats validatePositiveIntCGI calcRandomGraphStatsNew convertHumanORFsToEnsembl);
our %EXPORT_TAGS = (	all	=>	[ @EXPORT, @EXPORT_OK ],
											clik => [@EXPORT, qw(setupCLIK printCustomCLIKenrichmentForm calcCustomCLIK saveStructures loadStructures)],
											clikCLI => [@EXPORT],
        						);

# ********************************************************************************************************
# ********************************************************************************************************
# GLOBAL VARIABLE DECLARATIONS
# ********************************************************************************************************
# ********************************************************************************************************
$|=1; # flush buffer output after each statement --> this is required to prevent truncated data being returned - particularly from ajax calls
our $q;
our $lb = "\n"; # define linebreak character

my $RELATIVE_ROOT="tools"; # could probably grab the environmental variable RAILS_RELATIVE_URL_ROOT

sub gData{
	my %graphData = (
			'xLabel' => undef,
			'yLabel' =>undef,
			'imageDir' => "",
			'dataDir' => "",
			'topBorderOffset' => 26,
			'bottomBorderOffset' => 66,
			'leftBorderOffset' => 26,
			'minPlotWidth' => 600,
			'maxPlotWidth' => 800,
			'imageWidth' => 0,
			'imageHeight' => 0,
			'plotWidth' => 0, # plot area is square so the plot height == plotWidth
			'imageZoomFactor' => 4,
			'zoomTickSpacing' => 20,
			'zoomTickHeight' => 50,
			'orderedColor' => ['chartreuse', 'chartreuse', 'aquamarine', 'darkturquoise','dodgerblue','blue','blueviolet','magenta','mediumvioletred','red','firebrick','darkred', 'black'],
			'orderedSizeMultiplier' => [1, 1,1,1.5,2,2.5,3,3.5,4,4.5,5,5.5,6,6.5],
			'randomColors' => ['lightgrey','lightgrey','lightgrey','lightgrey','lightgrey'], # 'lightgrey', 'silver','darkgray', 'gray'
			'imageScaler' =>1,
			'randomPlotPointMultiplier' => 1.0,
			'randomPlotPointSize' => 2,
			'orderedPlotPointMultiplier' =>1.1,
			'printToBrowser' => 1,
			'numberTicks' => 15,
			'tickSize' => 5,
			'minMembers' => 10, # minimum number of members that an enrichment group needs to have in order to be considered an enrichment group
			'enrichmentGroupBuffer' => 0, # if 2 enrichment groups are 'enrichmentGroupBuffer' distance between one another, combine them
			'significanceThreshold' => 90, # densities above this percentile from random will be considered significant
			'imgObject' => GD::Simple->new(2,2) # for some reason the GD module was throwing an error in the printGraph function when I changed colors unless I initiated an image here
	);
	# set default image width & height
	$graphData{'imageWidth'} = $graphData{'maxPlotWidth'} + $graphData{'leftBorderOffset'};
	$graphData{'imageHeight'} = $graphData{'maxPlotWidth'} + $graphData{'topBorderOffset'} + $graphData{'bottomBorderOffset'};
	$graphData{'imgObject'}->bgcolor('red');
	$graphData{'orderedColorPositions'} = &orderedColorPositions(\%graphData);
	return \%graphData;
}

sub ucwords {join $_[1], map ucfirst lc, split /\Q$_[1]\E/, $_[0], -1;}

sub orderedColorPositions{
	my $graphData = shift;
	my $colorTable = GD::Simple->color_names;

	my %rgbColorPositions;
	for(my $i = 0; $i < @{$graphData->{'orderedColor'}}; $i++){
		if(defined $colorTable->{$graphData->{'orderedColor'}->[$i]}){
			my $t = join(",",@{$colorTable->{$graphData->{'orderedColor'}->[$i]}});
			$rgbColorPositions{$t} = $i;
		}
	}
	return \%rgbColorPositions;
}

sub acceptableInteractions{
	my ($db, $source) = @_;
	my $ITYPES;
	$source = lc($source);
	eval{open($ITYPES, "<interactionData/$db/$source\_interactionTypes.txt") or die "interactionData/$db/$source\_interactionTypes.txt.  $!";};
	if($@){&exitProgram("An error occurred, :( please try again later.", $@);}
	$/ = line_break_check( $ITYPES );
	my %acceptableInteractions=();
	while(<$ITYPES>){
		chomp;
		my @data = split /\:/;
		$data[1] =~ s/^\s+//; #remove leading spaces
		$data[1] =~ s/\s+$//; #remove trailing spaces
		$acceptableInteractions{uc($data[0])}->{uc($data[1])}=$data[1];
	}
	close $ITYPES;
	return \%acceptableInteractions;
}

sub organismInfo{
	my %organismInfo=(
		'saccharomyces_cerevisiae_biogrid' => {
			'useThese' => ['saccharomyces_cerevisiae_biogrid'],
			'shortName' => 'Scerevisiae',
			'ORFregex' => '^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$',
			'dataBaseType' => 'BioGRID',
			'dataDir' => 'BioGRID'
		},
		'saccharomyces_cerevisiae_goProcess' => {
			'useThese' => ['saccharomyces_cerevisiae_goProcess'],
			'shortName' => 'Scerevisiae',
			'ORFregex' => '^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$',
			'dataBaseType' => 'GO',
			'dataDir' => 'geneOntology/Scerevisiae',
			'GOAspect' => ['P']
		},
		'saccharomyces_cerevisiae_goFunction' => {
			'useThese' => ['saccharomyces_cerevisiae_goFunction'],
			'shortName' => 'Scerevisiae',
			'ORFregex' => '^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$',
			'dataBaseType' => 'GO',
			'dataDir' => 'geneOntology/Scerevisiae',
			'GOAspect' => ['F']
		},
		'saccharomyces_cerevisiae_goComponent' => {
			'useThese' => ['saccharomyces_cerevisiae_goComponent'],
			'shortName' => 'Scerevisiae',
			'ORFregex' => '^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$',
			'dataBaseType' => 'GO',
			'dataDir' => 'geneOntology/Scerevisiae',
			'GOAspect' => ['C']
		},
		'saccharomyces_cerevisiae_fnet' => {
			'useThese' => ['saccharomyces_cerevisiae_fnet'],
			'shortName' => 'Scerevisiae',
			'ORFregex' => '^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$',
			'dataBaseType' => 'Functional Network',
			'dataDir' => 'functionalNetwork'
		},
		'saccharomyces_cerevisiae_fnetANDbioGrid' => {
			'useThese' => ['saccharomyces_cerevisiae_biogrid', 'saccharomyces_cerevisiae_fnet'],
			'dataBaseType' => 'functionalnetworkAndBioGrid',
			'ORFregex' => '^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$',
			'shortName' => 'Scerevisiae'
		},
		'saccharomyces_cerevisiae_preppi' => {
			'useThese' => ['saccharomyces_cerevisiae_preppi'],
			'shortName' => 'Scerevisiae',
			'ORFregex' => '^[Y|y][A-Pa-p][L|R|l|r][0-9]{3}[W|w|C|c](?:-[A-Za-z])?$',
			'dataBaseType' => 'PrePPI',
			'dataDir' => 'preppi',
			'scoreThreshold' => 100
		},
		'c_elegans_fnet' => {
			'useThese' => ['c_elegans_fnet'],
			'shortName' => 'c_elegans',
			'ORFregex' => '.',
			'dataBaseType' => 'Functional Network',
			'dataDir' => 'functionalNetwork'
		},
		'homo_sapien_biogrid' => {
			'useThese' => ['homo_sapien_biogrid'],
			'shortName' => 'hsapien',
			'ORFregex' => '.',
			'dataBaseType' => 'BioGRID',
			'dataDir' => 'BioGRID'
		},
		'homo_sapien_preppi' => {
			'useThese' => ['homo_sapien_preppi'],
			'shortName' => 'Hsapien',
			'ORFregex' => '.',
			'dataBaseType' => 'PrePPI',
			'dataDir' => 'preppi',
			'scoreThreshold' => 600
		},
		# 'homo_sapien_biogrid_preppi' => {
		# 	'useThese' => ['homo_sapien_preppi','homo_sapien_biogrid'],
		# 	'shortName' => 'Hsapien',
		# 	'ORFregex' => '.',
		# 	'dataBaseType' => 'BioGRIDandpreppi',
		# 	'dataDir' => 'preppi'
		# },
		'mus_musculus'	 => {
			'useThese' => ['mus_musculus'],
			'shortName' => 'Mmusculus',
			'ORFregex' => '.',
			'dataBaseType' => 'BioGRID',
			'dataDir' => 'BioGRID'
		},
		'schizosaccharomyces_pombe_biogrid' => {
			'useThese' => ['schizosaccharomyces_pombe_biogrid'],
			'shortName' => 'Spombe',
			'ORFregex' => '.',
			'dataBaseType' => 'BioGRID',
			'dataDir' => 'BioGRID'
		},
		'schizosaccharomyces_pombe_goAll' => {
			'useThese' => ['schizosaccharomyces_pombe_goAll'],
			'shortName' => 'Spombe',
			'ORFregex' => '.',
			'dataBaseType' => 'GO',
			'dataDir' => 'geneOntology/Spombe',
			'GOAspect' => ['C','F','P']
		},
		'schizosaccharomyces_pombe_goProcess' => {
			'useThese' => ['schizosaccharomyces_pombe_goProcess'],
			'shortName' => 'Spombe',
			'ORFregex' => '.',
			'dataBaseType' => 'GO',
			'dataDir' => 'geneOntology/Spombe',
			'GOAspect' => ['P']
		},
		'schizosaccharomyces_pombe_goFunction' => {
			'useThese' => ['schizosaccharomyces_pombe_goFunction'],
			'shortName' => 'Spombe',
			'ORFregex' => '.',
			'dataBaseType' => 'GO',
			'dataDir' => 'geneOntology/Spombe',
			'GOAspect' => ['F']
		},
		'schizosaccharomyces_pombe_goComponent' => {
			'useThese' => ['schizosaccharomyces_pombe_goComponent'],
			'shortName' => 'Spombe',
			'ORFregex' => '.',
			'dataBaseType' => 'GO',
			'dataDir' => 'geneOntology/Spombe',
			'GOAspect' => ['C']
		},
		'schizosaccharomyces_pombe_go_and_biogrid' => {
			'useThese' => ['schizosaccharomyces_pombe_goProcess', 'schizosaccharomyces_pombe_biogrid'],
			'dataBaseType' => 'bioBRIDandGO',
			'ORFregex' => '.',
			'shortName' => 'Spombe'
		},
		'drosophila_melanogaster_biogrid'  => {
			'useThese' => ['drosophila_melanogaster_biogrid'],
			'shortName' => 'Dmelanogaster',
			'ORFregex' => 'CG[0-9]{1,5}$',
			'dataBaseType' => 'BioGRID',
			'dataDir' => 'BioGRID'
		},
		'd_melanogaster_droidb' => {
			'useThese' => ['d_melanogaster_droidb'],
			'dataBaseType' => 'droiDB',
			'dataDir' => 'droiDB',
			'ORFregex' => '.',
			'shortName' => 'Dmelanogaster'
		}
	);
	return \%organismInfo;
}

sub inputData{
	# setup default values
	my %inputData = (
		 'organismInteractionInfo' => 'saccharomyces_cerevisiae',
		 'interactionsToConsider' => {}, #{'probabilisticfunctionalgenenetwork' => 1},
		 'promiscuousCutoff' => 400,
		 'maxAmountOfData' => 50000,
		 'minNumberOfORFs' => 100,
		 'interactionNormalization' => 0,
		 'accumulateScores' => 0,
		 'reciprocal' => 0,
		 'numberOfBootStraps' => '100'
	);
	return \%inputData;
}

#some dumb ass variables for John's subroutines - don't even think about moving them!
our %nk;
our %LNfact;
our $pi = atan2(1,1)*4; # value needed for Stirling's approximation of factorials
our @fact = (0,0,0.693147180559945,1.791759469228055,3.178053830347946,4.787491742782046,6.579251212010101,8.525161361065415,
							 10.60460290274525,12.80182748008147,15.10441257307552,17.50230784587389,19.98721449566188,22.55216385312342,
							 25.19122118273868,27.89927138384089,30.6718743941422, 33.5050860689909, 36.3954564338402, 39.3398942384233,
							42.335625512472, 45.3801470926379); # A list of factorial values of their respective reference nu


# ********************************************************************************************************
# ********************************************************************************************************
# END GLOBAL VARIABLE DECLARATIONS
# ********************************************************************************************************
# ********************************************************************************************************

# Delete out files that have been abandoned (i.e. have not been modified) for greater than 1 day
sub bookkeeper {
	my $dir=$_[0];
	if(-d $dir){ # ignore subversion repos
		opendir (DH,"$dir");
		my $file;
		while ($file = readdir DH) {
			# the next if line below will allow us to only consider files with extensions
			#next if ($file =~ /^\./);
			#warn -M "$dir/$file";
			if(-d "$dir/$file"){rmdir("$dir/$file");} # rmdir will remove any empty directories
			elsif (-M "$dir/$file" > 0.2) {unlink "$dir/$file";}
		}
	}
}

sub gene_conversion_file{
	my $shortName = shift;
	if($shortName =~ /cerevisiae/i){
		return "../../data/key_file_data/sgd_genes.dat";
	}
	return 0;
}

sub performComplexBootStrapping{
	my ($orfsAsHash, $rData, $complexDataset) = @_;
	my @completeEnrichment;
	my %complexHash;
	my %bootStrapMembersOf;
	my $clikSize = scalar(keys %{$orfsAsHash});
	my $complexOutput='';

	my $complexData = &loadComplexData($complexDataset);
	if(defined $complexData->{'error'}){return "$lb<b>No complex enrichment performed: $complexData->{'error'}</b>";}

	# build hash that only contains complexes that have ORFs in current CLIK group
	foreach my $orf(keys %{$orfsAsHash}){
		# if ORF is in a complex...
		if(defined $complexData->{'ids'}->{$orf}){
			# pull complexes that current ORF is a member of...
			foreach my $complex(keys %{$complexData->{'ids'}->{$orf}}){
				$complexHash{$complex}++;
			}
		}
	}
	foreach my $complex(keys %complexHash){
		my $sizeOfComplex = 0;
		my @membersNotInDataSet = ();
		my @inCLIK = ();
		my @inDatasetNotinCLIK = ();
		foreach my $orf(keys %{$complexData->{'complexes'}->{$complex}->{'orfs'}}){
			if(defined $rData->{'ranksOfORFs'}->{$orf}){
				if(defined $orfsAsHash->{$orf}){push(@inCLIK,$rData->{'geneDisplaySub'}->($orf,'hel','','') );}
				else{push(@inDatasetNotinCLIK,$rData->{'geneDisplaySub'}->($orf,'hel','',''));}
				$sizeOfComplex++;
			}
			else{push(@membersNotInDataSet,$rData->{'geneDisplaySub'}->($orf,'hel','',''));}
		}
		my $membersInClik = scalar(@inCLIK);
		my ($complexEnrichment, $enrichment) = (1,1);
		($complexEnrichment, $enrichment) = &cum_hyperg_pval_info($membersInClik, $sizeOfComplex, $clikSize, $rData->{'size'}) if $membersInClik > 0;
		if($complexEnrichment <= 0.05 && $complexEnrichment ne 'under-represented'){
			$complexEnrichment = &prettyPrintNumber($complexEnrichment);
			my $notInDataset='';
			if(scalar(@membersNotInDataSet)>0){
				$notInDataset = "<li style='color:red;'>".scalar(@membersNotInDataSet)." members not in dataset:<ul><li>".join(', ', @membersNotInDataSet)."</li></ul></li>";
			}
			if($sizeOfComplex == $membersInClik){
				my $temp = "<span style='color:blue;'><b>$complex -- P-Value = $complexEnrichment</b></span><ul><li style='color:green;'>$sizeOfComplex member(s) in this CLIK group:<ul><li>".join(", ", @inCLIK)."</li></ul></li>";
				push (@completeEnrichment, "$temp\ $notInDataset</ul>");
			}
			# if complex has significant enrichment within clik group then....
			elsif(@inDatasetNotinCLIK > 1){
				$bootStrapMembersOf{$complexEnrichment}->{$complex}->{'stats'} = "$membersInClik of $sizeOfComplex in CLIK group:<ul><li>".join(", ", @inCLIK)."</li></ul>";
				$bootStrapMembersOf{$complexEnrichment}->{$complex}->{'notInDataSet'} = $notInDataset;
				@{$bootStrapMembersOf{$complexEnrichment}->{$complex}->{'orfs'}} = @inDatasetNotinCLIK;
			}
		}
	}
	if(@completeEnrichment > 0){
		$complexOutput .= "$lb<b><u>All the members of the following complexes are in this CLIK group (excluding genes not present in dataset)";
		$complexOutput .= " and this was unlikely due to chance (i.e. p-value < 0.05)</u></b>$lb$lb<ul><li>";
		$complexOutput .= join("</li><li>",  @completeEnrichment);
		$complexOutput .= "</li></ul>";
	}
	if(scalar(keys %bootStrapMembersOf) > 0){
		$complexOutput .= $lb."<b><u>Based on the enrichment of complex members within this CLIK group, the following genes may be bootstrapped [complex name - (# in CLIK group <b style='color:green;'>OF</b> # members in complex)]</u></b>$lb$lb<ul>";
		foreach my $score(sort keys %bootStrapMembersOf){
			foreach my $complex(sort keys %{$bootStrapMembersOf{$score}}){
				$complexOutput .= "<li><span style='color:blue;'><b>$complex -- P-Value = $score</b></span><ul>";
				$complexOutput .= "<li style='color:blue'>$bootStrapMembersOf{$score}->{$complex}->{'stats'}</li>";
				$complexOutput .= "<li style='color:green;'>".scalar(@{$bootStrapMembersOf{$score}->{$complex}->{'orfs'}});
				$complexOutput .= " members not in CLIK group:<ul><li><span class='orf'>".join("</span>, <span class='orf'>", @{$bootStrapMembersOf{$score}->{$complex}->{'orfs'}})."</span></li></ul></li>";
				$complexOutput .= $bootStrapMembersOf{$score}->{$complex}->{'notInDataSet'};
				$complexOutput .= "</ul></li>";
			}
		}
		$complexOutput .= "</ul>$lb$lb";
	}
	return $complexOutput;
}


sub bootStrapToClikGroup{
	# bootstrapping if preformed by checking the number of connections a given ORF has to members of a CLIK group.
	# Currently it does not perform the converse (check the number of connections members of the CLIK group have to ORFs outside).
	# This effectively means that bootstrapping is performed uni-directional. This is to ensure that the statistics calculated
	# by the hypergeometric distribution are correct.
	my($clikORFs, $interactionsInNetwork, $iCounts, $rData, $iData, $gData, $seperateBy_iType) = @_;
	# check to see if we can bootstrap in any additional ORFs to CLIK group defined by the keys in the hash ref $clikORFs
	my %bootStrapped;
	my %sigBootstrapScore;
	# ORFs = ORFs in current CLIK group
	my $complexOutput = &performComplexBootStrapping($clikORFs, $rData, $iData->{'complexDataset'});

	my %sig_iTypes;

	# look at members not part of current clik group
	for(my $j=0; $j<$rData->{'size'}; $j++){
		my $A = $rData->{'orderedORFnames'}->[$j];
		# if this orf is not a member of the current CLIK group
		if(!defined $clikORFs->{$A}){
			# if this ORF has not already been bootstrapped (may occur if it occurs more than once in dataset)
			if(!$sigBootstrapScore{$A}){
				my %interactionHash=(); # temp structure to prevent duplicates
				# find all members of the CLIK group that this ORF is connected to
				foreach my $clikORF(keys %{$clikORFs}){
					# if we have not yet considered this ORF yet
					if(!defined $interactionHash{'all'}->{$clikORF}){
						# and if this $A iteracts with $cliKORF
						if(defined $iCounts->{'orfs'}->{$A}->{'interactor'}->{$clikORF}){
							# iterate over interaction types
							foreach my $expType(keys %{$iCounts->{'orfs'}->{$A}->{'interactor'}->{$clikORF}->{'iTypes'}}){
								foreach my $iType(keys %{$iCounts->{'orfs'}->{$A}->{'interactor'}->{$clikORF}->{'iTypes'}->{$expType}}){
									# separate by interaction type
									$interactionHash{'iTypes'}->{$expType}->{$iType}->{$clikORF}++;
								}
							}
							# all interaction types together -- add CLIK orf as key to prevent duplicate -- the key count will
							# provide the number of 'To CLIK group' interactions for $A
							$interactionHash{'all'}->{ $clikORF }++;
						}
					}
				}
				# now calculate significance of $A's interactions with CLIK group...first do for all
				{
					# number of edges that connect current ORF to other CLIK group members
					my $numberToClikInteractions = 0 + scalar(keys %{$interactionHash{'all'}});
					# number of interaction that this orf has with entire dataset...
					my $numInteractions = $iCounts->{'orfs'}->{$A}->{'numInteractions'}/scalar( @{$rData->{'ranksOfORFs'}->{$A}});
					my $totalNumInteractions = $numInteractions;
					my $iInNetwork = $interactionsInNetwork->{'all'} + $numberToClikInteractions;
					# determine if the interactions of the current ORF are over or under represented among its CLIK group members
					my ($orfInteractionRate, $enrichment) = (1,1);
					if($numberToClikInteractions > 0){
						($orfInteractionRate, $enrichment) = &cum_hyperg_pval_info($numberToClikInteractions, $totalNumInteractions, $iInNetwork, $iCounts->{'totalInteractions'});
					}
					# if ORF has significant enrichment then....
					if($orfInteractionRate <= 0.05 && $enrichment ne 'under-represented'){
						push (@{$bootStrapped{'all'}->{'hyperGeoPvalues'}->{$orfInteractionRate}}, $A);
						my @temp =keys %{$interactionHash{'all'}};
						my $coeffData = &calcClusteringCoeffientDirectedGraph(\@temp, $iCounts);
						$coeffData->{'C'} = ($coeffData->{'C'} >= 0) ? &prettyPrintNumber($coeffData->{'C'}) : 'n/a';
						$bootStrapped{'all'}->{'clusteringCoefficients'}->{$A} = $coeffData->{'C'};
						$bootStrapped{'all'}->{'numToCLIKconnections'}->{$A} = $coeffData->{'numNeighbors'};
						$sigBootstrapScore{$A}=1;
					}
				}
				if($seperateBy_iType && $iData->{'interactionsToConsiderCount'}>1){
					# next do for each type of interaction in data
					foreach my $expType(keys %{$interactionHash{'iTypes'}}){
						foreach my $iType(keys %{$interactionHash{'iTypes'}->{$expType}}){
							# if the type of interaction this orf has does not exist within the network then we cannot consider it...can we?
							$interactionsInNetwork->{'iTypes'}->{$expType}->{$iType} = 0 if !defined $interactionsInNetwork->{'iTypes'}->{$expType}->{$iType};
							# number of edges that connect current ORF to other CLIK group members
							my $numberToClikInteractions = scalar(keys %{$interactionHash{'iTypes'}->{$expType}->{$iType}});
							# total number of interactions of type X that this ORF has
							my $totalNumInteractions = 0 + $iCounts->{'orfs'}->{$A}->{'iTypes'}->{$expType}->{$iType};
							# if we included this orf in the network then the number of interactions of type x would be equal to $iInNetwork
							my $iInNetwork = $interactionsInNetwork->{'iTypes'}->{$expType}->{$iType} + $numberToClikInteractions;
							# determine if the interactions of the current ORF are over or under represented among its CLIK group members
							my ($orfInteractionRate, $enrichment) = (1,1);

							if($numberToClikInteractions > 0){
								($orfInteractionRate, $enrichment) = &cum_hyperg_pval_info($numberToClikInteractions, $totalNumInteractions, $iInNetwork, $iCounts->{'iTypeCounts'}->{$expType}->{$iType});
							}
							# if ORF has significant enrichment then....
							if($orfInteractionRate <= 0.05 && $enrichment ne 'under-represented'){
								push (@{$bootStrapped{'iTypes'}->{'hyperGeoPvalues'}->{$orfInteractionRate}->{$expType}->{$iType}}, $A);

								my @temp =keys %{$interactionHash{'iTypes'}->{$expType}->{$iType}};
								my $coeffData = &calcClusteringCoeffientDirectedGraph(\@temp, $iCounts);
								$coeffData->{'C'} = ($coeffData->{'C'} >= 0) ? &prettyPrintNumber($coeffData->{'C'}) : 'n/a';
								$bootStrapped{'iTypes'}->{"$expType:$iType"}->{'clusteringCoefficients'}->{$A} = $coeffData->{'C'};
								$bootStrapped{'iTypes'}->{"$expType:$iType"}->{'numToCLIKconnections'}->{$A} = $coeffData->{'numNeighbors'};
								$sigBootstrapScore{$A}=1;
								$sig_iTypes{$expType}->{$iType} ="";
							}
						}
					}
				}
			}
		}
	}

	my $count = 0;
	my $bootStraps = '';
	%sigBootstrapScore = ();

	LOOP:foreach my $sigValue(sort {$a<=>$b} keys %{$bootStrapped{'all'}->{'hyperGeoPvalues'}}){
		foreach my $orf(@{$bootStrapped{'all'}->{'hyperGeoPvalues'}->{$sigValue}}){
			last LOOP if $count >= $iData->{'numberOfBootStraps'};
			my $color = $#{$gData->{'orderedColor'}};
			$color = int(2.5 + log($sigValue)*-1 / 10 * 1.2 + 0.5 ) if $sigValue != 0;
			$color = ( $color > $#{$gData->{'orderedColor'}}) ? $gData->{'orderedColor'}->[$#{$gData->{'orderedColor'}}] : $gData->{'orderedColor'}->[$color];
			$sigValue = &prettyPrintNumber($sigValue);
			$bootStraps .= $rData->{'geneDisplaySub'}->($orf,"hel $color", '', " ($rData->{'ranksOfORFs'}->{$orf}->[0], $sigValue, $bootStrapped{'all'}->{'clusteringCoefficients'}->{$orf}, $bootStrapped{'all'}->{'numToCLIKconnections'}->{$orf}), ");
			$count++;
		}
	}

	$bootStraps =~ s/, \<\/a\>$/\<\/a\>/;

	if($seperateBy_iType && $iData->{'interactionsToConsiderCount'} > 1){
		if($bootStraps ne ''){
			$bootStraps = "$lb$lb<b>Additional Bootstrapped Data [ ORF (Rank, hypergeometric p-value, Clustering Coefficient, # Connections)] - ALL INTERACTION TYPES:</b>$lb$lb".$bootStraps;
		}
		$count=0;
		LOOP:foreach my $sigValue(sort {$a<=>$b} keys %{$bootStrapped{'iTypes'}->{'hyperGeoPvalues'}}){
			foreach my $expType(keys %{$bootStrapped{'iTypes'}->{'hyperGeoPvalues'}->{$sigValue}}){
				foreach my $iType(keys %{$bootStrapped{'iTypes'}->{'hyperGeoPvalues'}->{$sigValue}->{$expType}}){
					foreach my $orf(@{$bootStrapped{'iTypes'}->{'hyperGeoPvalues'}->{$sigValue}->{$expType}->{$iType}}){
						last LOOP if $count >= $iData->{'numberOfBootStraps'};
						my $color = $#{$gData->{'orderedColor'}};
						$color = int(2.5 + log($sigValue)*-1 / 10 * 1.2 + 0.5 ) if $sigValue != 0;
						$color = ( $color > $#{$gData->{'orderedColor'}}) ? $gData->{'orderedColor'}->[$#{$gData->{'orderedColor'}}] : $gData->{'orderedColor'}->[$color];
						$sigValue = &prettyPrintNumber($sigValue);
						my $cc = $bootStrapped{'iTypes'}->{"$expType:$iType"}->{'clusteringCoefficients'}->{$orf};
						my $numC = $bootStrapped{'iTypes'}->{"$expType:$iType"}->{'numToCLIKconnections'}->{$orf};
						$sig_iTypes{$expType}->{$iType} .= $rData->{'geneDisplaySub'}->($orf, "hel $color", '', " ($rData->{'ranksOfORFs'}->{$orf}->[0], $sigValue, $cc, $numC), ");
						$count++;
					}
				}
			}
		}
		if($count>1){
			$bootStraps .= "$lb$lb<b>Additional Bootstrapped Data [ ORF (Rank, hypergeometric p-value, Clustering Coefficient, # Connections)] - SPECIFIC INTERACTION TYPES:</b>$lb";
			foreach my $expType(sort keys %sig_iTypes){
				foreach my $iType(sort keys %{$sig_iTypes{$expType}}){
					if($sig_iTypes{$expType}->{$iType} ne ''){
						$sig_iTypes{$expType}->{$iType} =~ s/, \<\/a\>$/\<\/a\>/;
						$sig_iTypes{$expType}->{$iType} =~ s/, $//i;
						$bootStraps .= "$lb<u>".$iData->{'interactionsToConsider'}->{$expType}->{$iType}." (".ucfirst(lc($expType)).")</u>:$lb$sig_iTypes{$expType}->{$iType}$lb";
					}
				}
			}
		}
	}
	elsif($bootStraps ne ''){
		$bootStraps = "$lb$lb<b>Additional Bootstrapped Data [ ORF (Rank, hypergeometric p-value, Clustering Coefficient, # Connections)]</b>$lb$lb$bootStraps";
	}

	$bootStraps .= $lb;
	if($complexOutput eq ''){$complexOutput = "<b>No Significant enrichment of protein complexes found in this CLIK group.</b>";}
	$bootStraps .= $complexOutput;
	# warn "bs = $bootStraps $lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb$lb";
	return $bootStraps;
}

sub validatePositiveIntCGI{
	my ($paramName,$name) = @_;
	if(!defined $q->param($paramName)){&exitProgram(ucfirst($name).' not defined. Please try again or contact an administrator');}
	elsif($q->param($paramName) !~/^(0)$|^([1-9][0-9]*)$/ || $q->param($paramName) < 0){	&exitProgram("Error validating $name data. Please enter a positive integer.");}
	else{return int($q->param($paramName));}
}

#  uniques == a hash of the nodes to pull, if it is not supplied then pull all
sub buildJSON_network{
	my ($iCounts,$uniques, $filename) = @_;
	my @uniques;
	if(!defined $uniques){
		@uniques = keys %{$iCounts->{'orfs'}};
	}
	else{ @uniques = keys %{$uniques};}

	my $edges = "";
	my $nodes = "";
	for (my $i=0; $i<@uniques;$i++){
		$nodes .= "{\"name\":\"$uniques[$i]\",\"group\":1,\"id\":\"$uniques[$i]\"},";
		for (my $j=0; $j<@uniques;$j++){
			if($iCounts->{'orfs'}->{$uniques[$i]}->{'interactor'}->{$uniques[$j]}){
				$edges .="{\"source\":\"$uniques[$i]\",\"target\":\"$uniques[$j]\",\"value\":1},";
			}
		}
	}
	chop($edges);chop($nodes);

	return "{\"nodes\":[$nodes],\"edges\":[$edges]}";
}

sub calculateCLIKgroupStats{
	my($v) = @_;
	# validate input data

	my $groupNumber = 0;
	if(defined($q->param('groupNumber'))){
		if($q->param('groupNumber') =~/^(0)$|^([1-9][0-9]*)$/){$groupNumber = int($q->param('groupNumber'));	}
		elsif($q->param('groupNumber') eq '-cust'){ $groupNumber = '-cust';}
		else{	&exitProgram('Error validating uploaded data. Please try again or contact an administrator.'.$lb, "groupNumber = ".$q->param('groupNumber'));	}
	}
	else{	&exitProgram('Error validating uploaded data. Please try again or contact an administrator.'.$lb, "groupNumber = ".$q->param('groupNumber'));	}

	if(defined($q->param('dataSet')) && $q->param('dataSet') =~/^(0)$|^([1-9][0-9]*)$/){	$v->{'dataSet'} = int($q->param('dataSet'));	}
	else{	&exitProgram('Error validating previously uploaded data. Please try again or contact an administrator.'.$lb, 'Error validating dataSet value. line '.__LINE__);	}

	my $startX = &validatePositiveIntCGI('startX', 'start x-value');
	my $endX = &validatePositiveIntCGI('endX', 'end x-value');
	if(($endX - $startX) < 5){
		&exitProgram('Error validating x-range data. The CLIK window coordinates must each be at least 5 units apart with the end value being the larger value.'.$lb, 'Error validating X range. line '.__LINE__);
	}
	my $startY = &validatePositiveIntCGI('startY', 'start y-value');
	my $endY = &validatePositiveIntCGI('endY', 'end y-value');
	if(($endY - $startY) < 5){
		&exitProgram('Error validating y-range data. The CLIK window coordinates must each be at least 5 units apart with the end values being the larger values.'.$lb, "");
	}


	my $xSize = $endX - $startX;
	my $ySize = $endY - $startY;
	# retrieve data structures
	my $dataDir = "$v->{'base_upload_dir'}/$v->{'user'}/$v->{'dataSet'}/";
	my $gData = eval{retrieve($dataDir."graphData.dat")};
	if($@){	&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}
	my $rData = eval{retrieve($dataDir."rankData.dat")};
	if($@){	&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}
	my $iCounts = eval{retrieve($dataDir."interactionCounts.dat")};
	if($@){	&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}
	my $iData = eval{retrieve($dataDir."inputData.dat")};
	if($@){	&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}

	&setupORFoutputSub($rData);

	if(defined($q->param('numBootStraps')) && $q->param('numBootStraps') =~/^(0)$|^([1-9][0-9]*)$/){	$iData->{'numberOfBootStraps'} = int($q->param('numBootStraps')+0.5);	}
	else{	$iData->{'numberOfBootStraps'}=50;	}

	$iData->{'complexDataset'} = 'baryshnikova';
	if(defined($q->param('complexData')) && $q->param('complexData') eq 'benschop'){	$iData->{'complexDataset'} = 'benschop';}


	if($endX > $rData->{'size'}){
		&exitProgram("Error validating x-range data. The maximum x-value you can enter cannot be larger than the size of the dataset you are analyzing ($rData->{'size'} genes).$lb", "Error max X value.");
	}
	if($endY > $rData->{'size'}){
		&exitProgram("Error validating y-range data. The maximum y-value you can enter cannot be larger than the size of the dataset you are analyzing ($rData->{'size'} genes).$lb", "Error max Y value.");
	}

	my $outputs;

	# calculate the connection coefficients for the members of current CLIK group, start building output
	my %coeffs=();
	my $noInteractionsWithinCLIK='';
	# is this a square clik group
	my $square = 0;
	if($startX == $startY && $endX == $endY){
		$square=1;
		$outputs->{'endFhOutput'} .= "genes in CLIK group (X and Y axis):\n";
	}
	else{	$outputs->{'endFhOutput'} .= "genes in X range:\n";	}

	my %interactionsInNetwork=();
	$interactionsInNetwork{'all'}=0;

	my $noConnections=0;
	my $atLeast2Connections = 0;
	my $clusterCoeffMean = 0;
	$outputs->{'numTotal'} = 0;
	for(my $x=$startX; $x<=$endX; $x++){
		my $A = $rData->{'orderedORFnames'}->[$x]; # current orf
		my $originalName = $rData->{'originalList'}->[$x];
		# calculate connection coefficient
		my $coeffData = &calcClusteringCoefficientInArea($A, $iCounts, $rData->{'orderedORFnames'}, $startY, $endY, \%interactionsInNetwork);
		$interactionsInNetwork{'all'}+=$coeffData->{'numNeighbors'};
		if($coeffData->{'C'} >= 0){
			$clusterCoeffMean += $coeffData->{'C'};
			$atLeast2Connections++;
			$coeffs{$A} = &prettyPrintNumber($coeffData->{'C'});
		}
		# else it is -1 and has no connections with the other ORF members
		else{
			$noConnections++;
			$coeffs{$A} = "n/a";
			# if there are no y values for the x in this enrichment group then color the ORF gray
			$noInteractionsWithinCLIK.= $rData->{'geneDisplaySub'}->($originalName, "hel gray", "rank=$x, C=$coeffs{$A}, neighbors=$coeffData->{'numNeighbors'}",', ');
		}
		$outputs->{'numTotal'}++;
		$outputs->{'endFhOutput'}.= "$A (C=$coeffs{$A}, neighbors=$coeffData->{'numNeighbors'})\t";
	}

	# if not square need to now calculated the scores for the ORFs in the Y axis
	# -- but only for those that don't overlap with the x-coordinates, since they should have been done already, above.
	if(!$square){
		my ($o1, $o2) = (-1,-1);
		# define the overlap, if it exists
		if($startX > $startY && $endX < $endY){	$o1 = $startX; $o2 = $endX;}
		elsif($startY > $startX && $endY < $endX){	$o1 = $startY; $o2 = $endY;	}
		elsif($startX <= $startY && $endY >= $endX ){	$o1 = $startY; $o2 = $endX;	}
		elsif($startX < $endY && $endX > $endY){	$o1 = $startX; $o2 = $endY;	}
		$outputs->{'endFhOutput'} .= "genes in Y range:\n";
		YLOOP:for(my $y=$startY; $y<=$endY; $y++){
			#  overlap is o1 to o2 so if y is greater or less than that range, we're good.
			next YLOOP if($y>=$o1 && $y<=$o2);
			my $A = $rData->{'orderedORFnames'}->[$y]; # current orf
			my $originalName = $rData->{'originalList'}->[$y];
			# calculate connection coefficient
			my $coeffData = &calcClusteringCoefficientInArea($A, $iCounts, $rData->{'orderedORFnames'}, $startX, $endX, \%interactionsInNetwork);
			$interactionsInNetwork{'all'}+=$coeffData->{'numNeighbors'};
			if($coeffData->{'C'} >= 0){
				$clusterCoeffMean += $coeffData->{'C'};
				$atLeast2Connections++;
				$coeffs{$A} = &prettyPrintNumber($coeffData->{'C'});
			}
			# else it is -1 and has not connections with the other ORF members
			else{
				$noConnections++;
				$coeffs{$A} = "n/a";
				$noInteractionsWithinCLIK.= $rData->{'geneDisplaySub'}->($originalName, "hel gray", "rank=$y, C=$coeffs{$A}, neighbors=$coeffData->{'numNeighbors'}",', ');
			}
			$outputs->{'numTotal'}++;
			$outputs->{'endFhOutput'}.= "$A (C=$coeffs{$A}, neighbors=$coeffData->{'numNeighbors'})\t";
		}
	}
	my $clusterCoeffMeanWithZeros = $clusterCoeffMean / ($atLeast2Connections + $noConnections);
	if($atLeast2Connections > 0){$clusterCoeffMean = $clusterCoeffMean / $atLeast2Connections;}
	else{$clusterCoeffMean = 0;}
	# the keys of %coeffs are the ORFs that make up the x and y axes
	my $bootStraps = &bootStrapToClikGroup(\%coeffs, \%interactionsInNetwork, $iCounts, $rData, $iData, $gData, 1);

	# interactionRate will be used to calculate the rate of interactions within this CLIK group
	#$interactionRate = $interactionRate / ($xSize);
	#warn $totalNumberInteractions;
	#$interactionRate = $interactionsInNetwork{'all'} / $totalNumberInteractions * 100;
	my $connectivityRate = $interactionsInNetwork{'all'} / $xSize;
	#warn "$interactionsInNetwork{'all'}";
	$outputs->{'meanCoeff'} = &prettyPrintNumber($clusterCoeffMean);
	$outputs->{'meanCoeffWithZeros'} = &prettyPrintNumber($clusterCoeffMeanWithZeros);
	$outputs->{'numberUniques'} = scalar(keys %coeffs);

	my $groupScore = sqrt($outputs->{'meanCoeff'})*($outputs->{'numTotal'} / $rData->{'size'})*10000;
	$groupScore = &prettyPrintNumber($groupScore);
	$connectivityRate = &prettyPrintNumber($connectivityRate);
	my $extraText = "$lb<table><tr><td style='height:100%'><fieldset><legend style='white-space:nowrap;'><b>CLIK Group Stats:</b></legend>";
	$extraText .= "<small>*All members within CLIK group (including duplicates, if present), are used for the following stats. All interactions are considered to be reciprocal. If the X and Y dimensions are not symmetrical then all unique members in the X dimension are compared to all members in the Y dimension, and conversely (i.e. the X and Y dimensions are not compared to themselves). </small>$lb";
	$extraText .= "# of members without connections = $noConnections$lb";
	$extraText .= '# of interactions within group = '.$interactionsInNetwork{'all'}.''.$lb;
	$extraText .= 'Mean # of interactions per member of the group = '.$connectivityRate.''.$lb;
	$extraText .= "$lb<strong>Mean Clustering Coefficient = $outputs->{'meanCoeff'}$lb";
	$extraText .= "Mean Clustering Coefficient (including nodes w/ degree < 2) = $outputs->{'meanCoeffWithZeros'}$lb";
	$extraText .= "$lb\ CLIK Group Score = $groupScore</strong>$lb</fieldset></td><td style='height:100%'>";
	$extraText .= "<fieldset style='height:100%;padding-bottom:0px;padding-right:15px;margin-left:10px;border:2px solid grey;'>";
	$extraText .= "<legend style='white-space:nowrap;'><b>Stats for random network of same size</b></legend>";


	my %data = (
		'hiddens' => {
			'numNodes' => $outputs->{'numTotal'},
			'numEdges' => $interactionsInNetwork{'all'},
			'noConnections' => $noConnections, # number of orfs without ANY connections to clik group
			'randomStats' => 'true'
		},
		'divName' => "randomClikGroupStats",
		'groupNumber' => $groupNumber,
		'message' => "Run Random Stats"
	);
	$extraText .= &printCLIKgroupForm(\%data);
	$extraText .= "</fieldset></td></tr></table>";
	my $extraFHtext = "\n\n CLIK group size $xSize x $ySize\n\ # of members in CLIK group: $outputs->{'numTotal'} (".($outputs->{'numTotal'}-$outputs->{'numberUniques'})." duplicates)\n";
	$extraFHtext .= "*All members within CLIK group (including duplicates, if present), are used for the following stats:\n";
	$extraFHtext .= "\# of members without connections = $noConnections\n";
	$extraFHtext .= "Mean Coefficient = $outputs->{'meanCoeff'}\n";
	$extraFHtext .= "CLIK group Score = $groupScore\n\n";
	#$extraText .= '<span style="margin-left:20px;">Percentage of total available interactions within this CLIK group = '.sprintf("%.2f",$interactionRate).'</span>'.$lb;

	#$extraText .= $lb.'Random Data:'.$lb.'<span style="margin-left:20px;">Rate of interactions of random ORFs = '.sprintf("%.2f",$randomInteractionRate).'</span>'.$lb;
	#$extraText .= '<span style="margin-left:20px;">Mean number of interactions per ORF within group = '.sprintf("%.2f",$randomConnectivityRate).'</span>'.$lb.$lb;
	#if ($randomInteractionRate > 0){$extraText .= "\n<strong>CLIK group score = ".sprintf("%.2f",($interactionRate / $randomInteractionRate))." / ".sprintf("%.2f",($connectivityRate / $randomConnectivityRate))."</strong>\n";}

	$outputs->{'webOutput'} .= "$extraText\ $bootStraps";
	$outputs->{'fhOutput'} .= "$extraFHtext\n$outputs->{'endFhOutput'}$bootStraps";
	$outputs->{'fhOutput'} =~ s/\<br\/\>/\n/ig;
	$outputs->{'fhOutput'} =~ s/\<\/li\>/\n/ig;
	$outputs->{'fhOutput'} =~ s/\s\<\s0/ less than 0/ig;
	$outputs->{'fhOutput'} =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
	$outputs->{'webOutput'} =~ s/,\s+\<\/span\>$/\<\/span\>/;
	$noInteractionsWithinCLIK =~ s/,\s+\<\/span\>$/\<\/span\>/;
	if($noInteractionsWithinCLIK ne ''){$outputs->{'webOutput'}.="$lb$lb<span class=\"hideMe\"><br>No interactions within this CLIK group enrichment ($noConnections):</b></span>$lb$noInteractionsWithinCLIK";}
	#warn $noInteractionsWithinCLIK;
	$outputs->{'webOutput'} .= '</div></fieldset>';
	$outputs->{'fhOutput'} .= "\n\n";
	print	$outputs->{'webOutput'};
}

sub printORFs{
	my ($start, $end, $binWidth, $gData, $rData, $diagonalDensities, $diagCount, $square, $uniques, $outputs) = @_;

	$binWidth = int($binWidth+0.5); # round binWidth
	# if this is an off diagonal clik group then all orfs are lightgray
	if(!$square){
		my $color = 'lightgray'; # if there are no y values for the x in this enrichment group then color the ORF lightgray
		for(my $i=$start; $i<=$end; $i++){
			# common to both...(see else statement below)
			my $A = $rData->{'orderedORFnames'}->[$i]; # current orf
			my $originalName = $rData->{'originalList'}->[$i];
			$outputs->{'numTotal'}++;
			my $pos = $i+1;
			if(defined $uniques->{$A}){	$uniques->{$A} .= ", $pos";	}
			else{	$uniques->{$A} = $pos;	}
			$outputs->{'endWebOutput'} .= $rData->{'geneDisplaySub'}->($originalName, "hel $color", "rank=$pos",', ');
			$outputs->{'endFhOutput'}.= "$A\t";
		}
	}
	else{
		my $lastColor='lightgray';
		RANK:for(my $i=$start; $i<=$end; $i++){
			my $color = 'lightgray'; # if there are no y values for the x in this enrichment group then color the ORF lightgray
			if(defined $diagonalDensities->[$i]){$color = $gData->{'orderedColor'}->[$diagonalDensities->[$i]];}
			else{
				my $noMovement=0;
				my $diffCounter1 = 0;
				my $color1=-1;
				my $topLimit = $i+$binWidth;
				# make sure we stay within bounds of array...
				if($topLimit > $diagCount){
					$topLimit = $diagCount; # to avoid going into the loop
					# if($i==$topLimit){$color=$lastColor;}
				}
				# go forward and look for a significant plot point
				my $j=0;
				FIRST:for($j=$i; $j<$topLimit; $j++){
					$diffCounter1++;
					if(defined $diagonalDensities->[$j]){
						$color1=$diagonalDensities->[$j];
						last FIRST; # break out of loop -- this does not change the value of j
					}
				}
				#if($i<4){warn "i = $i ($rData->{'orderedORFnames'}->[$i]), j = $j, topLimit = $topLimit, diffCounter1 = $diffCounter1, diagCount = $diagCount";}

				# if there was nothing ahead of this orf then it should be lightgray
				if($j<$topLimit || $topLimit==$diagCount){
					# if no movement occurred then set diffCounter to an arbitrarily large value, like $rData->{'size'}
					# since color will be set to the lesser of the 2 counters.
					if($diffCounter1==0 ){$diffCounter1 = $rData->{'size'};$noMovement++;}
					my $diffCounter2 = 0;
					my $color2=0;

					# don't go negative
					my $bottomLimit = $i-$binWidth;
					if($bottomLimit < 0){$bottomLimit=0;}

					# go backward and look for a significant plot point
					SECOND:for($j=$i; $j>$bottomLimit; $j--){
						$diffCounter2++;
						if(defined $diagonalDensities->[$j]){$color2=$diagonalDensities->[$j]; last SECOND;}
					}
					# if there has been no movement or nothing was found ($j<=bottomLimit)
					if($diffCounter2==0 || $j<=$bottomLimit){
						$diffCounter2 = $rData->{'size'};
						$noMovement++;
					}
					# if at least one moved with success
					if($noMovement < 2){
						$color = ($diffCounter1>$diffCounter2 || $color1<0) ? $gData->{'orderedColor'}->[$color2] : $gData->{'orderedColor'}->[$color1];
					}
					# else if we hit the bottom limit, but it was only because we were at the limit of the array, check diffCount1 for movement
					# note this may cause issues with off-axis clik groups
					elsif($bottomLimit==0 && $diffCounter1 != $rData->{'size'}){
						$color=$gData->{'orderedColor'}->[$color1];
					}
					#warn "$diffCounter1 ($topLimit) -- $diffCounter2 ($bottomLimit) -- $binWidth - $noMovement, J = $j, i=$i - $color -- $color1, $color2" if($i<4);
				}

			}
			$lastColor=$color;
			# common to both...see if statement above
			my $A = $rData->{'orderedORFnames'}->[$i]; # current orf
			my $originalName = $rData->{'originalList'}->[$i];
			$outputs->{'numTotal'}++;
			my $pos = $i+1;
			if(defined $uniques->{$A}){	$uniques->{$A} .= ", $pos";	}
			else{	$uniques->{$A} = $pos;	}
			$outputs->{'endWebOutput'} .= $rData->{'geneDisplaySub'}->($originalName, "hel $color", "rank=$pos",', ');
			$outputs->{'endFhOutput'}.= "$A\t";
		}
	}
	$outputs->{'endWebOutput'} =~ s/, \<\/a\>$/\<\/a\>/;
	return 1;
}

sub outputCLIKgroupORFs{
	my($startX, $endX, $startY, $endY, $gData, $rData, $iCounts, $outputs, $groupNumber, $binWidth, $dirNum) = @_;
	my $ySize = $endY-$startY+1;
	my $xSize = $endX-$startX+1;
	my %uniques = ();
	$outputs->{'numTotal'} = 0;

	my $square = ($startX == $startY && $endX == $endY) ? 1 : 0;
	if($square){
		$outputs->{'endWebOutput'} .= "$lb<b>Members in CLIK group (X and Y axis): </b>$lb";
		$outputs->{'endFhOutput'} .= "Members in CLIK group (X and Y axis):\n";
		my $diagCount = scalar(@{$gData->{'diagonalDensities'}});
		&printORFs($startX,$endX, $binWidth,$gData,$rData,$gData->{'diagonalDensities'},$diagCount,1, \%uniques,$outputs);
	}
	else{
		my ($x1, $x2, $y1, $y2, $o1,$o2) = ($startX, $endX, $startY, $endY,undef,undef);
		my @temp=();
		# x encompassed
		# X   	-----
		# Y 	---------
		if($startX > $startY && $endX < $endY){
			my $range1 = ($y1+1 == $x1) ? $x1 : ($y1+1)."-".($x1);
			my $range2 = ($x2+1 == $y2) ? $x2+2 : ($x2+2)."-".($y2+1);
			$outputs->{'endWebOutput'} .= "$lb$lb<b>Members only in Y range ($range1 & $range2): </b>$lb";
			$outputs->{'endFhOutput'} .= "Members only in Y range:\n";
			&printORFs($y1,($x1-1), $binWidth,$gData,$rData,\@temp,0,0, \%uniques,$outputs);
			$outputs->{'endWebOutput'} .= ',';
			&printORFs(($x2+1),$y2, $binWidth,$gData,$rData,\@temp,0,0, \%uniques,$outputs);
			# set o1 and o2, kill x1,x2,y1 and y2 so we don't enter conditionals
			$o1 = $x1; $o2 = $x2; $x1=1; $x2=0; $y1=1; $y2=0;
		}
		# y encompassed
		# X   ----------
		# Y 		----
		elsif($startY > $startX && $endY < $endX){
			my $range1 = ($x1+1 == $y1) ? $y1 : ($x1+1)."-".($y1);
			my $range2 = ($x2+1 == $y2) ? $x2+2 : ($y2+2)."-".($x2+1);
			$outputs->{'endWebOutput'} .= "$lb$lb<b>Members only in X range  ($range1 & $range2): </b>$lb";
			$outputs->{'endFhOutput'} .= "Members only in X range:\n";
			&printORFs($x1,($y1-1), $binWidth,$gData,$rData,\@temp,0,0, \%uniques,$outputs);
			$outputs->{'endWebOutput'} .= ',';
			&printORFs(($y2+1),$x2, $binWidth,$gData,$rData,\@temp,0,0, \%uniques,$outputs);
			# set o1 and o2, kill x1,x2,y1 and y2 so we don't enter conditionals
			$o1 = $y1; $o2 = $y2; $x1=1; $x2=0; $y1=1; $y2=0;
		}
		# left overhang
		#  X -------------
		#  Y      ---------------
		elsif($startX <= $startY && $startY <= $endX ){
			$x1 = $startX; $x2 = $startY-1;
			$o1 = $startY; $o2 = $endX;
			$y1 = $endX+1; # $y2 still is $endY;
		}
		# right overhang
		# X       -------------
		# Y   ------------
		elsif($startX < $endY && $startX > $startY){
			$x1 = $endY+1; # $x2 still is endX;
			$o1 = $startX; $o2 = $endY;
			$y1 = $startY; $y2 = $startX-1;
		}

		if($x1<=$x2){
			$outputs->{'endWebOutput'} .= "$lb<strong>Members only in X range (".($x1+1)."-".($x2+1)."):</strong>$lb";
			$outputs->{'endFhOutput'} .= "Members in X range:\n";
			# check if there is any overlap...
			&printORFs($x1,$x2, $binWidth,$gData,$rData,\@temp,0,0, \%uniques,$outputs);
		}
		if($y1<=$y2){
			$outputs->{'endWebOutput'} .= "$lb$lb<strong>Members only in Y range  (".($y1+1)."-".($y2+1)."):</strong>$lb";
			$outputs->{'endFhOutput'} .= "Members in Y range:\n";
			&printORFs($y1,$y2, $binWidth,$gData,$rData,\@temp,0,0, \%uniques,$outputs);
		}
		if(defined $o1){
			my $diagCount = scalar(@{$gData->{'diagonalDensities'}});
			$outputs->{'endWebOutput'} .= "$lb$lb<strong>Members in X and Y range  (".($o1+1)."-".($o2+1)."):</strong>$lb";
			$outputs->{'endFhOutput'} .= "Range overlap:\n";
			&printORFs($o1,$o2, $binWidth,$gData,$rData,$gData->{'diagonalDensities'},$diagCount,1, \%uniques,$outputs);
		}
	}

	my $json = &buildJSON_network($iCounts, \%uniques);
	my $file_name = "network$groupNumber.json";
	open (JSON, ">$gData->{'imageDir'}$file_name");
	print JSON $json;
	close JSON;

	$outputs->{'numberUniques'} = scalar(keys %uniques);
	# only build smaller networks
	# warn "$gData->{'imageDownloadDir'}";
	# warn CGI::escape($file_name);
	my @extras = ["<a href=\"$gData->{'imageDownloadDir'}&file=".CGI::escape($file_name)."\" class='ext_link'>Click here to download JSON representation of CLIK group network.</a>"];
	if($outputs->{'numberUniques'} <= 500){
		# note - the $json variable contains double quotes so it should be encapsulated in singles
		push(@extras, "<button class='commit' onclick=\"generateNetworkGraph('networkJSON$groupNumber');\">View CLIK Group Network</button>");
		push(@extras, "<input type='hidden' id='networkJSON$groupNumber' value='$json'/><input type='hidden' name='authenticity_token' id='authenticity_token' value='".$gData->{'authenticity_token'}."' />");
	}
	else{
		push(@extras, "<button class='commit' disabled='disabled'>View CLIK Group Network</button>");
		push(@extras, "<b>CLIK group too large for network analysis (must be < 500 unique items, # present = $outputs->{'numberUniques'})</b>");
	}


	my $dups = $outputs->{'numTotal'}-$outputs->{'numberUniques'};
	my $extraText = "$lb$lb\ CLIK group size $xSize x $ySize$lb\# of members in CLIK group: $outputs->{'numTotal'} (";
	$extraText .= $dups > 1 ? "$dups duplicates)$lb" : "no duplicates found)$lb";
	$extraText .= $lb;
	my %data = (
		'hiddens' => { 'startX'  => $startX,
									 'endX'    => $endX,
									 'startY'  => $startY,
									 'endY'    => $endY,
									 'dataSet' => $dirNum,
									 'orderedGroupStats' => 'true'
									},
		'divName'     => "clikGroupStats",
		'groupNumber' => $groupNumber,
		'message'     => "Run CLIK Group Stats, bootstrapping, and complex enrichment",
		'extras'      => @extras
	);

	$extraText .= &printCLIKgroupForm(\%data);
	my $extraFHtext = "\n\n CLIK group size $xSize x $ySize\n\ # of members in CLIK group: $outputs->{'numTotal'} ($dups";
	$extraFHtext .= $dups > 1 ? " duplicates)\n" : " duplicate)\n";

	$outputs->{'webOutput'} .= "$extraText$outputs->{'endWebOutput'}";
	$outputs->{'fhOutput'} .= "$extraFHtext\n$outputs->{'endFhOutput'}";
	$outputs->{'fhOutput'} =~ s/\<br\/\>/\n/ig;
	$outputs->{'fhOutput'} =~ s/\<\/li\>/\n/ig;
	$outputs->{'fhOutput'} =~ s/\s\<\s0/ less than 0/ig;
	$outputs->{'fhOutput'} =~ s/<(?:[^>'"]*|(['"]).*?\1)*>//gs;
	$outputs->{'webOutput'} =~ s/,\s+\<\/span\>$/\<\/span\>/;
	$outputs->{'webOutput'} .= '</div></fieldset>';
	$outputs->{'fhOutput'} .= "\n\n";
}

sub calculateMaxROI{
	my ($rData, $iCounts) = @_;
	my $windowSize = int($rData->{'size'}**0.5); # start window size
	my %limits = ('max' => 0);
	my $start = 0;
	my $end = $windowSize;
	#  Slide a window of size $windowSize over the dataset. Determine the number of interactions among the ORFs within the window.
	# with each interaction slide the window over by a number of ORFs defined as $windowSize/2
	while($end <= $rData->{'size'}){
		my $currentTotal=0;
		for(my $i=$start; $i<$end; $i++){
			for(my $j=$i; $j<$end; $j++){
				if($iCounts->{'orfs'}->{$rData->{'orderedORFnames'}->[$i]}->{'interactor'}->{$rData->{'orderedORFnames'}->[$j]}){
					$currentTotal++;
				}
			}
		}
		if($currentTotal > $limits{'max'}){
			$limits{'max'}=$currentTotal;
			$limits{'start'}=$start;
			$limits{'end'}=$end;
		}
		if($end == $rData->{'size'}){
			$end+=2; # break out of while loop
		}
		else{
			$start += ($windowSize/2) ;
			$end = $start + $windowSize;
			if($end > $rData->{'size'}){
				$end = $rData->{'size'};
				$start = $end - $windowSize;
			}
		}
	}
	if(!defined $limits{'end'}){
		$limits{'start'}=0;
		$limits{'end'}=$windowSize;
		$limits{'max'}=0;
		return \%limits;
	}
	# now that a region of interest has been defined, refine it slightly by shrinking it.
	my $minWindowSize = int($rData->{'size'}**0.5) / 3; # set minimum window size
	$minWindowSize=10 if($minWindowSize < 10);
	my $leftLimitStart = $limits{'start'};
	my $rightLimitStart = ($limits{'end'}-$limits{'start'}) / 2;
	my $rightLimitEnd = $limits{'end'};
	my $currentWindow = ($limits{'end'}-$limits{'start'});
	while($currentWindow > $minWindowSize){
		my $leftWindowTotal=0;
		for(my $i=$leftLimitStart; $i<$rightLimitStart; $i++){
			for(my $j=$i; $j<$rightLimitStart; $j++){
				if($iCounts->{'orfs'}->{$rData->{'orderedORFnames'}->[$i]}->{'interactor'}->{$rData->{'orderedORFnames'}->[$j]}){
					$leftWindowTotal++;
				}
			}
		}
		my $rightWindowTotal=0;
		for(my $i=$rightLimitStart; $i<$rightLimitEnd; $i++){
			for(my $j=$i; $j<$rightLimitEnd; $j++){
				if($iCounts->{'orfs'}->{$rData->{'orderedORFnames'}->[$i]}->{'interactor'}->{$rData->{'orderedORFnames'}->[$j]}){
					$rightWindowTotal++;
				}
			}
		}
		$currentWindow = $currentWindow / 2;
		if($rightWindowTotal > $leftWindowTotal){
			$limits{'max'}=$rightWindowTotal;
			$limits{'start'}=$rightLimitStart;
			$limits{'end'}=$rightLimitEnd;
			$leftLimitStart = $rightLimitStart;
			$rightLimitStart = $rightLimitStart + $currentWindow;
			$rightLimitEnd = $rightLimitStart + $currentWindow;

		}
		else{
			$limits{'max'}=$leftLimitStart;
			$limits{'start'}=$leftLimitStart;
			$limits{'end'}=$rightLimitStart;

			$rightLimitStart = $leftLimitStart + $currentWindow;
			$rightLimitEnd = $rightLimitStart + $currentWindow;
		}
	}
	return \%limits;
}

sub refineROI{
	my ($rData, $iCounts, $roi) = @_;
	# find orf in range of ROI with max connection coefficient
	my $max = 0;
	my $maxRank = -1;
	for(my $j=$roi->{'start'}; $j <= $roi->{'end'}; $j++){
		my $A = $rData->{'orderedORFnames'}->[$j];
		my $coeffData = &calcClusteringCoefficientInArea($A, $iCounts, $rData->{'orderedORFnames'}, $roi->{'start'}, $roi->{'end'});
		if($coeffData->{'C'} > $max){
			$max = $coeffData->{'C'};
			$maxRank = $j;
		}
	}
	$maxRank = int($roi->{'start'}+(($roi->{'end'}-$roi->{'start'})/2)) if ($maxRank < 1);

	my $possibleNumberInteractions = ($rData->{'size'}*($rData->{'size'}-1)/2);

	my %coeffs = ('max' => 0);
	# now that we have pin pointed the start we will expand a window around it in blocks of $windowSizeIterator
	# and determine how the mean connection coeff changes
	my $lowerLimit = $maxRank;
	my $upperLimit = $maxRank;
	my @random1 = @{$rData->{'orderedORFnames'}};
	&fisher_yates_shuffle(\@random1);
	&fisher_yates_shuffle(\@random1);
	my $iteration = 0;
	my $limit = int($rData->{'size'}**0.5)*4;
	my $min = int($rData->{'size'}**0.5) / 3;
	my $minBin = int($rData->{'size'}**0.5) / 2;
	my $maxBin = int($rData->{'size'}**0.5);
	my $lastRatioAve = -1;
	my $runningSum = 0;
	my $size = $upperLimit - $lowerLimit;
	if($size < $min){
		$min = ($min-$size) / 2;
		$lowerLimit -= $min;
		$upperLimit += $min;
		$size = $upperLimit - $lowerLimit;
	}
	my $windowSizeIterator = int($rData->{'size'}**0.5)/8;
	$windowSizeIterator = 3 if($windowSizeIterator < 3);
	while($size < $limit){
		$iteration++;
		# defined box bounds
		if($lowerLimit < 0){
			$upperLimit += 0 - $lowerLimit;
			$lowerLimit = 0;
		}
		if($upperLimit > $rData->{'size'}){
			$lowerLimit = $lowerLimit - ($upperLimit-$rData->{'size'});
			$upperLimit = $rData->{'size'};
		}
		$size = ($upperLimit - $lowerLimit);
		my $count = 0;
		my $sum = 0;
		my $meanCoefficient = 0;
		# my $inNetworkInteractionCount = 0;
		# my $totalInteractionsPossible = 0;
		# my $numTwoOrMore=0;
		# calculate mean clustering coefficient of ordered network of size upperLimit - lowerLimit

		for(my $j=$lowerLimit; $j <= $upperLimit; $j++){
			my $A = $rData->{'orderedORFnames'}->[$j];
			my $coeffData = &calcClusteringCoefficientInArea($A, $iCounts, $rData->{'orderedORFnames'}, $lowerLimit, $upperLimit);
			# $numTwoOrMore += &isConnected($A, $iCounts, $rData->{'orderedORFnames'}, $lowerLimit, $upperLimit);
			if($coeffData->{'C'} >= 0){
				$count++ ;
				$sum += $coeffData->{'C'};
			}
			# $totalInteractionsPossible+=$iCounts->{'orfs'}->{$A}->{'numInteractions'};
			# for(my $y=$j; $y<=$upperLimit; $y++){
			# 	my $B = $rData->{'orderedORFnames'}->[$y];
			# 	if(defined $iCounts->{'orfs'}->{$A}->{'interactor'}->{$B} && $A ne $B){
			# 		$inNetworkInteractionCount++;
			# 	}
			# }
		}

		if($count > 0){	$meanCoefficient = $sum / $count;}

		my $sizeScaledScore = $meanCoefficient * log($size);
		#my $logSizeScaledScore = $meanCoefficient * (log($size)/log(10));
		if($sizeScaledScore > $coeffs{'max'}){
			$coeffs{'max'} = $sizeScaledScore;
			$coeffs{'size'} = ($upperLimit-$lowerLimit) / 4;
		}
		#warn "$orfInteractionRate, $enrichment -- $inNetworkInteractionCount,

		#warn "lower = $lowerLimit, upper = $upperLimit, count = $count, size = $size, 2orMore = $numTwoOrMore (".($numTwoOrMore/ $size).") ---- mean = $meanCoefficient (ln scaled = $sizeScaledScore, log scaled = $logSizeScaledScore -- ln = ".log($size).", log = ".( log ( $size / log(10)))."), random = $randomMeanCoefficient -- ratio = $ratio";
		$lowerLimit = $lowerLimit - $windowSizeIterator;
		$upperLimit = $upperLimit + $windowSizeIterator;
	}
	if(!$coeffs{'size'}){$coeffs{'size'} = ($maxBin + $minBin)/2;}
	elsif($coeffs{'size'} > $maxBin){$coeffs{'size'}=$maxBin;}
	elsif($coeffs{'size'} < $minBin){$coeffs{'size'}=$minBin;}
	return $coeffs{'size'};
}

sub calcClusteringCoefficientInArea{
	# determine the clustering coefficient of a given ORF with a range of continuous ORFs in the dataset
	# curORF = current node we are considering
	# iCounts contains interaction data
	# orfList is an array of all ORFs in dataset, ordered by rank
	# start = start position in orfList to consider
	# end = end position in orfList to consider
	my ($curORF, $iCounts, $orfList, $start, $end, $types) = @_;
	my @neighbors = (); # neighbors = ORFs within current group that $curORF is connected to, do not consider self interactions
	# find all neighbors --> only consider A-->B interactions (i.e. uni-directional) --> $currentORF = A
	# note that if interactions are considered bidirectional it could mess up in-CLIK-group interaction counts
	for(my $k=$start; $k<= $end; $k++){
		if($curORF ne $orfList->[$k] && defined $iCounts->{'orfs'}->{$curORF}->{'interactor'}->{$orfList->[$k]}){
			push(@neighbors, $orfList->[$k]);
		}
	}

	my $info = &calcClusteringCoeffientDirectedGraph(\@neighbors, $iCounts);

	if(defined $types){
		foreach my $orfB(@neighbors){
			if(defined $iCounts->{'orfs'}->{$curORF}->{'interactor'}->{$orfB}){
				foreach my $ExpType(keys %{$iCounts->{'orfs'}->{$curORF}->{'interactor'}->{$orfB}->{'iTypes'}}){
					foreach my $iType(keys %{$iCounts->{'orfs'}->{$curORF}->{'interactor'}->{$orfB}->{'iTypes'}->{$ExpType}}){
						$types->{'iTypes'}->{$ExpType}->{$iType}++;
					}
				}
			}
		}
	}

	return $info;
}

sub calcClusteringCoeffientDirectedGraph{
	# assumes graph is directed...
	# calculate clustering coefficient for a list of 'neighboring nodes' - just determine how many interactions
	# exist among neighbors and divide by the number of possible interactions among interactions
	my ($neighbors, $iCounts) = @_;
	my $neighborInteractions = 0;
	my %info = ('C'=>'n/a', 'numNeighbors' => scalar(@{$neighbors}));
	# determine interactions among neighbors
	for(my $nIndex=0; $nIndex < $info{'numNeighbors'}; $nIndex++){
		my $curNeigh = $neighbors->[$nIndex];
		for(my $nIndex2=$nIndex; $nIndex2 < $info{'numNeighbors'}; $nIndex2++){
			if($nIndex != $nIndex2){
				if(defined $iCounts->{'orfs'}->{$curNeigh}->{'interactor'}->{$neighbors->[$nIndex2]}) {$neighborInteractions++;}
				if(defined $iCounts->{'orfs'}->{$neighbors->[$nIndex2]}->{'interactor'}->{$curNeigh}) {$neighborInteractions++;}
			}
		}
	}
	my $C=0;
	if($info{'numNeighbors'} < 3){
		if($info{'numNeighbors'} == 0){$info{'C'}=-1;}
		else{$info{'C'}=0;}
	}
	else{
		my $divisor = $info{'numNeighbors'}*($info{'numNeighbors'}-1);
		if($divisor == 0){$info{'C'}=0;}
		else{$info{'C'}=($neighborInteractions / $divisor);}
	}
	return \%info;
}

# sub calculateWindowInteractionDensity{
#
# 	my ($rData, $iCounts) = @_;
# 	my $minWindowSize = int($rData->{'size'}**0.5); # start window size
# 	my $windowIterator = int($minWindowSize/2);
# 	my $sizeIterator = $windowIterator; #($windowIterator >= 5) ? int($windowIterator / 5 + 0.5) : 1;
# 	my $maxWindowSize = (($minWindowSize*100) < int($rData->{'size'} / 2)) ? ($minWindowSize*100) : int($rData->{'size'} / 2) ;# max window size
# 	my $global_ratio = $iCounts->{'totalInteractions'} / $rData->{'size'};
# 	warn "global ratio =  $global_ratio";
# 	my %maxWindow = ('ratio' => 0);
# 	for(my $windowSize=$minWindowSize; $windowSize < $maxWindowSize; $windowSize+=$windowIterator){ # iterate window size
# 		my $max = 0;
# 		my $window_end_bound = $rData->{'size'}-$windowSize;
# 		for(my $windowStart=0; $windowStart <= $window_end_bound; $windowStart+=$sizeIterator){ # move window across data
# 			my $windowEnd=$windowStart+$windowSize;
# 			my $windowTotal=0;
# 			for(my $i=$windowStart; $i<$windowEnd; $i++){
# 				for(my $j=$i; $j<$windowEnd; $j++){
# 					if($iCounts->{'orfs'}->{$rData->{'orderedORFnames'}->[$i]}->{'interactor'}->{$rData->{'orderedORFnames'}->[$j]}){
# 						$windowTotal++;
# 					}
# 				}
# 			}
# 			my $windowRatio = $windowTotal / ($windowSize*$global_ratio);
# 			$max = $windowRatio if($windowRatio > $max);
# 			if($windowRatio > $maxWindow{'ratio'}){
# 				$maxWindow{'ratio'} = $windowRatio;
# 				$maxWindow{'start'} = $windowStart;
# 				$maxWindow{'end'} = $windowEnd;
# 			}
#
# 		#	warn "windowSize = $windowSize s=$windowStart, $windowEnd , $windowTotal, --> window max = $max, current global max =  $maxWindow{'ratio'}";
# 		}
# 		warn "windowSize = $windowSize --> window max = $max, current global max =  $maxWindow{'ratio'}";
# 	}
# 	warn Dumper \%maxWindow;exit;
# 	return \%maxWindow;
# }


sub pullInteractionDataFromDatabase {
	my ($dbh, $fields, $tableName, $queryField, $processSub, $rData, $interactionCounts, $otherData) = @_;

	my $limit = 50;

	my $sqlFront = "SELECT ".join(', ', @{$fields})." FROM $tableName WHERE $queryField IN (";
	my $sqlEnd = join(', ', ('?') x $limit ). ")";
	my $interactionsSth = $dbh->prepare( "$sqlFront $sqlEnd" );
	# warn "$sqlFront $sqlEnd";
	my $count = 0;
	my $start = 0;
	my $end = -1;
	my $total = scalar(@{$rData->{'orderedORFnames'}});
	my $go = 1;
	my $totalInteractions = 0;
	while($go){
		$start=$end+1;
		$end=$start+$limit-1;
		if($end > $total){
			$interactionsSth->finish();
			$end = $total;
			$limit = $end-$start;
			$end--;
			# $dbh->{TraceLevel} = 2;
			if($limit < 1){
				$limit = 1;
				$start = $end;
			}
			$sqlEnd = join(', ', ('?') x $limit ). ")";
			$interactionsSth = $dbh->prepare( "$sqlFront $sqlEnd" );
			$go=0;
		}
		my @temp = @{$rData->{'orderedORFnames'}}[$start..$end];

		$interactionsSth->execute(@temp);
		$count++;

		# set start (ie the start of the next round) to be end+1

		if($count > 1000){
			&progressHook(10, "Calculating Interaction matrix ($start of $total)");
			$count=0;
		}
		while ( my $row = $interactionsSth->fetchrow_arrayref() ) {
			my $orf = $row->[0];
			my $interactor = $row->[1];
			if(!defined $interactor && $interactor eq $orf){next;}  # ignore self interactions
			# if present in our data set....
			if(defined $rData->{'ranksOfORFs'}->{$interactor} && defined $rData->{'ranksOfORFs'}->{$orf}){
				$totalInteractions += $processSub->($orf, $interactor, $interactionCounts,$otherData, $row);
			} # end defined $rData->{'ranksOfORFs'}->{$interactor}
		} # end while loop
	}	# end while GO $orf
	$interactionsSth->finish();
	$dbh->disconnect();
	return $totalInteractions;
}

sub calculateBioGridInteractionsMySQL{
	my ($rData,$iData, $interactionCounts, $notConsidered, $organismInfo) = @_;
	my $organism = lc($organismInfo->{'shortName'});
	my $totalInteractions = 0;
	my @fields = ('`intA`', '`intB`', '`expSystemType`', '`expSystem`');
	my $tableName = '`'.$organism.'_bioGrid_interactions`';
	my $queryField = '`intA`';

	my $dbh = Modules::ScreenAnalysis::connectToMySQL();
	if(!$dbh){&exitProgram("Could not connect to database!");}
	my %otherData = ('iData'=>$iData,'notConsidered'=>$notConsidered);
	$totalInteractions = &pullInteractionDataFromDatabase($dbh, \@fields, $tableName, $queryField, \&processBioGridMySQLrow, $rData, $interactionCounts, \%otherData);
	$dbh->disconnect();
	return $totalInteractions; # since $interactionCounts and $notConsidered were passed by reference, we do not need to return them
}

sub calculateDroidbInteractionsMySQL{
	my ($rData,$iData, $interactionCounts, $notConsidered, $organismInfo) = @_;
	my $organism = lc($organismInfo->{'shortName'});
	my $totalInteractions = 0;
	my @fields = ('`flyID_a`', '`flyID_b`', '`interaction_category`', '`interaction_type`');
	my $tableName = lc('`'.$organism.'_droidb_interactions`');
	my $queryField = '`flyID_a`';

	my $dbh = Modules::ScreenAnalysis::connectToMySQL();
	if(!$dbh){&exitProgram("Could not connect to database!");}
	my %otherData = ('iData'=>$iData,'notConsidered'=>$notConsidered);
	$totalInteractions = &pullInteractionDataFromDatabase($dbh, \@fields, $tableName, $queryField, \&processBioGridMySQLrow, $rData, $interactionCounts, \%otherData);
	$dbh->disconnect();
	return $totalInteractions; # since $interactionCounts and $notConsidered were passed by reference, we do not need to return them
}

sub processBioGridMySQLrow {
	my($orf, $interactor, $interactionCounts,$otherData, $row) = @_;

	my $expSysType = uc($row->[2]); # e.g. genetic or physical
	my $interactionType = uc($row->[3]); # e.g. synthetic lethality, affinity capture, etc.
	my $countIT = 0; # should we count this interaction?
	my $forceRecip = 0;
	# if we are considering this type of interaction
	if(defined $otherData->{'iData'}->{'interactionsToConsider'}->{$expSysType}->{$interactionType}){
		$countIT=1;
		if($otherData->{'iData'}->{'forceReciprocal'} && !defined $interactionCounts->{'orfs'}->{$interactor}->{'interactor'}->{$orf}){
			$forceRecip=1;
			$interactionCounts->{'orfs'}->{$interactor}->{'iTypes'}->{$expSysType}->{$interactionType}++;
		}
		$interactionCounts->{'orfs'}->{$orf}->{'iTypes'}->{$expSysType}->{$interactionType}++;
		$interactionCounts->{'iTypeCounts'}->{$expSysType}->{$interactionType}++;
		$interactionCounts->{'orfs'}->{$orf}->{'interactor'}->{$interactor}->{'iTypes'}->{$expSysType}->{$interactionType}++;
		$interactionCounts->{'orfs'}->{$orf}->{'interactor'}->{$interactor}->{'evidenceCount'}++;
	} # end if defined $otherData->{'iData'}->{'interactionsToConsider'}->{"\L$interactionType"}
	else{$otherData->{'notConsidered'}->{$expSysType}->{$interactionType}=1;}
	# if we do not care about reciprocal interactions OR if we do AND the reciprocal exists
	if($countIT && ($otherData->{'iData'}->{'reciprocal'} == 0 || defined $interactionCounts->{'orfs'}->{$interactor}->{'interactor'}->{$orf})){
		$interactionCounts->{'orfs'}->{$orf}->{'numInteractions'}++; # add 1 to the total number interactions that this orf has
		if($forceRecip){
			$interactionCounts->{'orfs'}->{$interactor}->{'numInteractions'}++;
			$interactionCounts->{'orfs'}->{$interactor}->{'interactor'}->{$orf} = $interactionCounts->{'orfs'}->{$orf}->{'interactor'}->{$interactor};
		}
		return 1;
	} # end if reciprocal check
	return 0;
}

sub calculatePrePPI_InteractionsMySQL{
	my ($rData,$iData, $interactionCounts, $notConsidered, $organismInfo) = @_;

	my $organism = lc($organismInfo->{'shortName'});
	my $scoreThreshold = $organismInfo->{'scoreThreshold'};

	my $expSysType = 'Phyical'; # e.g. genetic or physical
	my $interactionType = 'PrePPI'; # e.g. synthetic lethality, affinity capture, etc.
	$iData->{'interactionsToConsider'}->{$expSysType}->{$interactionType}="PrePPI";

	my $dbh = Modules::ScreenAnalysis::connectToMySQL();
	if(!$dbh){&exitProgram("Could not connect to database!");}

	my $geneID = 'ORF';
	if($organism eq 'hsapien'){
		$geneID = 'ensembl';
		$organism .="_filtered";
	}
	my @fields = ("`int_a_$geneID`","`int_b_$geneID`");
	my $queryField = $fields[0];

	#  my ($numberOfRows) = $dbh->selectrow_array("SELECT count(*) FROM `honig_preppi_int_$organism` WHERE `preppi_score` > $scoreThreshold");
	my $tableName = "tempTable";
	my $sourceTable = "`honig_preppi_int_$organism`";

	if($organism ne 'hsapien_filered'){
		my $tempTable = "CREATE TEMPORARY TABLE IF NOT EXISTS $tableName AS (SELECT ".join(', ', @fields)." FROM $sourceTable WHERE `preppi_score` > $scoreThreshold)";
		$dbh->do($tempTable);
		&progressHook(10, "Calculating Interaction matrix (temp table created)");
		$tableName = "`$tableName`";
	}
	else{	$tableName = $sourceTable;}

	my %otherData = ('expSysType'=> $expSysType, 'interactionType' => $interactionType);
	&pullInteractionDataFromDatabase($dbh, \@fields, $tableName, $queryField, \&processSingleInteractionTypeMySQLrow,$rData, $interactionCounts, \%otherData);

	$dbh->disconnect();
	return $interactionCounts->{'iTypeCounts'}->{$expSysType}->{$interactionType}; # since $interactionCounts and $notConsidered were passed by reference, we do not need to return them
}

sub processSingleInteractionTypeMySQLrow {
	my($orf,$interactor,$interactionCounts, $otherData) = @_;
	my $countIT = 0; # should we count this interaction?

	if(!defined $interactionCounts->{'orfs'}->{$interactor}->{'interactor'}->{$orf}){
		$interactionCounts->{'orfs'}->{$interactor}->{'iTypes'}->{$otherData->{'expSysType'}}->{$otherData->{'interactionType'}}++;
		$interactionCounts->{'orfs'}->{$interactor}->{'numInteractions'}++;
		$interactionCounts->{'orfs'}->{$orf}->{'interactor'}->{$interactor}->{'iTypes'}->{$otherData->{'expSysType'}}->{$otherData->{'interactionType'}}++;
		$interactionCounts->{'orfs'}->{$interactor}->{'interactor'}->{$orf}->{'evidenceCount'}++;
		$countIT=1;
	}
	if(!defined $interactionCounts->{'orfs'}->{$orf}->{'interactor'}->{$interactor}){
		$interactionCounts->{'orfs'}->{$orf}->{'iTypes'}->{$otherData->{'expSysType'}}->{$otherData->{'interactionType'}}++;
		$interactionCounts->{'orfs'}->{$orf}->{'interactor'}->{$interactor}->{'iTypes'}->{$otherData->{'expSysType'}}->{$otherData->{'interactionType'}}++;
		$interactionCounts->{'orfs'}->{$orf}->{'interactor'}->{$interactor}->{'evidenceCount'}++;
		$interactionCounts->{'orfs'}->{$orf}->{'numInteractions'}++; # add 1 to the total number interactions that this orf has
		$countIT=1;
	}
	$interactionCounts->{'iTypeCounts'}->{$otherData->{'expSysType'}}->{$otherData->{'interactionType'}}+=$countIT;
	return 0;
}

sub calculateFunctionalNetInteractionsMySQL{
	my ($rData,$iData, $interactionCounts, $notConsidered, $organismInfo) = @_;
	my $organism = lc($organismInfo->{'shortName'});
	my $totalInteractions = 0;

	my @fields = ('`intA`','`intB`');
	my $queryField = $fields[0];
	my $tableName = '`'.$organism.'_interactions_funNet`';

	my $expSysType = "Probabilistic functional gene network"; # e.g. genetic or physical
	my $interactionType = "Functional gene network (informatic)"; # e.g. synthetic lethality, affinity capture, etc.
	$iData->{'interactionsToConsider'}->{$expSysType}->{$interactionType}='Functional Net';
	my %otherData = ('expSysType'=> $expSysType, 'interactionType' => $interactionType);

	my $dbh = Modules::ScreenAnalysis::connectToMySQL();
	if(!$dbh){&exitProgram("Could not connect to database!");}
	# $dbh->{TraceLevel} = 2;
	&pullInteractionDataFromDatabase($dbh, \@fields, $tableName, $queryField, \&processSingleInteractionTypeMySQLrow,$rData, $interactionCounts, \%otherData);
	$dbh->disconnect();

	return $interactionCounts->{'iTypeCounts'}->{$expSysType}->{$interactionType};
}

# calculates interactions between genes, removes noisy interactions
sub calculateInteractions{
	# rData = rank data processed in processInputData by readSceenMillFile or readORF_list
	# 				rData is a ref to a hash with the following keys:
	#					$rData->{'orderedORFnames'}=> an array with the index corresponds to rank and values are ORFs names
	# 				$rData->{'orderedValues'}=> an array containing the values associated with each ORF
	#					$rData->{'ranksOfORFs'}=> a hash with ORFs as keys and their corresponding ordered rank values as....values
	#					$rData->{'ranksOfRandomORFs'}=> same as 'ranksOfORFs' but with random order
	#					$rData->{'randomORFnames'} => same as 'orderedORFnames' but with random order
	# iData = is a hash ref that contains the input data processed by processInputData. Keys are:
	#					$iData->{'organism'} ==> organism associated with ORFs entered
	#					$iData->{'interactionsToConsider'} ==> hash that contains the type of interactions (e.g. SL, SDL, Western, Two-Hybrid) to consider
	#					$iData->{'promiscuousCutoff'} ==> interaction cutoff. Any ORFs that have more interactions than this value are not considered
	#					$iData->{'binWidth'} ==> width of bins to divide plot area into
	#					$iData->{organismInteractionInfo} ==> hash that contains info about the organism whose ORFs are being considered (used with oData)
	#					$iData->{'interactionNormalization'} ==> should auto noise reduction be applied
	#					$iData->{'reciprocal'} ==> should we only consider reciprocal interactions (i.e. only consider interaction if A -> B and B -> A exist).
	# oInfo = a hash ref to what interaction data we will be considering

	my ($iData,$rData, $oData) = @_;

	# begin
	my (%interactionCounts, %notConsidered)=((),());

	my $size = @{$rData->{'orderedORFnames'}};

	my $dataLoaded = 0;
	my $totalInteractions = 0;
	foreach my $db(@{$oData->{$iData->{'organismInteractionInfo'}}->{'useThese'}}){
		if($oData->{$db}->{'dataBaseType'} eq 'GO'){
			# go interaction data is retrieved faster from flat files then from the db, so keep it that way.
			$iData->{'interactionsToConsider'}->{'GO'}->{'GO'}='Gene Ontology';
			my $dataDir = $oData->{$db}->{'dataDir'};
			my $aspect = $oData->{$db}->{'GOAspect'};
			my $organism = $oData->{$db}->{'shortName'};
			my $throughput = 'variable';
			my $expSysType = 'GO';
			my $interactionType = 'GO';
			my $source = 'GO';
			foreach my $a(@{$aspect}){
				my $interactionInfo = &retrieveInteractionDataStructureInfo($dataDir, $a, $organism);
				# iterate over ORF names in uploaded dataset
				my $lastFile ='';
				my $interactionData;
				# iterate over the known interactions of current ORF
				foreach my $interactionFile(@{$interactionInfo}){
					#warn "iterating over $interactionFile";
					if($interactionFile ne $lastFile){
						$interactionData = eval{retrieve("interactionData/savedStructures/$dataDir/$a/$interactionFile")};
						if($@){	&exitProgram("Problem loading interaction data. An administrator has been notified, please try again soon.","Could not open $interactionFile\n$@");}
					}
					$lastFile = $interactionFile;
					foreach my $orf(@{$rData->{'orderedORFnames'}}){
						$interactionCounts{'orfs'}->{$orf}->{'numInteractions'}+=0;
						foreach my $interactor(keys %{$interactionData->{$orf}}){
							if($interactor eq $orf){next;}  # ignore self interactions
							# if present in our data set....
							if(defined $rData->{'ranksOfORFs'}->{$interactor}){
								$totalInteractions++;
								$interactionCounts{'orfs'}->{$orf}->{'numInteractions'}++; # add 1 to the total number interactions that this orf has
								$interactionCounts{'orfs'}->{$orf}->{'iTypes'}->{$expSysType}->{$interactionType}++;
								$interactionCounts{'iTypeCounts'}->{$expSysType}->{$interactionType}++;
								$interactionCounts{'orfs'}->{$orf}->{'interactor'}->{$interactor}->{'evidenceCount'}++;
								$interactionCounts{'orfs'}->{$orf}->{'interactor'}->{$interactor}->{'iTypes'}->{$expSysType}->{$interactionType}->{$source}++;
								# GO term interactions are, by definition, reciprocal --> make it so.
								if(!defined($interactionData->{$interactor}->{$orf})){
									$totalInteractions++;
									$interactionCounts{'orfs'}->{$interactor}->{'numInteractions'}++;
									$interactionCounts{'orfs'}->{$interactor}->{'iTypes'}->{$expSysType}->{$interactionType}++;
									$interactionCounts{'orfs'}->{$interactor}->{'interactor'}->{$orf} = $interactionCounts{'orfs'}->{$orf}->{'interactor'}->{$interactor};
								}
							} # end defined $rData->{'ranksOfORFs'}->{$interactor}
						} # end foreach $biogridInteractor
					} # end foreach my $orf
				} # end foreach interaction file
			} # end foreach aspect
		} # end if interaction type == go
		elsif($oData->{$db}->{'dataBaseType'} eq 'Functional Network'){$totalInteractions+=&calculateFunctionalNetInteractionsMySQL($rData,$iData, \%interactionCounts, \%notConsidered,$oData->{$db});}
		elsif($oData->{$db}->{'dataBaseType'} eq 'PrePPI'){
			$totalInteractions+=&calculatePrePPI_InteractionsMySQL($rData,$iData, \%interactionCounts, \%notConsidered, $oData->{$db});
		}
		elsif($oData->{$db}->{'dataBaseType'} eq 'droiDB'){
			$totalInteractions+=&calculateDroidbInteractionsMySQL($rData,$iData, \%interactionCounts, \%notConsidered, $oData->{$db})
		}
		# else do BioGRID
		else{
			$totalInteractions+=&calculateBioGridInteractionsMySQL($rData,$iData, \%interactionCounts, \%notConsidered, $oData->{$db});
		}
	}

	#warn $totalInteractions;
	# warn "size = $size";
	#
	my $interactionTypeMsg='';
	if(%notConsidered){
		$interactionTypeMsg = $lb."<b>The following interaction types were not considered:</b>$lb";
		foreach my $db(@{$oData->{$iData->{'organismInteractionInfo'}}->{'useThese'}}){
		# warn "calling! $oData->{$db}->{'dataDir'}, $oData->{$db}->{'shortName'}";
			my $acceptableInteractions = &acceptableInteractions($oData->{$db}->{'dataDir'}, $oData->{$db}->{'shortName'});
			foreach my $expSysType(keys %notConsidered){
				foreach my $interactionType(keys %{$notConsidered{$expSysType}}){
					$interactionTypeMsg.= $acceptableInteractions->{$expSysType}->{$interactionType}.", ";
				}
			}
			$interactionTypeMsg =~ s/, $//; # remove trailing comma
		}
		$interactionTypeMsg.=$lb;
	}
	# warn $interactionTypeMsg;

	# use Data::Dumper;
	# warn Dumper $oData->{'iData'}->{'interactionsToConsider'};
	# warn Dumper($interactionCounts{'orfs'});
	# run &trimNoisyItems here since %promiscuousGenes is built here...
	#	my ($numRemoved, $trimInfo) = (0,'');# &trimNoisyItems(\%interactionCounts, $rData, $iData, 0);
	my ($numRemoved, $trimInfo) = &trimNoisyItems(\%interactionCounts, $rData, $iData, 0);
	$size -= $numRemoved;
	$rData->{'size'} = $size;
	$rData->{'numberORFsTrimmed'} = $numRemoved;
	# make sure we do not have TOOOOO much data to analyze
	if($rData->{'size'} > $iData->{'maxAmountOfData'}){
		&exitProgram("Too much data to analyze. You can analyze a maximum of $iData->{'maxAmountOfData'} items (you entered $rData->{'size'}).$lb", "Too much data to analyze. You can analyze a maximum of $iData->{'maxAmountOfData'} items (you entered $rData->{'size'}).");
	}

	if($totalInteractions < 1){	&exitProgram("Failed to find any interactions among the genes being analyzed.");}

	# make sure we have enough data to analyze
	if($rData->{'size'} < $iData->{'minNumberOfORFs'}) {
		&exitProgram("Too few valid identifiers (genes) in dataset to properly analyze ( < $iData->{'minNumberOfORFs'} valid identifiers found)!");
	}

	# add random rank information to $rData
	$size--; # to correct for arrays starting at 0;
	my @temp = (0..$size);
	&fisher_yates_shuffle(\@temp);
	for(my $i=0; $i <= $size; $i++){
		push(@{$rData->{'ranksOfRandomORFs'}->{$rData->{'orderedORFnames'}->[$i]}}, $temp[$i]);
		$rData->{'randomORFnames'}->[$temp[$i]]=$rData->{'orderedORFnames'}->[$i];
	}

	return (\%interactionCounts, $trimInfo, $interactionTypeMsg);
}

sub calculatePlotPoints{
	# rData = rank data processed in processInputData by readSceenMillFile or readORF_list
	# 				rData is a ref to a hash of which the following keys are relevant in this sub:
	#						'orderedORFnames'=> an array with the index corresponds to rank and values are ORFs names
	#						'ranksOfORFs'=> a hash with ORFs as keys and their corresponding ordered rank values as....values
	#						'size' => number of ORFs we are considering
	# iData = is a ref to a hash of which the following keys are relevant in this sub:
	#					'numberofBinRows'

	my ($iCounts, $rData, $iData, $gData) = @_;
	my %plotData;

	use Statistics::Descriptive; # stats and whatnot
	my $interactionCounts = Statistics::Descriptive::Sparse->new();

	# round value to nearest integer value
	$iData->{'numberofBinRows'} = int($rData->{'size'} / $iData->{'binWidth'} + 0.5);
	if($iData->{'numberofBinRows'} <= 0){
		&exitProgram("An issue has occurred. Please try again or contact the admin for more assistance.", "ERROR! $iData->{'numberofBinRows'} <= 0");
	}
	$plotData{'binWidth'} = $rData->{'size'}/$iData->{'numberofBinRows'};
	$plotData{'halfWidth'}=$plotData{'binWidth'}/2;
	$plotData{'binArea'} = ($plotData{'binWidth'}*2)**2;

	$plotData{'numberOfBins'} = ($iData->{'numberofBinRows'}**2);
	$plotData{'randomTotalInteractions'}=0;

	#  set default color
	my $color = $gData->{'randomColors'}->[0];  # light gray
	$gData->{'imgObject'}->fgcolor($color); # set foreground color
	$gData->{'imgObject'}->bgcolor($color); # set background color
	#  set default point size
	my $ellipseSize = int($gData->{'randomPlotPointSize'} * $gData->{'randomPlotPointMultiplier'});

	my (@topLeft, @bottomRight)=((),());
	my $nextCount = 0;
	$iCounts->{'totalInteractions'}=0;

	for(my $i=0; $i<$rData->{'size'}; $i++){#   A's ->
		my $A = $rData->{'orderedORFnames'}->[$i];
		$iCounts->{'orfs'}->{$A}->{'numInteractions'}+=0;
		my $numInteractions = $iCounts->{'orfs'}->{$A}->{'numInteractions'}/scalar( @{$rData->{'ranksOfORFs'}->{$A}});
		$interactionCounts->add_data( $numInteractions ); # needed to perform stats

		my $aRank = $i;
		# need to push and pull this data so that next time this ORF comes up in the ordered data we pull the proper rank.
		# this will also ensure that when we iterate over the B data, everything is there [even if only 1 interaction exists]
		my $randomA_rank = shift(@{$rData->{'ranksOfRandomORFs'}->{$A}});
		push(@{$rData->{'ranksOfRandomORFs'}->{$A}}, $randomA_rank);
		#$randomA_rank++;	# index starts at 0 so add one to both ranks
		foreach my $B (keys %{$iCounts->{'orfs'}->{$A}->{'interactor'}}) {#      -> B's

			# we are iterating over an array b/c their may be duplicate orfs in a rank ordered set with
			# different....uuuhhhh rankings

			BRANK: foreach my $bRank(@{$rData->{'ranksOfORFs'}->{$B}}){
				$iCounts->{'totalInteractions'}++;

				my $currentBin = int( $aRank / $plotData{'binWidth'}) * $iData->{'numberofBinRows'} + int($bRank / $plotData{'binWidth'}); # figure out what 'bin' we are in based on the current coordinates
				push(@{$plotData{'plotPoints'}->{$currentBin}->{'x'}}, $aRank);
				push(@{$plotData{'plotPoints'}->{$currentBin}->{'y'}}, $bRank);
				$plotData{'plotPoints'}->{$currentBin}->{'count'}++;

				# plot point on graph
				my $x = ($aRank / $gData->{'imageScaler'})+$gData->{'leftBorderOffset'}; # calculate where to plot this x value on the actual image
				my $y = ($rData->{'size'}-$bRank) / $gData->{'imageScaler'}+$gData->{'topBorderOffset'};	# calculate where to plot this y value on the actual image
				$gData->{'imgObject'}->moveTo($x,$y); # move to ellipse position
				$gData->{'imgObject'}->ellipse($ellipseSize,$ellipseSize);	 # draw ellipse
			}

			# now recalculate for RANDOM data
			foreach my $randomB_rank(@{$rData->{'ranksOfRandomORFs'}->{$B}}){
				#if($nextCount > 0){	$nextCount--;	next;	}
				my $currentBin = int( $randomA_rank / $plotData{'binWidth'}) * $iData->{'numberofBinRows'} + int($randomB_rank / $plotData{'binWidth'}); # figure out what 'bin' we are in based on the current coordinates

				push(@{$plotData{'randomPlotPoints'}->{$currentBin}->{'x'}}, $randomA_rank);
				push(@{$plotData{'randomPlotPoints'}->{$currentBin}->{'y'}}, $randomB_rank);
				$plotData{'randomPlotPoints'}->{$currentBin}->{'count'}++;
				$plotData{'randomTotalInteractions'}++;
			}
		}# end foreach B
	}# end foreach A
	#
	# warn "posCounter = $posCounter";
	# warn "# left = ".scalar(@randomPosToDelete);
	# warn 'Now, number of total interactions: '.$iCounts->{'totalInteractions'};
	# warn "top left count -->".scalar(@topLeft);
	# warn "bottom right count -->".scalar(@bottomRight);
	# warn "ordered bin count = ".scalar(keys %{$plotData{'plotPoints'}});
	# warn "random bin count = ".scalar(keys %{$plotData{'randomPlotPoints'}});
	$rData->{'meanNumberInteractions'}=$interactionCounts->mean();
	$plotData{'meanInteractionsPerBin'} = $iCounts->{'totalInteractions'}/($iData->{'numberofBinRows'}**2);
	# warn $plotData{'randomTotalInteractions'};
	# exit;
	# warn $iCounts->{'totalInteractions'};
	##################### End determine x and y coordinates of scatter plot #################
	#
	return \%plotData;
}

# subroutine that will calculate the densities of all the points within the bin passed to it
sub calculateSigBinDensities{
	my ($bin, $pData, $binsToConsider, $numBinRows, $dataSize, $densityValues, $orderedStats, $sigCutoff) = @_;
	# all bins on the borders will have to deal with the edge effect...
	# all internal bins will absolutely not because at most their bin will extend
	# to 1 unit of the graph border. so to correct for this we can determine
	# if the current bin lies on the border and account for the edge affect.
	# To do this, just push the bin within bounds
	my $xFloorSub = sub {$_[0] - $pData->{'binWidth'} };
	my $yFloorSub = sub {$_[0] - $pData->{'binWidth'} };
	my $xCeilingSub = sub {$_[0] + $pData->{'binWidth'} };
	my $yCeilingSub = sub {$_[0] + $pData->{'binWidth'} };
	# remove neighbors if they do not exist (i.e if current bin is on a border)...
	if($bin < $numBinRows){
		# current bin is on the left border of the graph. Ignore all bins to the left
		delete $binsToConsider->{"bottom-left"};
		delete $binsToConsider->{"immediate-left"};
		delete $binsToConsider->{"top-left"};
		# really do not need to change xFloor since it will not be needed since we
		# just deleted the bins that use it in the 3 lines above
		$xFloorSub = sub{return 0};
		# we do, however, need to adjust the $xCeilingSub
		my $temp = $pData->{'binWidth'}*2;
		$xCeilingSub= sub { return $temp };
		# look out for corners too!
		if($bin == 0){
			$yFloorSub = sub{return 0};
			$yCeilingSub=sub{return $temp};
			delete $binsToConsider->{"bottom-right"};
			delete $binsToConsider->{"bottom"};
		}
		elsif($bin == $numBinRows-1){
			$yFloorSub = sub{return $dataSize-$pData->{'binWidth'}*2};
			$yCeilingSub=sub{return $dataSize};
			delete $binsToConsider->{"top-right"};
			delete $binsToConsider->{"top"};
		}
	}
	elsif($bin >= $pData->{'numberOfBins'}-$numBinRows-1){
		# current bin is on the right border of the graph. Ignore all bins to the right
		delete $binsToConsider->{"bottom-right"};
		delete $binsToConsider->{"immediate-right"};
		delete $binsToConsider->{"top-right"};
		# really do not need to change xCeiling since it will not be needed since we
		# just deleted the bins that use it in the 3 lines above
		$xCeilingSub=sub{return $dataSize};

		# we do, however, need to adjust the $xFloorSub
		my $temp = $dataSize-$pData->{'binWidth'}*2;
		$xFloorSub = sub{return $temp};

		# look out for corners too!
		if($bin == $pData->{'numberOfBins'}-$numBinRows-1){
			# bottom-right
			$yFloorSub = sub{return 0};
			$yCeilingSub=sub{return $pData->{'binWidth'}*2};
			delete $binsToConsider->{"bottom-left"};
			delete $binsToConsider->{"bottom"};
		}
		elsif($bin == $pData->{'numberOfBins'}-1){
			# top-right
			$yFloorSub = sub{return $dataSize-$pData->{'binWidth'}*2};
			$yCeilingSub=sub{return $dataSize};
			delete $binsToConsider->{"top-left"};
			delete $binsToConsider->{"top"};
		}
	}
	elsif( $bin % $numBinRows == 0){
		# bottom row
		delete $binsToConsider->{"bottom-right"};
		delete $binsToConsider->{"bottom"};
		delete $binsToConsider->{"bottom-left"};
		$yFloorSub = sub{return 0};
		$yCeilingSub=sub{return $pData->{'binWidth'}*2};
	}
	elsif( ($bin+1) % $numBinRows == 0 ){
		# top row
		delete $binsToConsider->{"top-right"};
		delete $binsToConsider->{"top"};
		delete $binsToConsider->{"top-left"};
		$yFloorSub = sub{return $dataSize-$pData->{'binWidth'}*2};
		$yCeilingSub=sub{return $dataSize};
	}
	# make sure each bin has plot data defined, else delete it...
	foreach my $neighboringBin(keys %{$binsToConsider}){
		my $temp = $binsToConsider->{$neighboringBin}->{'args'}->{'binNeighbor'};
		if(!  defined $pData->{'plotPoints'}->{$temp}){
			delete $binsToConsider->{$neighboringBin};
		}
	}

	for(my $i=0; $i < $pData->{'plotPoints'}->{$bin}->{'count'}; $i++){
		# note that binNeighbors contains the current bin, so it is really binNeighbors + currentBin

		# initialize count to the number of guys in current
		# my $count = $pData->{'plotPoints'}->{$bin}->{'count'};
		my $curX = $pData->{'plotPoints'}->{$bin}->{'x'}->[$i]; # current X value	(RANK!)
		my $curY = $pData->{'plotPoints'}->{$bin}->{'y'}->[$i]; # current Y value (RANK!)

		my $count = $pData->{'plotPoints'}->{$bin}->{'count'};

		my %borders = (
			'xFloor' => $xFloorSub->($curX),
			'xCeiling' => $xCeilingSub->($curX),
			'yFloor' => $yFloorSub->($curY),
			'yCeiling' => $yCeilingSub->($curY)
		);

		foreach my $neighboringBin(keys %{$binsToConsider}){
			$count += $binsToConsider->{$neighboringBin}->{'sub'}->($binsToConsider->{$neighboringBin}->{'args'},\%borders);
		}
		my $density = $count / $pData->{'binArea'};
		$orderedStats->add_data($density); # needed to perform stats
		$densityValues->{'ordered'}->{'densities'}->{$density}->{$curX}->{$curY}=1;
		$densityValues->{'ordered'}->{'binsAnalyzed'}->{$bin}=1;
	}

	return 1;
}

# find bins surrounding current bin being analyzed, defined sub routine refs to extract
# point within surrounding bins that count towards the density of the current point being analyzed.
sub getBinsToConsider{
	my ($bin, $numberofBinRows, $pData) = @_;
	# only look in current bin and bins immediately surrounding (if they exist)...Note that
	# if we are on the left side then bin+numberofBinRows does not exist so do not search in it
	# binsToConsider 0-2 = left, 3-4 = middle, 5-7 = right
	my %binsToConsider = (
		"bottom-left" => {
											'args' => {'binNeighbor'=>($bin-$numberofBinRows-1), 'pData'=>$pData},
											'sub' => sub{
												my ($args,$borders) = @_;
												my $count = 0;
												my $limit = $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'};
												my $jj=0;
												while($jj<$limit && $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'x'}->[$jj] <= $borders->{'xFloor'}){$jj++;}
												for(my $j=$jj; $j < $limit; $j++){
													if($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'y'}->[$j] > $borders->{'yFloor'}){
														$count++;
													}
												}

												return $count;
											}
										},
		"immediate-left" => {
											'args' => {'binNeighbor'=>($bin-$numberofBinRows), 'pData'=>$pData},
											'sub' => sub{
												# the immediate left (i.e. 1) should be in the y range so just no need to check it
												my ($args,$borders) = @_;
												my $count = 0;
												my $limit = $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'};
												my $jj=0;
												while($jj<$limit && $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'x'}->[$jj] <= $borders->{'xFloor'}){$jj++;}
												$count += ($limit - $jj);

												return $count;
											}
										},
		"top-left" => {
										'args' => {'binNeighbor'=>($bin-$numberofBinRows+1), 'pData'=>$pData},
										'sub' => sub{
												my ($args,$borders) = @_;
												my $count = 0;
												my $limit = $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'};
												my $jj=0;
												while($jj<$limit && $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'x'}->[$jj] <= $borders->{'xFloor'}){
													$jj++;
												}
												for(my $j=$jj; $j < $limit; $j++){
													if($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'y'}->[$j] < $borders->{'yCeiling'}){
														$count++;
													}
												}
												return $count;
											}
									},
		"bottom" => {
									'args' => {'binNeighbor'=>($bin-1), 'pData'=>$pData},
									'sub' => sub{
												my ($args,$borders) = @_;
												my $count = 0;
												for(my $j=0; $j < $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'}; $j++){
													if($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'y'}->[$j] > $borders->{'yFloor'}){
														$count++;
													}
												}
												return $count;
											}
								},
		"top" => {
							'args' => {'binNeighbor'=>($bin+1), 'pData'=>$pData},
							'sub' => sub{
												my ($args,$borders) = @_;
												my $count = 0;
												for(my $j=0; $j < $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'}; $j++){
													if($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'y'}->[$j] < $borders->{'yCeiling'}){
														$count++;
													}
												}
												return $count;
											}
						},
		"bottom-right" => {
											'args' => {'binNeighbor'=>($bin+$numberofBinRows-1), 'pData'=>$pData},
											'sub' => sub{
												my ($args,$borders) = @_;
												my $count = 0;
												for(my $j=0; $j < $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'}; $j++){
													if($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'x'}->[$j] > $borders->{'xCeiling'} ){
														# breakout of loop
														$j=$args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'};
													}
													elsif($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'y'}->[$j] > $borders->{'yFloor'}){
														$count++;
													}
												}
												return $count;
											}
										},
		"immediate-right" =>{
											'args' => {'binNeighbor'=>($bin+$numberofBinRows), 'pData'=>$pData},
											'sub' => sub{
												my ($args,$borders) = @_;
												my $count = 0;
												for(my $j=0; $j < $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'}; $j++){
													if($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'x'}->[$j] > $borders->{'xCeiling'} ){
														# breakout of loop
														$j=$args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'};
													}
													$count++;
												}
												return $count;
											}
										},
		"top-right" =>	{
											'args' => {'binNeighbor'=>($bin+$numberofBinRows+1), 'pData'=>$pData},
											'sub' => sub{
												my ($args, $borders) = @_;
												my $count = 0;
												for(my $j=0; $j < $args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'}; $j++){
													if($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'x'}->[$j] > $borders->{'xCeiling'} ){
														# breakout of loop
														$j=$args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'count'};
													}
													elsif($args->{'pData'}->{'plotPoints'}->{$args->{'binNeighbor'}}->{'y'}->[$j] < $borders->{'yCeiling'}){
														$count++;
													}
												}
												return $count;
											}
										}
	);
	return \%binsToConsider;
}

sub calculatePointDensity{
	use Statistics::Descriptive; # stats and whatnot
	# calculate density of each point by determining the number of data points within its immediate vicinity
	# do this by centering a virtual bin over a given point and determining the amount of data within it

	#  also begin plotting points, assume all are boring (i.e. do not have a significant density value)
	# rData = rank data processed in processInputData by readSceenMillFile or readORF_list
	# 				rData is a ref to a hash of which the following keys are relevant in this sub:
	#						'orderedORFnames'=> an array with the index corresponds to rank and values are ORFs names
	#						'ranksOfORFs'=> a hash with ORFs as keys and their corresponding ordered rank values as....values
	#						'size' => number of ORFs we are considering
	# iData = is a ref to a hash of which the following keys are relevant in this sub:
	#					'numberofBinRows'
	# pData = ref to %plotData hash that contains the x and y coordinated for every data point, relevant keys:
	#					$plotData->{'numberOfBins'} == total number of data bins possible
	#					$plotData->{'binWidth'} == width of each bin
	#					$plotData->{'binArea'} == area of each bin
	#					$plotData->{'plotPoints'}->{$bin}->{'x'} == an array with all of the x plot point values in the current bin
	#					$plotData->{'plotPoints'}->{$bin}->{'y'} == an array with all of the corresponding y plot point values in the current bin
	#					$plotData->{'plotPoints'}->{$bin}->{'count'} == a scalar containing the total number of data in the current bin
	# 				$plotData->{'randomPlotPoints'}->{$bin}->{'x'} == same as above but with randomized data
	#					$plotData->{'randomPlotPoints'}->{$bin}->{'y'} == same as above but with randomized data
	#					$plotData->{'randomPlotPoints'}->{$bin}->{'count'} == a scalar containing the total number of data in the current bin
	#					$plotData->{'totalInteractions'} == total number of interactions in the dataset
	my ($iData, $iCounts, $rData, $pData, $gData) = @_;
	my %densityValues;

	my $orderedStats = Statistics::Descriptive::Sparse->new();
	my $randomStats = Statistics::Descriptive::Full->new();
	# figure out bin stats
	for(my $bin = 0; $bin <= $pData->{'numberOfBins'}; $bin++){
		if(defined $pData->{'randomPlotPoints'}->{$bin}){
			$randomStats->add_data( $pData->{'randomPlotPoints'}->{$bin}->{'count'} );
		}
		# else{$randomStats->add_data(0);}
		if(defined $pData->{'plotPoints'}->{$bin}){
			$orderedStats->add_data( $pData->{'plotPoints'}->{$bin}->{'count'} );
		}
		# else{$orderedStats->add_data(0);}
	}

	my $binArea = $pData->{'binWidth'}*$pData->{'binWidth'};
	$densityValues{'randomMean'} = $randomStats->mean()/$binArea;
	$densityValues{'randomStdDev'} = $randomStats->standard_deviation()/$binArea;
	$densityValues{'randomDenMax'} = $randomStats->max()/$binArea;
	$densityValues{'randomDenCount'} = $randomStats->count();
	my $index;
	($densityValues{'densityCorrection'}, $index) = $randomStats->percentile($gData->{'significanceThreshold'});


	# reset stats
	$orderedStats = Statistics::Descriptive::Sparse->new();
	#$randomStats = Statistics::Descriptive::Full->new();

	for(my $bin = 0; $bin <= $pData->{'numberOfBins'}; $bin++){
		# update status message
		if($bin % 10 == 0){	&progressHook(40+($bin/$pData->{'numberOfBins'}*40), "Calculating point densities");}
		# if this is a significant bin, then...
		if(defined $pData->{'plotPoints'}->{$bin} && $pData->{'plotPoints'}->{$bin}->{'count'} > $densityValues{'densityCorrection'}){

			my $binsToConsider = &getBinsToConsider($bin, $iData->{'numberofBinRows'}, $pData);

			&calculateSigBinDensities($bin, $pData, $binsToConsider, $iData->{'numberofBinRows'}, $rData->{'size'}, \%densityValues, $orderedStats, $densityValues{'densityCorrection'});

			# now for each neighboring bin check to see if it is insignificant and has not yet been analyzed,
			# if a neighbor bin meets both of those criteria, analyze the points within it, because points near
			# significant bins may be significant, even if their bin container is not considered so.

			foreach my $neighboringBin(keys %{$binsToConsider}){
				if(defined $binsToConsider->{$neighboringBin}->{'args'}){
					# if this bin has not yet been analyzed and is below the sig cutoff (i.e won't be analyzed)
					if(! defined $densityValues{'ordered'}->{'binsAnalyzed'}->{$binsToConsider->{$neighboringBin}->{'args'}->{'binNeighbor'}} &&
							$pData->{'plotPoints'}->{$binsToConsider->{$neighboringBin}->{'args'}->{'binNeighbor'}}->{'count'} < $densityValues{'densityCorrection'}){
						# go ahead and check of any of the points are significant...
						my $newBin = $binsToConsider->{$neighboringBin}->{'args'}->{'binNeighbor'};
						$binsToConsider = &getBinsToConsider($newBin, $iData->{'numberofBinRows'}, $pData);
						&calculateSigBinDensities($newBin, $pData, $binsToConsider, $iData->{'numberofBinRows'}, $rData->{'size'}, \%densityValues, $orderedStats, $densityValues{'densityCorrection'});
					}
				}
			}
		}
	} # end of foreach my $bin
	$densityValues{'densityCorrection'}/=$binArea;
	$densityValues{'orderedMean'} = $orderedStats->mean();
	$densityValues{'orderedStdDev'} = $orderedStats->standard_deviation();
	$densityValues{'orderedDenMax'} = $orderedStats->max();

	# number of interactions within significant bins
	$densityValues{'orderedDenCount'}=$orderedStats->count();

	# adjuster is the z-score of the max random density using the order data mean and standard deviation.
	#$densityValues{'adjuster'} = ($densityValues{'randomDenMax'} - $densityValues{'orderedMean'})/$densityValues{'orderedStdDev'};
	#$densityValues{'maxOrderedZscore'} = sprintf("%.6f", ((($densityValues{'orderedDenMax'} - $densityValues{'orderedMean'})/ $densityValues{'orderedStdDev'} - 0.5)-$densityValues{'adjuster'}));
	#$densityValues{'maxRandomZscore'} = sprintf("%.6f", (($densityValues{'randomDenMax'} - $densityValues{'randomMean'})/ $densityValues{'randomStdDev'} - 0.5));

	# calculate the density from the random dist that is $gData->{'significanceThreshold'} standard devs from the mean
	#$densityValues{'densityCorrection'} = $densityValues{'randomStdDev'}*$gData->{'significanceThreshold'}+$densityValues{'randomMean'};

	return \%densityValues;
}

################################### LINE_BREAK_CHECK
#
# line_break_check receives a file handle as its input and returns the new line character used in the file handle
sub line_break_check{
	my $file = shift;
	local $/ = \1000; # read first 1000 bytes
	local $_ = <$file>; # read
	my ($newline) = /(\015\012?)/ ? $1 : "\012"; # Default to unix.
	seek $file,0,0; # rewind to start of file
 	return $newline;
}


sub retrieveInteractionDataStructureInfo{
	my ($dataDIR, $aspect, $organism) = @_;
	my $dir = "interactionData/savedStructures/$dataDIR/$aspect";
	if(! -d $dir){
		&buildGOdata($organism);
		if(! -d $dir){
			&exitProgram("Could not load interaction data! The website admin has been notified of this error. Please try again later.", 'dir does not exist'. __FILE__.' line '.__LINE__);
		}
	}
	opendir(DIR, $dir);
	my @files = grep {
										-f "$dir/$_"   # and is a file
										&&	/\.dat$/	# ends with .dat
										} readdir(DIR);
	close DIR;
	if(@files < 1 ){
		&buildGOdata($organism);
		opendir(DIR, $dir);
		@files = grep {
									-f "$dir/$_"   # and is a file
									&&	/\.dat$/	# ends with .dat
									} readdir(DIR);
		close DIR;
		if(@files < 1 ){
			&exitProgram("Could not load interaction data! The website admin has been notified of this error. Please try again later.", 'no files'. __FILE__.' line '.__LINE__);
		}
	}
	return \@files;
}


sub buildGOdata{
	my $source = shift;
	if(! -e "interactionData/savedStructures"){	mkdir("interactionData/savedStructures", 0770) || die "Could not create directory: $!";	}
	if(! -e "interactionData/savedStructures/geneOntology"){	mkdir("interactionData/savedStructures/geneOntology", 0770) || die "Could not create directory: $!";}
	if(! -e "interactionData/savedStructures/geneOntology/$source"){	mkdir("interactionData/savedStructures/geneOntology/$source", 0770) || die "Could not create directory: $!";}
	my %goData;
	open (my $GOdata, "<interactionData/geneOntology/GOdata_$source.txt") || die "Couldn't open GOdata_$source.txt data\n";
	$/ = line_break_check( $GOdata );
	my $header = <$GOdata>;

	LOOP:foreach(<$GOdata>){
		chomp;
		my @data = split /\t/;
		my @orf = split(/\|/,$data[10]);
		my $goCat = $data[4];
		my $goAspect = $data[8];
		if(defined $orf[0] && !defined($goData{$goAspect}->{$goCat}->{'orf'}->{$orf[0]})){
			push(@{$goData{$goAspect}->{$goCat}->{'array'}}, $orf[0]);
			$goData{$goAspect}->{$goCat}->{'orf'}->{$orf[0]}=1;
		}
	}
	my $iData=();
	foreach my $a(keys %goData){
		if(! -e "interactionData/savedStructures/geneOntology/$source/$a"){
			mkdir("interactionData/savedStructures/geneOntology/$source/$a", 0770) || die "Could not create directory: $!";
		}
		my $count = 0;
		my $fileNum=1;
		foreach my $c(keys %{$goData{$a}}){
			if(scalar(@{$goData{$a}->{$c}->{'array'}} <=200) && scalar(@{$goData{$a}->{$c}->{'array'}} > 4) ){
				$count+= scalar(@{$goData{$a}->{$c}->{'array'}});
				for(my $i = 0; $i < @{$goData{$a}->{$c}->{'array'}}; $i++){
					for(my $j = $i; $j < @{$goData{$a}->{$c}->{'array'}}; $j++){
						$iData->{$goData{$a}->{$c}->{'array'}->[$i]}->{$goData{$a}->{$c}->{'array'}->[$j]}=1;
						$iData->{$goData{$a}->{$c}->{'array'}->[$j]}->{$goData{$a}->{$c}->{'array'}->[$i]}=1;
					}
				}
			}
			# if($count >= 5000){
			# 	$count=0;
			# 	# save complex data
			# 	eval{store($iData, "interactionData/savedStructures/geneOntology/$source/$a/GOdata_$source\ $a$fileNum.dat")};
			# 	if($@){die "Serious error from Storable storing $a GOdata_$source\ $a$fileNum.dat: $@";}
			# 	$iData=();
			# 	$fileNum++;
			# }
		}
		# save complex data
		# if we need to parse this data out more we would need to store all the info for a given ORF in each file...
		eval{store($iData, "interactionData/savedStructures/geneOntology/$source/$a/GOdata_$source\ $a$fileNum.dat")};
		if($@){die "Serious error from Storable storing all GOdata_$source\ $a$fileNum: $@";}
		$iData=();
		$fileNum++;
	}
	$iData=();
	%goData=();
	return $iData;
}

sub loadComplexData{
	my ($dataFrom) = @_;
	my %complexData;
	if($dataFrom eq 'benschop'){
		if(-e "interactionData/savedStructures/BenschopProteinComplexStandard.dat"){
			my $complexData = eval{retrieve("interactionData/savedStructures/BenschopProteinComplexStandard.dat")};
			if($@){	warn "Could not open BenschopProteinComplexStandard.dat\n$@";	}
			else{return $complexData;}
		}
		open (my $COMPLEXES, "<interactionData/BenschopProteinComplexStandard.txt") || return {'error' => "Couldn't open Benschop Protein Complex data.\n"};
		$/ = line_break_check( $COMPLEXES );
		my $header = <$COMPLEXES>;
		foreach(<$COMPLEXES>){
			chomp;
			my @data=split /\t/;
			my @orfs = split /\; /, $data[2];
			my $complex = $data[0];
			$complexData{'complexes'}->{$complex}->{'note'} = $data[6];
			foreach my $orf(@orfs){
				$complexData{'complexes'}->{$complex}->{'orfs'}->{$orf}=1;
				$complexData{'ids'}->{$orf}->{$complex}=1;
			}
		}
		close $COMPLEXES;
		# save complex data
		eval{store(\%complexData, "interactionData/savedStructures/BenschopProteinComplexStandard.dat")};
		if($@){warn "Serious error from Storable storing BenschopProteinComplexStandard.dat: $@";}
	}
	else{
		# column 1 = orf ID, 2 = gene name, 3 = complex name
		if(-e "interactionData/savedStructures/BaryshnikovaProteinComplexStandard.dat"){
			my $complexData = eval{retrieve("interactionData/savedStructures/BaryshnikovaProteinComplexStandard.dat")};
			if($@){	warn "Could not open BaryshnikovaProteinComplexStandard.dat\n$@";	}
			else{return $complexData;}
		}
		open (my $COMPLEXES, "<interactionData/BaryshnikovaProteinComplexStandard.txt") || return {'error' => "Could not load Baryshnikova data."};

		$/ = line_break_check( $COMPLEXES );
		foreach(<$COMPLEXES>){
			chomp;
			my @data=split /\t/;
			$complexData{'complexes'}->{$data[2]}->{'orfs'}->{$data[0]}=1;
			$complexData{'ids'}->{$data[0]}->{$data[2]}=1;
		}
		close $COMPLEXES;
		# save complex data
		eval{store(\%complexData, "interactionData/savedStructures/BaryshnikovaProteinComplexStandard.dat")};
		if($@){warn "Serious error from Storable storing BaryshnikovaProteinComplexStandard.dat: $@";}
	}
	return \%complexData;
}


# load data structures saved to disk
sub loadStructures{
	my $sN = shift; # $sN = short name
	my $source = shift; #

	# if the biogrid is stored in storable objects, just return those...
	if(#-e "interactionData/savedStructures/$source/$sN"."_counted_interactions.dat" &&
			-e "interactionData/savedStructures/$source/$sN"."_interactions.dat"
			#	&& -e "interactionData/savedStructures/$source/$sN"."_sources.dat"
			#		&& -e "interactionData/savedStructures/$source/$sN"."_systems.dat"
			){
			#	my $successfulLoad=1;
			#	my $ci = eval{retrieve("interactionData/savedStructures/$source/$sN"."_counted_interactions.dat")};
			#	if($@){
			#		$successfulLoad=0;
			#		warn "Could not open interactionData/savedStructures/$source/$sN"."_counted_interactions.dat. Serious issue with storable, try again or contact administrator.\n$@";
			#	}

				my $i = eval{Storable::retrieve("interactionData/savedStructures/$source/$sN"."_interactions.dat")};
				if($@){
					#$successfulLoad=0;
					die "Could not open interactionData/savedStructures/$source/$sN"."_interactions.dat. Serious issue with storable, try again or contact administrator.\n$@";
				}
				return $i;
				# my $sources = eval{retrieve("interactionData/savedStructures/$source/$sN"."_sources.dat")};
				# if($@){
				# 	$successfulLoad=0;
				# 	warn "Could not open interactionData/savedStructures/$source/$sN"."_sources.dat. Serious issue with storable, try again or contact administrator.\n$@";
				# }
				# my $sys = eval{retrieve("interactionData/savedStructures/$source/$sN"."_systems.dat")};
				# if($@){
				# 	$successfulLoad=0;
				# 	warn "Could not open interactionData/savedStructures/$source/$sN"."_systems.dat. Serious issue with storable, try again or contact administrator.\n$@";
				# }
				# if($successfulLoad){
				# 	return ($ci, $i, $sources, $sys);
				# }
	}
	#die "Could not open interactionData/savedStructures/$source/$sN"."_interactions.dat. Serious issue with storable, try again or contact administrator.\n$@";
	return 0;
}

# save data structures to disk
sub saveStructures{
	#my ($counted_interactions, $interactions, $sources, $systems, $shortName, $source)=@_;
	my ($interactions,$shortName, $source) = @_;
	# eval{store($counted_interactions, "interactionData/savedStructures/$source/$shortName"."_counted_interactions.dat")};
	# if($@){die "Serious error from Storable storing $shortName"."_counted_interactions.dat: $@";}
	eval{store($interactions, "interactionData/savedStructures/$source/$shortName"."_interactions.dat")};
	if($@){die "Serious error from Storable storing $shortName"."_interactions.dat: $@";}
	# eval{store($sources, "interactionData/savedStructures/$source/$shortName"."_sources.dat")};
	# if($@){die "Serious error from Storable storing $shortName"."_all_sources.dat: $@";}
	# eval{store($systems, "interactionData/savedStructures/$source/$shortName"."_systems.dat")};
	# if($@){die "Serious error from Storable storing $shortName"."_all_systems.dat: $@";}
	return 1;
}

sub buildGraph{
	my ($numNodes, $numEdges) = @_;
	my $numPossible = ($numNodes*($numNodes-1)/2);

	my @possibleEdges = (1..$numPossible);
	&fisher_yates_shuffle(\@possibleEdges);
	my $oneLess = $numNodes-1;
	my %g;
	%{$g{'orfs'}} = map { $_ => undef } (1..$numNodes);
	for(my $i = 0; $i < $numEdges; $i++){
		my $edgeNumber = $possibleEdges[$i];
		# below is the solution to the quadratic formula where
		# a = -1
		# b = 1
		# c = $numNodes*$oneLess-2*$edgeNumber
		my $approxAvalue = $numNodes-((-1-sqrt(1-(4*-1*(	$numNodes*$oneLess-2*$edgeNumber	)))) / -2);
		my $aValue = int($approxAvalue+0.999999999999);
		my $bValue = $numNodes - ((($aValue / 2) * ($oneLess + ($numNodes-$aValue)))-$edgeNumber);
		# build graph, enforce reciprocal interactions
		$g{'orfs'}->{$aValue}->{'interactor'}->{$bValue} = $g{'orfs'}->{$bValue}->{'interactor'}->{$aValue} = 1;
	}

	return \%g;
}



sub buildGraphBoost{
	# my ($numNodes, $numEdges) = @_;
	# my $numPossible = ($numNodes*($numNodes-1)/2);
	#
	#
	# use Boost::Graph;
	# my $g = new Boost::Graph(directed=>1, net_name=>'random', net_id=>100);
	#
	# my @possibleEdges = (1..$numPossible);
	# &fisher_yates_shuffle(\@possibleEdges);
	# my $oneLess = $numNodes-1;
	# my %g;
	# %{$g{'orfs'}} = map { $_ => undef } (1..$numNodes);
	# for(my $i = 0; $i < $numEdges; $i++){
	# 	my $edgeNumber = $possibleEdges[$i];
	# 	# below is the solution to the quadratic formula where
	# 	# a = -1
	# 	# b = 1
	# 	# c = $numNodes*$oneLess-2*$edgeNumber
	# 	my $approxAvalue = $numNodes-((-1-sqrt(1-(4*-1*(	$numNodes*$oneLess-2*$edgeNumber	)))) / -2);
	# 	my $aValue = int($approxAvalue+0.999999999999);
	# 	my $bValue = $numNodes - ((($aValue / 2) * ($oneLess + ($numNodes-$aValue)))-$edgeNumber);
	# 	# build graph, enforce reciprocal interactions
	# 	$g->add_edge($aValue,$bValue);
	# }
	#
	# return $g;
}


sub calcRandomGraphStatsNew{
	my ($v) = @_;

	my $groupNumber = 0;
	if(defined($q->param('groupNumber')) && $q->param('groupNumber') =~/^(0)$|^([1-9][0-9]*)$/){	$groupNumber = int($q->param('groupNumber'));	}
	elsif($q->param('groupNumber') eq '-cust'){$groupNumber='-cust';}
	else{	&exitProgram('Error validating uploaded data. Please try again or contact an administrator', "groupNumber = ".$q->param('groupNumber'));	}

	my $numNodes = &validatePositiveIntCGI('numNodes', '');
	my $noConnections = &validatePositiveIntCGI('noConnections', '');
	# if($numNodes < 1 || $noConnections > $numNodes){
	if( $numNodes < 1 ){ &exitProgram('Error validating uploaded data. Please try again or contact an administrator', "noConnections = $noConnections numNodes = $numNodes,  line = ". __LINE__); }
	#$numNodes -= $noConnections;

	my $numEdges = &validatePositiveIntCGI('numEdges', '');
	my $numPossible = ($numNodes*($numNodes-1)/2);
	if($numEdges < 1 || $numEdges > $numPossible){	&exitProgram('Error validating uploaded data. Please try again or contact an administrator', "ne: $numEdges, np: $numPossible");		}

	my $graph=&buildGraphBoost($numNodes, $numEdges);

	# warn $graph->nodecount();
	# warn $graph->edgecount();
	# my $coeffSig='';
	# my ($numNotConnectedNew, $randomMeanCoefficientNew, $total, $aveNotConnected)=(0,0,0,0);
	my $numberPermutations=1000;
	for(my $per=0; $per < $numberPermutations; $per++){
		$graph=&buildGraphBoost($numNodes, $numEdges);
	# 	$aveNotConnected+=$g->isolated_vertices();
	# 	$randomMeanCoefficientNew = $g->clustering_coefficient();
	# 	warn $randomMeanCoefficientNew;
	# 	$total+=$randomMeanCoefficientNew;
	}
	# $coeffSig .= "New = numNotConnectedNew --> ".($aveNotConnected / $numberPermutations)." $lb randomMeanCoefficientNew = ".&prettyPrintNumber( ( $total / $numberPermutations ) )."$lb";
	# print $coeffSig;
	#print "hi";
	#$numNodes += $noConnections;
	my %data = (
		'hiddens' => {
			'numNodes' => $numNodes,
			'noConnections' => $noConnections, # number of orfs without ANY connections to clik group
			'numEdges' => $numEdges,
			'randomStats' => 'true'
		},
		'divName' => "randomClikGroupStats",
		'groupNumber' => $groupNumber,
		'message' => "Run Random Stats Again?"
	);
	print &printCLIKgroupForm(\%data);

	return 1;
}



sub calcRandomGraphStats{
	my ($v) = @_;

	my $groupNumber = 0;
	if(defined($q->param('groupNumber')) && $q->param('groupNumber') =~/^(0)$|^([1-9][0-9]*)$/){	$groupNumber = int($q->param('groupNumber'));	}
	elsif($q->param('groupNumber') eq '-cust'){$groupNumber='-cust';}
	else{	&exitProgram('Error validating uploaded data. Please try again or contact an administrator', "groupNumber = ".$q->param('groupNumber').", line = ".__LINE__);	}

	my $numNodes = &validatePositiveIntCGI('numNodes', '');
	my $noConnections = &validatePositiveIntCGI('noConnections', '');
	$numNodes -= $noConnections;
	#if($numNodes < 1 || $noConnections > $numNodes){
	if( $numNodes < 1 ){	&exitProgram('Error validating uploaded data. Please try again or contact an administrator', "noConnections = ".$noConnections." numNodes = $numNodes or ".$q->param('numNodes')." line = ".__LINE__);}
	my $numEdges = &validatePositiveIntCGI('numEdges', '');
	my $numPossible = ($numNodes*($numNodes-1)/2);
	if($numEdges < 1 || $numEdges > $numPossible){	&exitProgram('Error validating uploaded data. Please try again or contact an administrator', "ne: $numEdges, np: $numPossible, line = ".__LINE__);		}


	my $coeffSig = 0;
	my $numberPermutations = 100;
	my $randomMeanCoefficientTotal = 0;
	my $randomMeanCoefficientTotalWithZeros = 0;
	for(my $per=0; $per < $numberPermutations; $per++){
		my $graph = &buildGraph($numNodes, $numEdges);
		my $numNotConnected=0;
		my $randomCoeffCount = 0;
		my $randomMeanCoefficient = 0;
		for(my $aNode=1; $aNode<=$numNodes; $aNode++){
			# find all neighbors
			my @neighbors = (defined $graph->{'orfs'}->{$aNode}) ?  keys %{$graph->{'orfs'}->{$aNode}->{'interactor'}} : ();
			my $coeffData = &calcClusteringCoeffientDirectedGraph(\@neighbors, $graph);
			if($coeffData->{'C'} >= 0){
				$randomCoeffCount++ ;
				$randomMeanCoefficient += $coeffData->{'C'};
			}
			else{$numNotConnected++;}
		}
		if($randomCoeffCount > 0){
			$randomMeanCoefficientTotalWithZeros += $randomMeanCoefficient / ($randomCoeffCount+$numNotConnected+$noConnections);
			$randomMeanCoefficient = $randomMeanCoefficient / $randomCoeffCount;
			$randomMeanCoefficientTotal += $randomMeanCoefficient;
		}
	}
	my $randomMeanCoefficient = &prettyPrintNumber(($randomMeanCoefficientTotal / $numberPermutations));
	my $randomMeanCoefficientWithZeros = &prettyPrintNumber(($randomMeanCoefficientTotalWithZeros / $numberPermutations));
	# without connections = $numNotConnected\ $lb\
	$coeffSig = "Using same variables as CLIK group:$lb# Connected Nodes = $numNodes -- # Edges = $numEdges,$lb\ Random Mean Coefficient = $randomMeanCoefficient$lb";#"$randomMeanCoefficient$lb$lb";
	$coeffSig .= "Random Mean Clustering Coefficient (including nodes w/ degree < 2) = $randomMeanCoefficientWithZeros$lb$lb";
	print $coeffSig;
	$numNodes += $noConnections;
	my %data = (
		'hiddens' => {
			'numNodes' => $numNodes,
			'noConnections' => $noConnections, # number of orfs without ANY connections to clik group
			'numEdges' => $numEdges,
			'randomStats' => 'true'
		},
		'divName' => "randomClikGroupStats",
		'groupNumber' => $groupNumber,
		'message' => "Run Random Stats Again?"
	);
	print &printCLIKgroupForm(\%data);

	return 1;
}

sub calcRandomORFStats{
	my ($v) = @_;

	my $groupNumber = 0;
	if(defined($q->param('groupNumber')) && $q->param('groupNumber') =~/^(0)$|^([1-9][0-9]*)$/){	$groupNumber = int($q->param('groupNumber')+0.5);	}
	elsif($q->param('groupNumber') eq '-cust'){$groupNumber='-cust';}
	else{	&exitProgram('Error validating uploaded data. Please try again or contact an administrator', "groupNumber = ".$q->param('groupNumber'));	}
	if(defined($q->param('dataSet')) && $q->param('dataSet') =~/^(0)$|^([1-9][0-9]*)$/){	$v->{'dataSet'} = int($q->param('dataSet')+0.5);	}
	else{	&exitProgram('Error validating previously uploaded data. Please try again or contact an administrator', "Error validating dataSet value: ".$q->param('dataSet'));	}
	my $numORFs=0;
	if(defined($q->param('numNodes')) && $q->param('numNodes') =~/^(0)$|^([1-9][0-9]*)$/){	$numORFs = int($q->param('numNodes')+0.5);	}
	else{	&exitProgram('Error validating uploaded data. Please try again or contact an administrator', "");	}
	if($numORFs < 1){	&exitProgram('Error validating uploaded data. Please try again or contact an administrator', "");		}

	my $dataDir = "$v->{'base_upload_dir'}/$v->{'user'}/$v->{'dataSet'}/";

	my $rData = eval{retrieve($dataDir."rankData.dat")};
	if($@){	&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}
	if($numORFs > $rData->{'size'}){
		&exitProgram("Error validating CLIK group size. Please contact the administrator.", "dating CLIK group size: $numORFs, $rData->{'size'}");
	}

	my $iCounts = eval{retrieve($dataDir."interactionCounts.dat")};
	if($@){	&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}

	my $coeffSig = 0;
	my $coeffStats = Statistics::Descriptive::Sparse->new();
	{
		my @random1 = @{$rData->{'orderedORFnames'}};
		my $numberPermutations = 10;
		for(my $per=0; $per < $numberPermutations; $per++){
			my $randomCoeffCount = 0;
			my $randomMeanCoefficient = 0;
			&fisher_yates_shuffle(\@random1);
			for(my $x=0; $x<$numORFs; $x++){
				my $A = $random1[$x]; # current orf
				# calculate connection coefficient
				my $coeffData = &calcClusteringCoefficientInArea($A, $iCounts, \@random1, 0, ($numORFs-1));
				if($coeffData->{'C'} >= 0){
					$randomCoeffCount++ ;
					$randomMeanCoefficient += $coeffData->{'C'};
				}
			}
			if($randomCoeffCount > 0){	$randomMeanCoefficient = $randomMeanCoefficient / $randomCoeffCount;}
			else{$randomMeanCoefficient=0;}
			$coeffStats->add_data($randomMeanCoefficient);
		}
	}
	my $noConnections = 0;
	#print &printCLIKgroupForm($v->{'dataSet'}, $numORFs, $noConnections, '', $groupNumber, 'Run again? calcRandomORFStats');
	$coeffSig = "Mean Clustering Coefficient of $numORFs random genes = ".&prettyPrintNumber($coeffStats->mean())."$lb<hr/>";#"$randomMeanCoefficient$lb$lb";

	print $coeffSig;

	return 1;
}

sub calcCustomCLIK{
	my ($v) = @_;

	# validate input data
	if(defined($q->param('dataSet')) && $q->param('dataSet') =~/^(0)$|^([1-9][0-9]*)$/){	$v->{'dataSet'} = int($q->param('dataSet')+0.5);	}
	else{	&exitProgram('Error validating previously uploaded data. Please try again or contact an administrator.'.$lb, "Error validating dataSet value.");	}

	my $startX = &validatePositiveIntCGI('startX', 'start x-value');
	my $endX = &validatePositiveIntCGI('endX', 'end x-value');
	if(($endX - $startX) < 5){
		&exitProgram('Error validating x-range data. The CLIK window coordinates must each be at least 5 units apart with the end value being the larger value.'.$lb, 'Error validating X range. line '.__LINE__);
	}

	my $startY = &validatePositiveIntCGI('startY', 'start y-value');
	my $endY = &validatePositiveIntCGI('endY', 'end y-value');
	if(($endY - $startY) < 5){
		&exitProgram('Error validating y-range data. The CLIK window coordinates must each be at least 5 units apart with the end values being the larger values.'.$lb, "");
	}

	my $iData;
	if(defined($q->param('numBootStraps')) && $q->param('numBootStraps') =~/^(0)$|^([1-9][0-9]*)$/){	$iData->{'numberOfBootStraps'} = int($q->param('numBootStraps')+0.5);	}
	else{	$iData->{'numberOfBootStraps'}=50;	}

	$iData->{'complexDataset'} = 'baryshnikova';
	if(defined($q->param('complexData')) && $q->param('complexData') eq 'benschop'){	$iData->{'complexDataset'} = 'benschop';}

	my $xSize = $endX - $startX;
	my $ySize = $endY - $startY;
	# retrieve data structures
	my $dataDir = "$v->{'base_upload_dir'}/$v->{'user'}/$v->{'dataSet'}/";
	my $gData = eval{retrieve($dataDir."graphData.dat")};
	if($@){&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}

	my $rData = eval{retrieve($dataDir."rankData.dat")};
	if($@){exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}
	&setupORFoutputSub($rData);

	my $dData = eval{retrieve($dataDir."densityValues.dat");};
	if($@){&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");}

	my $iCounts = eval{retrieve($dataDir."interactionCounts.dat")};
	if($@){	&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}

	my $pData = eval{retrieve($dataDir."plotData.dat")};
	if($@){	&exitProgram("Problem retrieving data. Please contact the administrator.", "$@");	}

	if($endX > $rData->{'size'}){
		&exitProgram("Error validating x-range data. The maximum x-value you can enter cannot be larger than the size of the dataset you are analyzing ($rData->{'size'} members).$lb");
	}
	if($endY > $rData->{'size'}){
		&exitProgram("Error validating y-range data. The maximum y-value you can enter cannot be larger than the size of the dataset you are analyzing ($rData->{'size'} members).$lb", "Error max Y value.");
	}

	my %outputs;
	$outputs{'webOutput'} = "";
	$outputs{'endWebOutput'} = $lb;
	# subtract 1 from values since indices start at 0 and not 1
	$startX--;
	$endX--;
	$startY--;
	$endY--;

	# my $yGraphStart = $rData->{'size'} - $endY;
	# my $yGraphEnd = $rData->{'size'} - $startY;
	my $yGraphStart = $startY;
	my $yGraphEnd = $endY;
	my $meanDensity=0;
	my $numberInteractions=0;
	my $maxDensityInGroup = 0;


	foreach my $density(keys %{$dData->{'ordered'}->{'densities'}}){
		X:foreach my $x(keys %{$dData->{'ordered'}->{'densities'}->{$density}}){
			next X if($x<$startX || $x > $endX);
			Y:foreach my $y(keys %{$dData->{'ordered'}->{'densities'}->{$density}->{$x}}){
				next Y if($y<$yGraphStart || $y > $yGraphEnd);
				$numberInteractions++;
				$meanDensity += $density;
				if($density > $maxDensityInGroup){ $maxDensityInGroup = $density;}
			}
		}
	}

	$dData = (); # clear memory
	$meanDensity = $meanDensity / $numberInteractions;
	$meanDensity = &prettyPrintNumber($meanDensity);
	$maxDensityInGroup = &prettyPrintNumber($maxDensityInGroup);

	$outputs{'webOutput'} .= "<span style='font-weight:bold;'>Mean Density = $meanDensity</span>$lb";
	$outputs{'webOutput'} .= "<span style='font-weight:bold;'>Max Density = $maxDensityInGroup</span>";
	$outputs{'fhOutput'} = "Custom CLIK Group\n";
	$outputs{'fhOutput'} .= "Mean Density = $meanDensity\n";
	$outputs{'fhOutput'} .= "Max Density = $maxDensityInGroup\n";

	&outputCLIKgroupORFs($startX, $endX, $startY, $endY, $gData, $rData, $iCounts, \%outputs, '-cust', $pData->{'binWidth'}, $v->{'dataSet'});
	open (my $fh, ">$gData->{'imageDir'}$gData->{'imageFileName'}-customCLIKgroup.txt") || die "could not open custom clik group output file: $!";
	print $fh $outputs{'fhOutput'};
	close $fh;

	my $string = "<fieldset class='clikGroup' style='margin-top:20px;'><legend><strong id='customClikGroup'>Custom CLIK Group";
	#$string .= " -- <a href=\"download.cgi?ID=".CGI::escape("$v->{'user'}/$gData->{'imageFileName'}-customCLIKgroup.txt")."\" class='ext_link'>Download CLIK group stats</a>";
	$string .= "</strong></legend>";
	$string .= $outputs{'webOutput'};
	print $string;
	return 1;
}

sub prettyPrintNumber{
	my $number = shift;
	if(!defined $number){return 0;}
	$number = ($number < 0.001 || $number == 0) ? sprintf('%.2e',$number) : sprintf("%.3f",$number);
	return $number;
}

sub overlayClikData{
	my $gData = shift;
	my $widthAdjuster = $gData->{'plotWidth'} / $gData->{'imageWidth'};
	my $heightAdjuster = $gData->{'plotWidth'} / ($gData->{'imageHeight'}-$gData->{'bottomBorderOffset'});
	my $css='';
	foreach my $clik(keys %{$gData->{'clikCoordinates'}}){
		$css.=".c$clik"."{left:".int($gData->{'clikCoordinates'}->{$clik}->[0]*$widthAdjuster).";top:".int($gData->{'clikCoordinates'}->{$clik}->[1]*$heightAdjuster).";}";
	}
	return $css;
}


sub plot2dHistogram{
	my ($gData, $rData, $dData, $iCounts, $pData, $iData, $dirNumber) = @_;

	my %outputs;

	# initialize sigValues
	my %sigValues;

	$outputs{'fhOutput'} .= "Group with maximum density marked with '***'$lb$lb";
	my %sigDensities;
	# minimum density that we will consider as significant - currently set to densities > the density that corresponds to a z-score of 0.5 + the 'densityCorrection'
	my $zThresh = 0.5;
	$pData->{'densitySignificantLimit'} = $zThresh * $dData->{'orderedStdDev'} + $dData->{'orderedMean'} + $dData->{'densityCorrection'};
	# warn "\n4nM rapamycin, z-score = $zThresh\n";
	# warn "z-score of background density (ordered mean and std dev) = ".(($dData->{'densityCorrection'} - $dData->{'orderedMean'})/$dData->{'orderedStdDev'});
	# warn "z-score = ".(($pData->{'densitySignificantLimit'} - $dData->{'orderedMean'})/$dData->{'orderedStdDev'});
	DEN: foreach my $density(sort {$b<=>$a} keys %{$dData->{'ordered'}->{'densities'}}){
		if($density > $pData->{'densitySignificantLimit'}){
			foreach my $x(keys %{$dData->{'ordered'}->{'densities'}->{$density}}){
				foreach my $y(keys %{$dData->{'ordered'}->{'densities'}->{$density}->{$x}}){
					push(@{$sigDensities{$density}->{$x}}, $y);
				}
			}
			delete $dData->{'ordered'}->{'densities'}->{$density}; # delete some data to recover memory
		}
		else{last DEN;}
	}

	$dData->{'ordered'}->{'densities'}=();
	# sort significant density values, least significant 1st
	my @scores = (sort {$a <=> $b} keys %sigDensities);
	my ($minDen, $maxDen) = (0,0);
	if($iData->{'autoScaleDensityColors'} eq 'no'){
		$minDen = $iData->{'startScale'};
		$maxDen = $iData->{'endScale'};
	}
	else{
		$minDen = $scores[0] || 0;
		$maxDen = $scores[-1] || 0;
	}
	my $colorScaleModel;
	my ($arg1, $arg2);
	# if ($minDen*2) <= $maxDen use those values as the limits of the color scale
	my $scoreScaler;
	if(($minDen*2) <= $maxDen || $iData->{'autoScaleDensityColors'} eq 'no'){
		$colorScaleModel = \&absoluteColorScaleCalc;
		$pData->{'colorScaleModel'} = 'abs';
		$arg1 = $minDen;
		if($iData->{'autoScaleDensityColors'} ne 'no'){
			# ensure max is at least 5x min
			$maxDen = (($minDen*5) > $maxDen) ? ($minDen*5) : $maxDen;
		}
		$scoreScaler = ($maxDen-$minDen)/ $#{$gData->{'orderedColor'}};
		$arg2 = $scoreScaler;
	}
	# else use z-scores
	else{
		$colorScaleModel = \&zScoreColorScaleCalc;
		$pData->{'colorScaleModel'}='z';
		$arg1 = $dData;
		$arg2 = '';
		$scoreScaler = $dData->{'orderedStdDev'};
	}
	$pData->{'colorScaleModelArg1'}=$arg1; $pData->{'colorScaleModelArg2'}=$arg2;
	# really storing colors in this array, but the colors are based on the density values
	@{$gData->{'diagonalDensities'}} = ();
	$gData->{'diagonalDensities'}->[$rData->{'size'}-1]=undef;
	# my $initialDiagonalScore = $rData->{'size'}*-1;
	foreach my $density(@scores){
		foreach my $x(keys %{$sigDensities{$density}}){
			Y:foreach my $y(@{$sigDensities{$density}->{$x}}){
				my $score = $colorScaleModel->($density, $arg1, $arg2);
				{
					my $scaledX = ($x / $gData->{'imageScaler'})+$gData->{'leftBorderOffset'}; # calculate where to plot this x value on the actual image
					my $scaledY = ($rData->{'size'} - $y) / $gData->{'imageScaler'} + $gData->{'topBorderOffset'};	# calculate where to plot this y value on the actual image
					$gData->{'imgObject'}->moveTo($scaledX,$scaledY); # move to ellipse position
				}
				# score is low...
				if($score < 0){
					my $ellipseSize = int($gData->{'randomPlotPointSize'} * $gData->{'randomPlotPointMultiplier'});
					$gData->{'imgObject'}->fgcolor('lightgrey'); # set foreground color
					$gData->{'imgObject'}->bgcolor('lightgrey'); # set background color
					$gData->{'imgObject'}->ellipse($ellipseSize,$ellipseSize);	 # draw ellipse
					next Y;
				}
				else{
					# if $density is super significant and > than the number of colors
					# available, automatically set is to the most significant color...
					my $color = ( int($score*1.2+0.5) > $#{$gData->{'orderedColor'}}) ? $#{$gData->{'orderedColor'}} : int($score*1.2+0.5);
					my $ellipseSize = int($gData->{'orderedPlotPointMultiplier'} * $gData->{'orderedSizeMultiplier'}->[$color])+2;
					$gData->{'imgObject'}->fgcolor($gData->{'orderedColor'}->[$color]); # set foreground color
					$gData->{'imgObject'}->bgcolor($gData->{'orderedColor'}->[$color]); # set background color
					$gData->{'imgObject'}->ellipse($ellipseSize,$ellipseSize);	 # draw ellipse

					my $diff = abs($x-$y);
					# if this point is close the the diagonal (within 1 bin width)
					if($diff < $iData->{'binWidth'}){
						# store color of this point for reference later in coloring ORF names. To do this take the mean
						# of the 2 points which is similar to drawing a perpendicular line to the diagonal
						my $perpendicular = int(($x+$y)/2+0.5);
						if(!defined $gData->{'diagonalDensities'}->[$perpendicular] || $gData->{'diagonalDensities'}->[$perpendicular] < $color){
							$gData->{'diagonalDensities'}->[$perpendicular]=$color;
						}
					}
				}

				# get bounds of this point
				my $minX = $x-$pData->{'halfWidth'};
				my $maxX = $x+$pData->{'halfWidth'};
				my $minY = $y-$pData->{'halfWidth'};
				my $maxY = $y+$pData->{'halfWidth'};

				my @possibleXenrichmentGroups=();
				foreach my $enrichmentGroup(keys %{$sigValues{'x'}}){
					# only 2 conditions are needed to exclude the current point from an enrichmentGroup, so do the opposite to check for inclusion
					# -----------
					# 							-------- # minX > maxPlot

					# 						---------
					# 		------						# maxX < minPlot
					if(	$minX < $sigValues{'x'}->{$enrichmentGroup}->{'maxPlot'} && $maxX > $sigValues{'x'}->{$enrichmentGroup}->{'minPlot'}){
						push(@possibleXenrichmentGroups, $enrichmentGroup);
					}
				} # end for each enrichmentGroup
				# iterate over @possibleXenrichmentGroups and check to see if the y values fall within range, same as above
				my @possibleYenrichmentGroups=();

				foreach my $enrichmentGroup(@possibleXenrichmentGroups){
					if(  $minY < $sigValues{'y'}->{$enrichmentGroup}->{'maxPlot'} && $maxY > $sigValues{'y'}->{$enrichmentGroup}->{'minPlot'} ){
						push(@possibleYenrichmentGroups, $enrichmentGroup);
					}
				} # end for each enrichmentGroup
				# if x and y values do not fall within any existing enrichment group, create a new one
				if(!@possibleYenrichmentGroups){
					my $i=scalar(keys %{$sigValues{'x'}})+1;
					while(defined $sigValues{'x'}->{$i}){$i++;}
					$sigValues{'x'}->{$i}->{'minPlot'}=$minX;
					$sigValues{'x'}->{$i}->{'minActualX'}=$x;
					$sigValues{'x'}->{$i}->{'maxActualX'}=$x;
					$sigValues{'x'}->{$i}->{'maxPlot'}=$maxX;
					$sigValues{'y'}->{$i}->{'minPlot'}=$minY;
					$sigValues{'y'}->{$i}->{'maxPlot'}=$maxY;
					$sigValues{'y'}->{$i}->{'minActualY'}=$y;
					$sigValues{'y'}->{$i}->{'maxActualY'}=$y;
					$sigValues{'x'}->{$i}->{'count'}=1;
					$sigValues{'x'}->{$i}->{'densitySum'} = $density;
					$sigValues{'x'}->{$i}->{'maxDensity'}=$density;
					$sigValues{'x'}->{$i}->{'maxDensityX'}=$x;
					$sigValues{'y'}->{$i}->{'maxDensityY'}=$y;

				} # end if
				# else we have found an enrichment group (possibly more than 1). Set the 1st one as the new group and collapse the other ones to it.
				else{
					my $eg = $possibleYenrichmentGroups[0];
					# expand out range of eg, if needed
					if ($minX < $sigValues{'x'}->{$eg}->{'minPlot'}){
						$sigValues{'x'}->{$eg}->{'minPlot'}=$minX;
						$sigValues{'x'}->{$eg}->{'minActualX'}=$x;
					}
					if ($minY < $sigValues{'y'}->{$eg}->{'minPlot'}){
						$sigValues{'y'}->{$eg}->{'minPlot'}=$minY;
						$sigValues{'y'}->{$eg}->{'minActualY'}=$y;
					}
					if ($maxX > $sigValues{'x'}->{$eg}->{'maxPlot'}){
						$sigValues{'x'}->{$eg}->{'maxPlot'}=$maxX;
						$sigValues{'x'}->{$eg}->{'maxActualX'}=$x;
					}
					if ($maxY > $sigValues{'y'}->{$eg}->{'maxPlot'}){
						$sigValues{'y'}->{$eg}->{'maxPlot'}=$maxY;
						$sigValues{'y'}->{$eg}->{'maxActualY'}=$y;
					}

					if($density > $sigValues{'x'}->{$eg}->{'maxDensity'}){
						$sigValues{'x'}->{$eg}->{'maxDensity'} = $density;
						$sigValues{'x'}->{$eg}->{'maxDensityX'} = $x;
						$sigValues{'y'}->{$eg}->{'maxDensityY'} = $y;
					}

					$sigValues{'x'}->{$eg}->{'densitySum'} += $density;
					$sigValues{'x'}->{$eg}->{'count'}++;

					# now iterate over all of the other possible enrichment groups - they should all overlap so incorporate them into $eg, expanding eg as needed
					for(my $pEG=1; $pEG < @possibleYenrichmentGroups; $pEG++){

						# all of these should overlap, find absolute min and max values, delete references, then create new enrichment group with absolute min and max values
						if($sigValues{'x'}->{$eg}->{'minPlot'} > $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'minPlot'}){
							$sigValues{'x'}->{$eg}->{'minPlot'} = $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'minPlot'};
							$sigValues{'x'}->{$eg}->{'minActualX'} = $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'minActualX'};
						}
						if ($sigValues{'y'}->{$eg}->{'minPlot'} > $sigValues{'y'}->{$possibleYenrichmentGroups[$pEG]}->{'minPlot'}){
							$sigValues{'y'}->{$eg}->{'minPlot'} = $sigValues{'y'}->{$possibleYenrichmentGroups[$pEG]}->{'minPlot'};
							$sigValues{'y'}->{$eg}->{'minActualY'} = $sigValues{'y'}->{$possibleYenrichmentGroups[$pEG]}->{'minActualY'};
						}
						if ($sigValues{'x'}->{$eg}->{'maxPlot'} < $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'maxPlot'}){
							$sigValues{'x'}->{$eg}->{'maxPlot'} = $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'maxPlot'};
							$sigValues{'x'}->{$eg}->{'maxActualX'} = $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'maxActualX'};
						}
						if ($sigValues{'y'}->{$eg}->{'maxPlot'} < $sigValues{'y'}->{$possibleYenrichmentGroups[$pEG]}->{'maxPlot'}){
							$sigValues{'y'}->{$eg}->{'maxPlot'} = $sigValues{'y'}->{$possibleYenrichmentGroups[$pEG]}->{'maxPlot'};
							$sigValues{'y'}->{$eg}->{'maxActualY'} = $sigValues{'y'}->{$possibleYenrichmentGroups[$pEG]}->{'maxActualY'};
						}

						if($sigValues{'x'}->{$eg}->{'maxDensity'} < $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'maxDensity'}){
							$sigValues{'x'}->{$eg}->{'maxDensity'} = $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'maxDensity'};
							$sigValues{'x'}->{$eg}->{'maxDensityX'} = $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'maxDensityX'};
							$sigValues{'y'}->{$eg}->{'maxDensityY'} = $sigValues{'y'}->{$possibleYenrichmentGroups[$pEG]}->{'maxDensityY'};
						}

						$sigValues{'x'}->{$eg}->{'densitySum'} += $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'densitySum'};
						$sigValues{'x'}->{$eg}->{'count'} += $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]}->{'count'};

						# delete the ref to this group
						delete $sigValues{'x'}->{$possibleYenrichmentGroups[$pEG]};
						delete $sigValues{'y'}->{$possibleYenrichmentGroups[$pEG]};
					} # end for my $pEG
				} # end else of if(! @possibleXenrichmentGroups || ! @possibleYenrichmentGroups)
				#print " --> size = $Density, color = $color --> $densityValues{$x}->{$y} $lb";
			} # end foreach my $y(@{$densityValues{$density}->{$x}})
		} # end foreach my $x(keys %{$densityValues{$density}})
	} # end foreach my $density(sort {$a <=> $b} keys %densityValues


	# delete redundant / overlapping enrichment groups
	my %densityMeans;
	foreach my $enrichmentGroup(keys %{$sigValues{'x'}}){

		# if there is data in this enrichment group
		if($sigValues{'x'}->{$enrichmentGroup}){
			my $startX = $sigValues{'x'}->{$enrichmentGroup}->{'minPlot'}; # x range start
			my $endX = $sigValues{'x'}->{$enrichmentGroup}->{'maxPlot'}; # x range end
			my $endY = $sigValues{'y'}->{$enrichmentGroup}->{'maxPlot'}; # y-range end
			my $startY = $sigValues{'y'}->{$enrichmentGroup}->{'minPlot'}; # y range start
			#warn "\nbefore: $enrichmentGroup --> $startX-$endX,  $startY-$endY";
			#warn "y range = $startY ($sigValues{'y'}->{$enrichmentGroup}->{'maxActualY'}) - $endY ($sigValues{'y'}->{$enrichmentGroup}->{'minActualY'})";
			# if this clik group lies on the diagonal, make it square
			if( ($startX >= $startY && $startX <= $endY) || # if startX is in the bounds of the y range
					($startY >= $startX && $startY <= $endX)  # or if endX is in the y range
				){
					# we are square!
					$sigValues{'x'}->{$enrichmentGroup}->{'square'}=1;
					my $lowerLimit = ($startX < $startY) ? $startX : $startY;
					my $upperLimit = ($endX < $endY) ? $endY : $endX;
					# update values
					$startX = $lowerLimit; # x range start
					$endX = $upperLimit; # x range end
					$startY = $lowerLimit; # y-range end
					$endY = $upperLimit; # y range start
					$sigValues{'x'}->{$enrichmentGroup}->{'minPlot'}=$lowerLimit;
					$sigValues{'x'}->{$enrichmentGroup}->{'maxPlot'}=$upperLimit;
					$sigValues{'y'}->{$enrichmentGroup}->{'minPlot'}=$lowerLimit;
					$sigValues{'y'}->{$enrichmentGroup}->{'maxPlot'}=$upperLimit;
			}


			#warn "$enrichmentGroup --> $startX $endX, minY $startY $endY" if($endX < 300 && $endY < 300);
			foreach my $eg(keys %{$sigValues{'x'}}){
				if($eg && $eg != $enrichmentGroup){
					# delete enrichment groups that are fully encompassed by others
					if( $startX < $sigValues{'x'}->{$eg}->{'minPlot'} &&
								$startY < $sigValues{'y'}->{$eg}->{'minPlot'} &&
								$endX > $sigValues{'x'}->{$eg}->{'maxPlot'} &&
								$endY > $sigValues{'y'}->{$eg}->{'maxPlot'})
							{
								$sigValues{'x'}->{$enrichmentGroup}->{'densitySum'} += $sigValues{'x'}->{$eg}->{'densitySum'};
								$sigValues{'x'}->{$enrichmentGroup}->{'count'} += $sigValues{'x'}->{$eg}->{'count'};
								# instead of a hash merge store a ref to the other group
								delete $sigValues{'x'}->{$eg};
								delete $sigValues{'y'}->{$eg};
								if( defined $densityMeans{$eg}){ delete $densityMeans{$eg};}
							#	warn "deleting $eg (plots || actual), pushing to $enrichmentGroup? --> $startX $endX, minY $startY $endY\n\n";
					}
				}
			}

		} # end if
		else{
			delete $sigValues{'x'}->{$enrichmentGroup};
			delete $sigValues{'y'}->{$enrichmentGroup};
		}
	}
	# delete enrichment groups that contain fewer than $minMembers members
	foreach my $enrichmentGroup(keys %{$sigValues{'x'}}){
		if(
				(($sigValues{'x'}->{$enrichmentGroup}->{'maxActualX'} - $sigValues{'x'}->{$enrichmentGroup}->{'minActualX'}) < $gData->{'minMembers'}) ||
				(($sigValues{'y'}->{$enrichmentGroup}->{'maxActualY'} - $sigValues{'y'}->{$enrichmentGroup}->{'minActualY'}) < $gData->{'minMembers'})
			){
			#warn "Deleting --> $enrichmentGroup --> $sigValues{'x'}->{$enrichmentGroup}->{'minPlot'} - $sigValues{'x'}->{$enrichmentGroup}->{'maxPlot'}, $sigValues{'x'}->{$enrichmentGroup}->{'minPlot'} - $sigValues{'y'}->{$enrichmentGroup}->{'maxPlot'} --> ".($sigValues{'x'}->{$enrichmentGroup}->{'maxPlot'} - $sigValues{'x'}->{$enrichmentGroup}->{'minPlot'})." --> ".($sigValues{'y'}->{$enrichmentGroup}->{'maxPlot'} - $sigValues{'y'}->{$enrichmentGroup}->{'minPlot'});
			delete $sigValues{'x'}->{$enrichmentGroup};
			delete $sigValues{'y'}->{$enrichmentGroup};
			if( defined $densityMeans{$enrichmentGroup}){ delete $densityMeans{$enrichmentGroup};}
			#warn "deleting $enrichmentGroup (too few X or Y)\n\n";
		}
		else{$densityMeans{$enrichmentGroup} = $sigValues{'x'}->{$enrichmentGroup}->{'densitySum'} / $sigValues{'x'}->{$enrichmentGroup}->{'count'};}
	}
	# END PLOTTING DATA POINTS!!!
	# ********************************************************
	# find max using built in sort since we only expect a few enrichment groups
	my ($maxMean) = sort { $b <=> $a } values %densityMeans;
	# below algorithm to determine max is more efficient but ONLY for larger datasets, for
	# smaller datasets using perl's built in sort is optimal
	# my $max;
	# while ((undef, my $val) = each %densityMeans) {
	#     $max ||= $val;
	#     $max = $val if $val >= $max;
	# }
	# use Data::Dumper;
	# warn Dumper \@diagonalDensities;
	# BEGIN PLOTTING ENRICHMENT GROUP LABELS
	$gData->{'imgObject'}->bgcolor(undef);
	#warn "\n\n\n";
	$outputs{'webOutput'} = "</div><hr/>$lb<h2>CLIK GROUP DETAILS</h2><em>CLIK group numbers indicate which label they map to on the CLIK graph above.";
	$outputs{'webOutput'} .= " Gene names are colored according the the color of the diagonal at that point in the rank order.</em>$lb$lb";
	my $groupNumber=1; # reset CLIK group numbering to 1.
	my $numGroups=scalar(keys %{$sigValues{'x'}});
	my $bm='';

	# warn &buildJSON_network($iCounts);

	foreach my $enrichmentGroup(sort {$a<=>$b} keys %{$sigValues{'x'}}){

		&progressHook(80+($groupNumber/$numGroups*20), "Calculating CLIK group statistics");

		# calculate x range
		my $startX = int($sigValues{'x'}->{$enrichmentGroup}->{'minActualX'}+0.5); # x range start
		$startX = 0 if($startX<0);
		my $endX = int($sigValues{'x'}->{$enrichmentGroup}->{'maxActualX'}+0.5); # x range end
		$endX=$rData->{'size'} if($endX>$rData->{'size'});
		# calculate y range
		my $endY = int($sigValues{'y'}->{$enrichmentGroup}->{'maxActualY'}+0.5); # y range start
		$endY=$rData->{'size'} if($endY>$rData->{'size'});
		my $startY = int($sigValues{'y'}->{$enrichmentGroup}->{'minActualY'}+0.5); # y-range end
		$startY = 0 if($startY<0);

		my $maxDensityInGroup=$sigValues{'x'}->{$enrichmentGroup}->{'maxDensity'}; # maximum density value of data in current clik group
		my $meanDensity = $densityMeans{$enrichmentGroup};
		my $style='style="font-weight:bold;';
		my $maxGroup = '';
		# if this clik group contains greatest density mean, style it so that it stands out
		if($maxMean eq $meanDensity){

			#warn Dumper($sigValues{'x'}->{$enrichmentGroup});
			#warn Dumper($sigValues{'y'}->{$enrichmentGroup});
			$style .= 'color:blue;font-size:1.3em;font-weight:bold;';
			$maxGroup="***";
			$gData->{'maxGroup'}="c$groupNumber";
		}
		$style.='"';

		$maxDensityInGroup = &prettyPrintNumber($maxDensityInGroup);
		$meanDensity = &prettyPrintNumber($meanDensity);
		$outputs{'webOutput'} .= "<fieldset class='clikGroup'><span class='sprite-plus' onclick='showHideDiv(this);'>";
		$outputs{'webOutput'} .= "<strong id='c$groupNumber' $style>GROUP #$groupNumber";
		$outputs{'webOutput'} .= "$lb<span $style>Mean Density = $meanDensity</span>$lb";
		$outputs{'webOutput'} .= "<span $style>Max Density = $maxDensityInGroup</span>";
		$outputs{'webOutput'} .= "$lb\ X Range = ".($startX+1)." - ".($endX+1)."  | Y range = ".($startY+1)." - ".($endY+1)."</strong>";
		# $outputs{'webOutput'} .= "$lb\ Recommended diagonal cutoff ~ ".abs($sigValues{'x'}->{$enrichmentGroup}->{'maxDiagonalScore'})."";
		$outputs{'webOutput'} .= " <small style='float:right;' class='href' onclick=\"parent.scrollTo(0,(parent.document.getElementById('results').offsetTop+document.getElementById('clikGraph').offsetTop));\"> back to top</small>";
		$outputs{'webOutput'} .= "</span><div id='content_c$groupNumber' style='display:none'>";

		$outputs{'endWebOutput'} = $lb;

		$outputs{'fhOutput'}.= "$maxGroup GROUP # $groupNumber\tMax Density = $maxDensityInGroup\n";

		my $preStart = new Benchmark;

		&outputCLIKgroupORFs($startX, $endX, $startY, $endY, $gData, $rData, $iCounts, \%outputs, $groupNumber, $iData->{'binWidth'}, $dirNumber);

		my $start = new Benchmark;
		$bm .= "$lb Time taken calculate clik group stat $groupNumber ($sigValues{'x'}->{$enrichmentGroup}->{'count'})(in plot2dhisto) was ". timestr(timediff($start, $preStart), 'all'). " seconds$lb";

		# calculate the point on the image that corresponds to the center of density for this CLIK group.
		my $scaledXcenter = ($sigValues{'x'}->{$enrichmentGroup}->{'maxDensityX'} / $gData->{'imageScaler'}) + $gData->{'leftBorderOffset'};
		my $scaledYcenter = ($rData->{'size'} - $sigValues{'y'}->{$enrichmentGroup}->{'maxDensityY'}) / $gData->{'imageScaler'} + $gData->{'topBorderOffset'};

		my ($width,$height)=$gData->{'imgObject'}->stringBounds($groupNumber);
		# prevent labels from being printed out of the plot area bounds}
		my $x = (($scaledXcenter+$width) >= $gData->{'imageWidth'}) ? ($gData->{'imageWidth'} - $width) : ($scaledXcenter);
		my $y = ( ($scaledYcenter-$height) <= $gData->{'topBorderOffset'}  ) ? $gData->{'topBorderOffset'}+$height  : $scaledYcenter ;
		$x = $gData->{'leftBorderOffset'} if $x<$gData->{'leftBorderOffset'};

		$gData->{'imgObject'}->moveTo($x,$y);

		# get pixel at this point - if dark then color font white, else make black
		my @rgb = $gData->{'imgObject'}->rgb($gData->{'imgObject'}->getPixel($x,$y));
		my $brightness = &preceivedBrightness(\@rgb);
		if($brightness < 130){$gData->{'imgObject'}->fgcolor('white');}
		else{$gData->{'imgObject'}->fgcolor('black');}

		$gData->{'clikCoordinates'}->{$groupNumber}=[$x,($y-$height)];
		$gData->{'imgObject'}->string($groupNumber);


		$groupNumber++;
		delete $sigValues{'x'}->{$enrichmentGroup};
		delete $sigValues{'y'}->{$enrichmentGroup};
	}

	for(my $i=$rData->{'size'}-1;$i>0;$i--){
		$outputs{'webOutput'} = ", <span title='".($i+1)."'>$rData->{'orderedORFnames'}->[$i]</span>$outputs{'webOutput'}";
	}
	$outputs{'webOutput'}.="<br style='clear:both' />";
	if(defined $gData->{'maxGroup'}){
		return ("<span class='href' onclick=\"scrollToID('$gData->{'maxGroup'}');\">Jump to most enriched CLIK</span>$lb$lb<div id='allORFs' style=\"display:none;\"><span title='1'>$rData->{'orderedORFnames'}->[0]</span>$outputs{'webOutput'}", $outputs{'fhOutput'}, $minDen, $scoreScaler, 1, $bm);
	}
	else{
		return ("<span>No CLIK enrichment found :-(</span>\n\n<div id='allORFs' style=\"display:none;\"><span title='1'>$rData->{'orderedORFnames'}->[0]</span>$outputs{'webOutput'}", $outputs{'fhOutput'},$minDen, $scoreScaler, 0, $bm);
	}
}

sub preceivedBrightness{
	# from http://www.nbdtech.com/Blog/archive/2008/04/27/Calculating-the-Perceived-Brightness-of-a-Color.aspx
	my $rgb = shift;
	return int(($rgb->[0]*$rgb->[0]*0.241 + $rgb->[1]*$rgb->[1]*0.691 + $rgb->[2]*$rgb->[2]*0.068)**0.5);
}

sub zScoreColorScaleCalc{
	my $density = shift;
	my $dData = shift;
	my $zScore = ( ($density-$dData->{'densityCorrection'}) - $dData->{'orderedMean'})/$dData->{'orderedStdDev'} ;
	return $zScore;
}

sub absoluteColorScaleCalc{
	my ($density, $minDen, $scoreScaler) = @_;
	my $scale = ( $density - $minDen) / $scoreScaler;
	return $scale;
}

# print x and y axis labels...
sub printGraphAxis{
	my ($rData, $gData) = @_;
	my ($width,$height);
	# scaledSize = width and height of actual plotting area (excluding the area where the axis information is printed) - only used for y position mapping
	my $scaledXsize =$rData->{'size'} / $gData->{'imageScaler'}+$gData->{'leftBorderOffset'};
	my $scaledYSize =$rData->{'size'} / $gData->{'imageScaler'} + $gData->{'topBorderOffset'};
	$gData->{'xLabel'} = (defined $gData->{'xLabel'}) ? $gData->{'xLabel'} : "Rank";
	$gData->{'yLabel'} = (defined $gData->{'yLabel'}) ? $gData->{'yLabel'} : "Rank";
	$gData->{'imgObject'}->fgcolor('black');
	$gData->{'imgObject'}->bgcolor(undef);

	$gData->{'imgObject'}->angle(-90);
	($width,$height)=$gData->{'imgObject'}->stringBounds($gData->{'yLabel'});
	$gData->{'imgObject'}->moveTo(($gData->{'leftBorderOffset'}-$width-3),(($scaledYSize+$gData->{'leftBorderOffset'})/2));
	$gData->{'imgObject'}->string($gData->{'yLabel'});

	# print y ticks

	# print 0 position tick
	($width,$height)=$gData->{'imgObject'}->stringBounds("0");
	$gData->{'imgObject'}->moveTo($gData->{'leftBorderOffset'}-($gData->{'leftBorderOffset'}-$width-3), ($scaledYSize +(abs($height)/2)+5));
	$gData->{'imgObject'}->string("0");
	# print tick mark / line
	$gData->{'imgObject'}->moveTo($gData->{'leftBorderOffset'}, $scaledYSize);
	$gData->{'imgObject'}->lineTo(($gData->{'leftBorderOffset'}-$gData->{'tickSize'}), $scaledYSize);
	# middle ticks
	for(my $i=1; $i<$gData->{'numberTicks'}; $i++){
		# tick value
		my $tick=int($rData->{'size'} - (($rData->{'size'}/$gData->{'numberTicks'}) * $i));
		# tick position
		my $tickPos = ($rData->{'size'}-$tick) / $gData->{'imageScaler'}+$gData->{'topBorderOffset'};
		$gData->{'imgObject'}->angle(-90); # for vertical printing
		($width,$height)=$gData->{'imgObject'}->stringBounds($tick);

		# print string
		$gData->{'imgObject'}->moveTo(($gData->{'leftBorderOffset'}-$gData->{'tickSize'}),($tickPos+(abs($height)/2)));
		$gData->{'imgObject'}->string($tick);

		# print line
		$gData->{'imgObject'}->angle(0);
		$gData->{'imgObject'}->moveTo($gData->{'leftBorderOffset'},$tickPos);
		$gData->{'imgObject'}->lineTo(($gData->{'leftBorderOffset'}-$gData->{'tickSize'}), $tickPos);
	}

	# print last tick
	$gData->{'imgObject'}->angle(-90);
	($width,$height)=$gData->{'imgObject'}->stringBounds($rData->{'size'});
	$gData->{'imgObject'}->moveTo(($gData->{'leftBorderOffset'}-$gData->{'tickSize'}),(abs($height)+5+$gData->{'topBorderOffset'}));
	$gData->{'imgObject'}->string($rData->{'size'});
	$gData->{'imgObject'}->angle(0);
	$gData->{'imgObject'}->moveTo($gData->{'leftBorderOffset'},1+$gData->{'topBorderOffset'});
	$gData->{'imgObject'}->lineTo(($gData->{'leftBorderOffset'}-$gData->{'tickSize'}), 1+$gData->{'topBorderOffset'});

	my $startPos = $scaledYSize+$gData->{'tickSize'};
	&printAxis($startPos, $rData->{'orderedValues'}, $gData, $scaledXsize, $rData->{'size'}, $gData->{'xLabel'});
	$gData->{'imgObject'}->angle(0);
	($width,$height)=$gData->{'imgObject'}->stringBounds(	$gData->{'xLabel'});
	$startPos = $scaledYSize+$gData->{'tickSize'}+abs($height)*2+3;
	if($gData->{'xLabel'} ne "Rank"){
		@{$rData->{'orderedValues'}} =(0..$rData->{'size'}); # orderedValues not just an array of rank positions...
		&printAxis($startPos, $rData->{'orderedValues'}, $gData, $scaledXsize, $rData->{'size'}, "Rank");
	}

	# print dataset label
	if(defined $gData->{'dataSetLabel'} && $gData->{'dataSetLabel'} ne ''){
		$gData->{'imgObject'}->angle(0);
		my ($width,$height)=$gData->{'imgObject'}->stringBounds($gData->{'dataSetLabel'});
		my $startX = ($scaledXsize / 2 - ( $width / 2));
		my $startY = $height;
		$gData->{'imgObject'}->moveTo($startX,($startY+1));
		$gData->{'imgObject'}->string($gData->{'dataSetLabel'});
	}

	# print diagonal axis across image...
	$gData->{'imgObject'}->penSize(1);
	$gData->{'imgObject'}->moveTo($gData->{'leftBorderOffset'},$scaledYSize);
	$gData->{'imgObject'}->lineTo($scaledXsize,$gData->{'topBorderOffset'});
	# print rectangle around image
	# warn ($gData->{'leftBorderOffset'}-1);
	# warn $gData->{'topBorderOffset'};
	# warn "$scaledXsize,$scaledYSize";
	# warn "x size details: $rData->{'size'} / $gData->{'imageScaler'} + $gData->{'leftBorderOffset'}";
	$gData->{'imgObject'}->rectangle($gData->{'leftBorderOffset'}-1,$gData->{'topBorderOffset'},$scaledXsize,$scaledYSize);
}

# print axis - if Rank is the label eq 'Rank', print out the
# rank at that position, corrected for the genes that may have been
# removed during noise correction. If label is not "rank", then
# use the value corresponding to the orf at that position in the
# ORGINAL rank order.
sub printAxis{
	my ($startPos, $data, $gData, $scaledXsize, $size, $label) = @_;
	# print x label
	$gData->{'imgObject'}->angle(0);
	my ($width,$height)=$gData->{'imgObject'}->stringBounds($label);
	$gData->{'imgObject'}->moveTo(($scaledXsize/2),($startPos+$height*2));
	$gData->{'imgObject'}->string($label);

	# call with $stringSub->($tick, $data);
	my $stringSub = sub { sprintf("%.2f", $_[1]->[$_[0]] ) };
	if($label eq 'Rank'){$stringSub = sub {	$_[0] };}

	# print X label ticks
	# first tick, first print string
	my $string = $stringSub->(0,$data);
	($width,$height)=$gData->{'imgObject'}->stringBounds($string);
	$gData->{'imgObject'}->moveTo($gData->{'leftBorderOffset'}-($width/2),$startPos+$height+3);
	$gData->{'imgObject'}->string($string);
	# then tick mark / line
	$gData->{'imgObject'}->moveTo($gData->{'leftBorderOffset'},$startPos-$gData->{'tickSize'});
	$gData->{'imgObject'}->lineTo($gData->{'leftBorderOffset'},$startPos);

	# middle ticks
	for(my $i=1; $i<$gData->{'numberTicks'}; $i++){
		my $tick=int(($size/$gData->{'numberTicks'}) * $i);
		my $tickPos = $tick / $gData->{'imageScaler'} + $gData->{'leftBorderOffset'};
		$string = $stringSub->($tick,$data);
		($width,$height)=$gData->{'imgObject'}->stringBounds($string);

		# print string
		$gData->{'imgObject'}->moveTo($tickPos-($width/2),$startPos+$height+3);
		$gData->{'imgObject'}->string($string);

		# print line
		$gData->{'imgObject'}->moveTo($tickPos,$startPos-$gData->{'tickSize'});
		$gData->{'imgObject'}->lineTo($tickPos,$startPos);
	}
	# last tick line
	$gData->{'imgObject'}->moveTo($scaledXsize,$startPos-$gData->{'tickSize'});
	$gData->{'imgObject'}->lineTo($scaledXsize,$startPos);
	# last tick string
	$string = $stringSub->(-1,$data);
	if($string == -1){$string = $size}

	($width,$height)=$gData->{'imgObject'}->stringBounds($string);
	$gData->{'imgObject'}->moveTo(($scaledXsize-$width),$startPos+$height+3);
	$gData->{'imgObject'}->string($string);
}

# actually print image out to file and to browser
sub printImage{
	my ($gData, $xSize) = @_;
	# bookkeeper($gData->{'imageDir'});
	if($gData->{'imageFileName'} !~ /\.png$/){$gData->{'imageFileName'} .= '.png';}
	open (IMG, ">$gData->{'imageDir'}$gData->{'imageFileName'}") || die "Could not open output file. $! --> $gData->{'imageDir'}$gData->{'imageFileName'}";
	binmode IMG; # this line really only required for windows, but does not hurt to include it here
	print IMG $gData->{'imgObject'}->png;
	close IMG;

	my $imageHTML='';
	if($gData->{'printToBrowser'}){

		my $zoomWidth = $gData->{'imageZoomFactor'}*$gData->{'imageWidth'};
		my $zoomHeight = $gData->{'imageZoomFactor'}*$gData->{'imageHeight'};
		my $iDir = $gData->{'imageDir'};
		$iDir =~ s/^\.\./$RELATIVE_ROOT/;

		$imageHTML .= '<div style=" margin: 0 auto; overflow: hidden;clear:both;">';
		$imageHTML .= "<div id='clikGraph' style='float:left;padding:0;margin:0;top:1px;position:relative;display:block;left:0;'>";
		$imageHTML .= "<img src='/$iDir$gData->{'imageFileName'}'  width='$gData->{'imageWidth'}' height='$gData->{'imageHeight'}' id='clikImage' />";
		$imageHTML .= '</div>';
		#  note, we could set the dims of #zoom here, using something like width:".($gData->{'imageWidth'}*0.5).";
		#  currently this is set the style sheet. It must be #zoom, not #zoomContainer that is set.
		$imageHTML .= "<div id='zoomContainer'><div id='zoom'></div>";
		# $imageHTML .= "<div id='zoomAxisContainer'>";
		# $imageHTML .= "<div id='zoomAxis' style='width:$zoomWidth;position:absolute;'><ul>";

		my $xScale = $zoomWidth / ($gData->{'imageWidth'}-$gData->{'leftBorderOffset'}+1);
		my $yScale = $zoomHeight / ($gData->{'imageHeight'}-$gData->{'topBorderOffset'}+1);
		# my $numTicks = int($zoomWidth-($xScale*$gData->{'leftBorderOffset'}))/$gData->{'zoomTickSpacing'};
		# my $tickSize = $xSize/$numTicks;

		# my $startTickPosition = 0;
		# for(my $i=0; $i<= $numTicks; $i++){
		# 	my $tickValue=int(($xSize/$numTicks) * $i + 0.5);
		# 	my $tickPosition = $tickValue / $gData->{'imageScaler'}*$gData->{'imageZoomFactor'} + $startTickPosition;
		# 	$imageHTML.="<li class='zt' style='left:$tickPosition'>$tickValue --</li>";
		# }
		#$imageHTML .= "</ul></div></div></div></div></div>";
		$imageHTML .= "</div></div></div>";

		#warn "xSize = $xSize, tickSize = $tickSize, numTicks = $numTicks, xScale = $xScale, leftBorderOffset = $gData->{'leftBorderOffset'}, imageWidth = $gData->{'imageWidth'}";
		#warn "displayRatio = $displayRatio, xy? = $gData->{'imgObject'}->{'xy'}->[0], leftOffset = $leftOffset, xOffset = $xOffset, xAxisBorderOffset, $gData->{'bottomBorderOffset'}";
		# need to move the following 2 line of code out of all the other divs to prevent their javascript event handlers
		# from firing  at inappropriate times
		$imageHTML .= <<VAR;
		<div id='mousePos' style='display:none;'></div>
		<div id = 'followMouseY' style='display:none;' ></div>
		<div id = 'followMouseX' style='display:none;'></div>
		<script type='text/javascript' charset='utf-8'>
			var image_yAxisLength = $gData->{'plotWidth'};
			var leftOffset=$gData->{'leftBorderOffset'};
			var image_xAxisLength = image_yAxisLength;
			var topOffset = $gData->{'topBorderOffset'};
			var bottomOffset = $gData->{'bottomBorderOffset'};
			var axisLength = $xSize;
			setupClikMagnifyEffect();

VAR
		$imageHTML.="var yZoomOffset=".($yScale*$gData->{'leftBorderOffset'}).";";
		$imageHTML.=" var xZoomOffset=($gData->{'imageWidth'}*0.25);</script><div id='debug'></div>";
	}
	return $imageHTML;
}

sub printCLIKgroupForm{
	my ($data) = @_;
	$data->{'groupNumber'} = '-cust' if !defined ($data->{'groupNumber'});

	my $html =<<HEAD;
	<div id ='$data->{'divName'}$data->{'groupNumber'}'>
		<form id="$data->{'divName'}Form$data->{'groupNumber'}" name="clikEnrichmentForm" method = "post" onsubmit="return submitCLIKajax({'formID' :this.id, 'responseContainer' :'$data->{'divName'}$data->{'groupNumber'}', 'loader':'loading$data->{'groupNumber'}', 'removeSubmit':true});">
HEAD
	foreach my $fieldName(keys %{$data->{'hiddens'}}){
		$html.="<input type='hidden' name='$fieldName' value='$data->{'hiddens'}->{$fieldName}' />";
	}
	$html.=<<HEAD;
			<input type='hidden' name='groupNumber' value='$data->{'groupNumber'}' />
			<input type='submit' value='&raquo; $data->{'message'}' class='commit' style='clear:left;float:left;'/>
			<div id="loading$data->{'groupNumber'}" class="loading" style="display:none;float:left;margin:0px 0x 0px 5px;">
				<img src="/$RELATIVE_ROOT/images/spinner.gif" alt="spinner" id="spinner" name="spinner" />
				<span>Loading...</span>
			</div>
			$lb
		</form>
HEAD
	$html.= join('',@{$data->{'extras'}}) if defined $data->{'extras'};
	$html.='</div>';
	return $html;
}

sub printCustomCLIKenrichmentForm{
	my $dataSet = shift;
	my $numBootstraps = shift;
	my $organism = shift;
	my $html =<<HEAD;
	<form id="clikEnrichmentForm" name="clikEnrichmentForm" method = "post" style="color:#00008B;margin-left:20px;padding-right:10px;" onsubmit="return submitCLIKajax({'formID':'clikEnrichmentForm', 'responseContainer': 'customClikEnrichment','loader' :'loading', 'removeSubmit':false });">
	<input type="hidden" name="custom" value="true" />
	<input type="hidden" name="dataSet" value="$dataSet" />
	<input type="hidden" name="numBootStraps" value="$numBootstraps" />
	<fieldset class='clikGroup' style="width:auto;margin-bottom:0px;" >
		<legend>Custom CLIK enrichment tool</legend>
		<div style ="clear:left;float:left;">
			<label for="startX" style="display:inline"><b>Rank start X value:</b></label>
			<input type="text" id="startX" style="width:auto;" name="startX" class="validate-number field_associates" value=""/>
		</div>
		<div style ="float:left;margin-left:20px;">
			<label for="endX" style="display:inline"><b>Rank end X value:</b></label>
			<input type="text" id="endX" style="width:auto;" name="endX" class="validate-number field_associates" value=""/>
		</div>
		<div style ="clear:left;float:left;">
			<label for="startY" style="display:inline"><b>Rank start Y value:</b></label>
			<input type="text" id="startY" style="width:auto;" name="startY" class="validate-number field_associates" value=""/>
		</div>
		<div style ="float:left;margin-left:20px;">
			<label for="endY" style="display:inline"><b>Rank end Y value:</b></label>
			<input type="text" id="endY" style="width:auto;" name="endY" class="validate-number field_associates" value=""/>
		</div>
HEAD
if($organism =~ /cerevisiae/i){
	$html .=<<HEAD;
		<div style ="clear:left;float:left;margin:10px 0px 0px 0px;">
			Use complex data from:
			<input type="radio" name="complexData" value="baryshnikova" checked="checked" style="margin:0px 0px 0px 5px;display:inline;" />
			<em style="display:inline;">Baryshnikova et al.</em>
			<input type="radio" name="complexData" value="benschop" style="margin:0px 0px 0px 5px;display:inline;" />
			<em style="display:inline;">Benschop et al.</em>
		</div>
HEAD
}

	$html .=<<HEAD;
		<input type="submit" value="&raquo; Calculate Enrichment" class="commit" style="clear:left;float:left;margin-top:20px;"/>
		<div id="loading" class="loading" style="display:none;float:left;margin:20px 0px 0px 5px;">
			<img src="/$RELATIVE_ROOT/images/spinner.gif" alt="spinner" id="spinner" name="spinner" />
			<span>Loading...</span>
		</div>
	</fieldset>
	</form>
	<div id="customClikEnrichment" style="clear:left;float:left;"></div>
HEAD
return $html;
}


#################################################################
# subroutine to ping progress of script
sub progressHook{
	my ( $progress, $message, $exitProgram ) = @_;
	my $sessionID = $q->param("sessionID");
	# warn " $progress, $message";
	if($sessionID){
		my $session_file = "../temp/$sessionID.session";
		# Write this data to the session file.
		if (-f $session_file) {
			open (SES, "+<$session_file"); # open file in rw mode b/c we don't want to clear it until after the lock is applied
			flock(SES, 2); # lock file
			seek(SES, 0, 0); truncate(SES, 0); # clear file contents
		}
		else{
			if (! defined $exitProgram ){$exitProgram = "Couldn't create session file $session_file"; }
			open (SES, ">$session_file") || &exitProgram("Cannot create session file.",$!,$exitProgram); ;
		}
		if($message =~ /^printToBrowserExit\:/i){
			print SES "printToBrowserExit:$progress:".$$;
			$message =~ s/^printToBrowserExit\://i;
			close SES;
			die 'Directory setup error '. __FILE__.' line '.__LINE__ if !Modules::ScreenAnalysis::verifyDir($q,"../temp/images/$progress",'clik');
			open (NEW, ">../temp/images/$progress/$sessionID.html") || die "../temp/images/$progress/$sessionID.html. $!";
			print NEW $message;
			close NEW;
		}
		else{
			$progress = sprintf('%.2f', $progress);
			if($progress > 100 || $message eq 'finished'){print SES "finished!";}
			elsif($message !~/^combos/i){print SES "$progress:$message ($progress%):".$$;}
			else{print SES "$progress:$message:".$$;}
			close (SES);
		}
	}
}

sub setupCLIK{
	$q=new CGI; # initialize new cgi object;
	$lb = '<br/>';
}

sub setupORFoutputSub{
	my $rankData = shift;
	# add appropriate sub routine for printing out ORFs
	if($rankData->{'organism'} =~ /cerevisiae/i){
		$rankData->{'geneDisplaySub'} = sub {
			# $orf = $_[0]; class = $_[1];
			# title = $_[2];	extraText = $_[3];
			return "<a href='http://www.yeastgenome.org/cgi-bin/locus.fpl?locus=$_[0]' class='$_[1]'><span class='orf' title='$_[2]'>$_[0]</span>$_[3]</a>";
		}
	}
	elsif($rankData->{'organism'} =~ /Dmelanogaster/i){
		$rankData->{'geneDisplaySub'} = sub {return "<a href='http://flybase.org/reports/$_[0]".".html' class='$_[1]'><span class='orf' title='$_[2]'>$_[0]</span>$_[3]</a>"; }
	}
	else{
		$rankData->{'geneDisplaySub'} = sub {return "<span class='orf $_[1]' title='$_[2]'>$_[0]$_[3]</span>"; }
	}
	return 1;
}

sub convertHumanORFsToEnsembl{
	my ($geneList, $fromFormat) = @_;
	# for now just assume the only thing we are doing is converting gene names to ensemble ids.
	my $dbh = Modules::ScreenAnalysis::connectToMySQL();
	if(!$dbh){&exitProgram("Could not connect to database!");}
	my $sqlFront = "SELECT `geneName`, `ensemblID` FROM `hsapien_ensembl_genes` WHERE `geneName`";
	&progressHook(5, "Converting gene IDs");

	my $limit = 500;
	my (@list, %rank);
	my $rankCount = 0;

	my %geneLookup = ();
	@geneLookup{@{$geneList}} = ( 0..$#{$geneList} );

	my @processedList = ();
	my $totalGenes = scalar(@{$geneList});
	my $totalIteractions = int(($totalGenes / $limit) + 0.5)+1;
	my ($i, $go)=(0,1);

	while($go){
		$i++;
		if(scalar(@{$geneList}) < $limit){
			$go = 0;
			$limit = scalar(@{$geneList}) ;
		}
		if($limit > 1){
			my @temp = splice(@{$geneList}, 0, $limit);
			my $sth = $dbh->prepare( "$sqlFront IN (". join(', ', ('?') x @temp) . ")");
			$sth->execute( @temp );
			my %data = ();
			while ( my $row = $sth->fetchrow_arrayref() ) {
				if($row->[1]){
					push(@{$data{$row->[0]}}, [$row->[0], $row->[1]]);
				}
			}
			for (my $j = 0; $j < @temp; $j++) {
				foreach my $row(@{$data{$temp[$j]}}){
					$list[$rankCount] = $row->[1];
					$processedList[$rankCount] = $row->[0];
					push(@{$rank{$row->[1]}}, $rankCount);
					$rankCount++;

					delete $geneLookup{$row->[0]};
				}
			}
			$sth->finish();
		}
		else{	$go = 0; 	}
		if($i>=$totalIteractions){	$go = 0; 	}
	}

	$dbh->disconnect();

	my $inputLog='';
	if (keys %geneLookup > 0) {
		$inputLog .= "Could not id the following genes in your input list at the following positions:$lb";
		foreach my $gene(keys %geneLookup) {$inputLog .= "$geneLookup{$gene} -> $gene $lb";	}
		$inputLog .= "These lines were not included for interaction processing\n";
	} # end if fail
	my @values = (0..@list);
	my %rankData = ('orderedORFnames'=>\@list, 'orderedValues'=>\@values, 'ranksOfORFs'=>\%rank, 'originalList'=>\@processedList);
	return (\%rankData, $inputLog);
}

################################### READORF_LIST
# Reads list of ORFs in rank order from web form input (list)
# splits list by /\015\012|\r+|\012+|\n+|,\s+|\s+/, iterates over values
# verifies valid ORF values by comparing to a regex
sub readORF_list {
	my ($geneList, $organismInfo) = @_;
	my (@list, @fail, %rank);
	my ($count, $rankCounter) = (0,0);
	my $inputLog='';

	my $orfPattern = $organismInfo->{'ORFregex'};
	my $gene_lookup_hash = {};
	my $gene_conversion_file = &gene_conversion_file($organismInfo->{'shortName'});
	if($gene_conversion_file){
		$gene_lookup_hash = eval{retrieve($gene_conversion_file)};
		if($@){	&exitProgram("Problem loading gene conversion file. Please contact the administrator.", "$@ --> line #".__LINE__);	}
	}
	if (! defined $orfPattern){ $inputLog .= "No gene pattern defined!"; }
	else{
	 	ORFS:foreach my $orf(@{$geneList}) {
			$orf = &trimErroneousCharacters($orf);
			# warn "$count -$orf-";
			# warn "$_\n";
			# if we encounter an ORF name
			if($orf !~ /$orfPattern/){
				# attempt to lookup gene name instead
				if( defined $gene_lookup_hash->{$orf} ){ $orf = $gene_lookup_hash->{$orf}; }
				else{ next ORFS; }
			}
			if ($orf =~ /$orfPattern/) {
				push (@list,$orf);
				# push this into an array instead of just setting the value of the hash to the rank
				# because sometimes there are duplicate ORFs in a dataset with different (sometimes substantially) ranks
				push(@{$rank{$orf}}, $rankCounter);
				$rankCounter++;
			} # end if
			else {push (@fail,"$count ==> $orf");} # end else
			$count++;
		}# end while
	}
	if (@fail) {
		$inputLog .= "Non ORF data exists in your input list at the following lines:\n";
		foreach(@fail) {$inputLog .= "$_\n";	}
		$inputLog .= "These lines were not included for interaction processing\n";
	} # end if fail
	my @values = (0..@list);

	my %rankData = ('orderedORFnames'=>\@list, 'orderedValues'=>\@values, 'ranksOfORFs'=>\%rank, 'originalList'=>\@list);
	return (\%rankData, $inputLog);
}

################################### readSceenMillFile
#
# SHOULD ADD ADDIITONAL OPTION TO SORT BY CUSTOM FIELD
sub readSceenMillFile {
	my ($SCREEN_DATA, $sortBy, $conditionCombos)= @_;
	if(!$conditionCombos){$conditionCombos='';}
	my $processLog='';
	if(!&validateGoodTextFile( $SCREEN_DATA ) ){
		&exitProgram("Your file did not upload properly. If you have it open in another application, please close it and try again\n", 'Could not open millFile.');
	}
	$/ = line_break_check( $SCREEN_DATA ); # check what type of line breaks this file contains
	# check to make sure we have a valid file handle

	my $iloop=0; #used to check if we are in a seemingly infinite loop
	my (%outAll_colindex, @outAll_data,@headers,$orf_col);

	# get rid of header in an out-all file from a screen
	while(!(defined $outAll_colindex{'query'} && defined $outAll_colindex{'condition'} && defined $outAll_colindex{'plate #'} && defined $outAll_colindex{'row'} && defined $outAll_colindex{'column'} && defined $outAll_colindex{$sortBy})){
		$iloop++;
		if($iloop==100){
			#warn Dumper(\%outAll_colindex);
			&exitProgram("Your ScreenMillStats-All data File data file is not formatted properly. Please make sure it contains a header row with the following labels in the appropriate columns: 'Query', 'Condition', 'Row', 'Column' and ('Z-score' or 'P-Value'), depending on what parameter you are sorting your data by", 'Your out_all data file is not formatted properly.');
		}
		chomp (my $head = <$SCREEN_DATA>);
		$head =~ s/\s+\t|\t\s+/\t/; # trim off extra spaces before or after column labels
		@headers = split /\t/, "\L$head"; # want it to be case insensitive
		%outAll_colindex=();
		@outAll_colindex{@headers} = (0..$#headers);
		# In older out-all files the column label is 'col' in newer files it is 'column'
		if ($outAll_colindex{'col'}) {	$outAll_colindex{'column'} = $outAll_colindex{'col'};	}
	}
	%outAll_colindex=();
	@outAll_colindex{@headers} = (0..$#headers); #		store header line in array


	# check if the the normalized growth ratio column was found
	# my $normRatioCol = undef;
	# if(defined $outAll_colindex{'normalized growth ratio (comparer::exp)'}){$normRatioCol = $outAll_colindex{'normalized growth ratio (comparer::exp)'};}
	# elsif(defined $outAll_colindex{'normalized ratio (comparer::exp)'}){$normRatioCol = $outAll_colindex{'normalized ratio (comparer::exp)'};}
	# elsif(defined $outAll_colindex{'normalized ratio (control::exp)'}){$normRatioCol = $outAll_colindex{'normalized ratio (control::exp)'};}


	# depending on how old the out-all data file is orfs and log_ratios may have different identifiers
	if ($outAll_colindex{'id column'}) {	$orf_col = $outAll_colindex{'id column'};	}
	elsif ($outAll_colindex{'orf'}) {	$orf_col = $outAll_colindex{'orf'};	}
	else {	&exitProgram('Could not find the ORF column in your data file.\n','could not find the ORF column in your data file');}
	#print Dumper(\%outAll_colindex);
	$.=0; # reset file handle line counter
	$processLog .= "header line identified:\t$headers[0]\t $headers[1]\t $headers[2]\tetc...\n";
	$processLog .= "ORF column is $orf_col\n";
	#
	# now that we have removed and analyzed the header, iterate over the rest of an out-all file
	#
	my @temp;
	my $count = 0;
	while(<$SCREEN_DATA>){
		chomp;
		next if $_ =~ /BLANK\-.*\-BLANK|HIS3\-BLANK|excluded\-.*\-excluded|dead\-.*\-dead|^\n+$|^\s+$|^\t+$/igo;
		my @data =  split /\t/;

		# my $comparerSizeMean='';
		# if(defined $data[$normRatioCol] ){
		#	if($data[$normRatioCol]=~/^(\D+)|\D+$/){$data[$normRatioCol]=~s/^\D+|\D+$//ig;}
		#	$data[$normRatioCol] =~ /^(.*)::/;
		#	$comparerSizeMean = $1;
		# }
		#  && $comparerSizeMean > 0.4
		if(&is_numeric($data[$outAll_colindex{"$sortBy"}]) && defined $data[$orf_col] && $data[$orf_col] ne ''){ push(@temp, [@data]);}
		# else{warn "removed something";}
		$count++;
	}
	@temp = sort { $b->[$outAll_colindex{"$sortBy"}] <=> $a->[$outAll_colindex{"$sortBy"}] } @temp;
	# warn Dumper (\%outAll_colindex);
	# warn Dumper (\@temp);
	$processLog .= "\nFound $count lines of data\n";
	$processLog .= 'Removed '.($count - scalar(@temp))." lines containing 'dead', 'control' (e.g. HIS3) or 'excluded' data\n\n";
	#my @temp = sort { $b->[$outAll_colindex{"$sortBy"}+1] <=> $a->[$outAll_colindex{"$sortBy"}+1] } map { [ $_, (split /\t/) ] } grep(!/BLANK\-.*\-BLANK|HIS3\-BLANK|excluded\-.*\-excluded|dead\-.*\-dead|^\n+$|^\s+$|^\t+$/igo,<$SCREEN_DATA>); # slurp in the data, ignore blanks, deads, and excludes.  tab separated fields
	#$processLog .= "\nFound $. lines of data\n";
	#$processLog .= 'Removed '.($. - scalar(@temp))." lines containing 'dead', 'control' (e.g. HIS3) or 'excluded' data\n\n";
	close $SCREEN_DATA;
	my (@densities,@outAll_ORFs, %rank);
	my $size = scalar(@temp)-1;
	my %conditionCombos;

	$conditionCombos =~ s/\t/\-/gi;
	$conditionCombos =~ s/\s//i;
	$conditionCombos = lc($conditionCombos);
	#warn "=$conditionCombos=";
	my %tempCombos;
	foreach(@temp){
		my $combo = ($_->[$outAll_colindex{'condition'}]) ? "$_->[$outAll_colindex{'query'}]-$_->[$outAll_colindex{'condition'}]" : "$_->[$outAll_colindex{'query'}]";
		$tempCombos{$combo}=1;
		my $pCombo = lc($combo);
		$pCombo =~ s/\s//g;
		if($conditionCombos eq '' || $conditionCombos eq $pCombo){
			$conditionCombos{$combo}=1;
			push(@densities, $_->[$outAll_colindex{"$sortBy"}]);
			push(@outAll_ORFs,$_->[$orf_col]);
			# push this into an array instead of just setting the value of the hash to the rank
			# because sometimes there are duplicate ORFs in a dataset with different (sometimes substantially) ranks
			push(@{$rank{$outAll_ORFs[$#outAll_ORFs]}}, $#outAll_ORFs);
		}
	}
	# use Data::Dumper;
	# warn Dumper(\%tempCombos);
	# warn Dumper(\%conditionCombos);
	if(scalar(keys %conditionCombos) >1 ){	return (\%conditionCombos, 'combosFound');	}
	elsif(scalar(@temp) < 5){&exitProgram('Could not find enough data to analyze, make sure that the data in your file contains numerical data in the "'.$sortBy.'" column and that it is not all excluded, blank, or dead.','not enough data!');}
	elsif(scalar(keys %conditionCombos) < 1){
		if($conditionCombos ne '' && scalar(keys %tempCombos) > 0){ return (\%tempCombos, 'combosFound');}
		&exitProgram('Could not find any condition combinations to process in the file you uploaded','no combos found!');
	}
	# outAll_data && outAll_ORFs is now sorted by z-score...
	my %rankData = ('orderedORFnames'=>\@outAll_ORFs, 'orderedValues'=>\@densities, 'ranksOfORFs'=>\%rank, 'sortedBy' => $sortBy, 'originalList'=>\@outAll_ORFs);
	return (\%rankData, $processLog);
}

# removes ORFs that have more than $iData->{'promiscuousCutoff'} interactions within the dataset
# being analyzed
sub trimNoisyItems {
	# $iCounts ==> reference interactionCountHash created in calculateInteractions subroutine...for this subroutine you need to know that it
	#														contains keys that are ORFs. The value of any given ORFs (ORF a) is a hash who's keys are all the ORFs that ORF a interacts with
	# $iCounts->{'orfs'}->{$orf}->{'numInteractions'} ==> number of times each ORF interacts with another in this dataset
	# $rData ==> reference to $rankData hash created in	&processInputData subroutine. Keys of this hash relevant for this subroutine are:
	#						$rData->{'orderedORFnames'}=> an array with the index corresponds to rank and values are ORFs names
	# 					$rData->{'orderedValues'}=> an array containing the values associated with each ORF
	#						$rData->{'ranksOfORFs'}=> a hash with ORFs as keys and their corresponding ordered rank values as....values
	# $iData ==> reference to %inputData hash that contains (mostly) user entered data....for this subroutine relevant keys are
	#						 $iData->{'promiscuousCutoff'} == interaction cutoff. Any ORFs that have more interactions than this value are not considered
	#						 $iData->{'interactionNormalization'} == if value is one we will automatically normalize data based on the number of interactions a given ORF has within the dataset
	my ($iCounts, $rData, $iData) = @_;
	my $numberRemoved=0;
	my $trimInfo='';
	if($iData->{'promiscuousCutoff'} < 1){return ($numberRemoved, $trimInfo);}
	# open (my $DEBUG1, ">listDeltas.txt")||die "Can't open debug 1\n";
	# open (my $DEBUG2, ">listCollapsed.txt")||die "Can't open debug 2\n";
	my %deleted;
	#########  Delete promiscuous guys from the rank-ordered list

	#my %slowGrowingOrfs = (
	#	);
	#my %orfsToOmit = ();
	# use Data::Dumper;
	foreach my $orf(keys %{$iCounts->{'orfs'}}) {
		$iCounts->{'orfs'}->{$orf}->{'numInteractions'}+=0;
		# warn Dumper \@{$rData->{'ranksOfORFs'}->{$orf}};
		# warn $orf;
		my $numInteractions = $iCounts->{'orfs'}->{$orf}->{'numInteractions'}/scalar( @{$rData->{'ranksOfORFs'}->{$orf}});
		#if($numInteractions > $iData->{'promiscuousCutoff'} || defined $orfsToOmit{$orf}) {# if the list element is in the noise list
		if($numInteractions > $iData->{'promiscuousCutoff'} ) {# if the list element is in the noise list
			# in order to handle duplicate orfs, the rankings of each orf are stored in an array, hence @{$rData->{'ranksOfORFs'}->{$orf}}....
			# store rankings in deleted hash with values == orfs names being deleted, use this info below to splice out values from @{$rData->{'orderedORFnames'} && @{$rData->{'orderedValues'}
			foreach my $orfRank(@{$rData->{'ranksOfORFs'}->{$orf}}){
				$deleted{$orfRank} = $orf;
				$numberRemoved++;
			}
			delete $rData->{'ranksOfORFs'}->{$orf};
			delete $iCounts->{'orfs'}->{$orf};
		} # end if
	} # end foreach
	# sort rankings in descending order to prevent issues when splicing data out of arrays....
	my @deleted = ();
	foreach my $myDeletedOrfRank(sort {$b<=>$a} keys %deleted){
		splice(@{$rData->{'orderedORFnames'}}, $myDeletedOrfRank,1) ; # then delete from list
		splice(@{$rData->{'orderedValues'}}, $myDeletedOrfRank,1) ; # then delete from list
		# switch key / value order so that now ORFs are keys...will make look up easier later when deleting stuff from $iCounts
		if(! defined $deleted{$deleted{$myDeletedOrfRank}}){
			unshift (@deleted, $deleted{$myDeletedOrfRank});
		}
		unshift ( @{$deleted{$deleted{$myDeletedOrfRank}}} , $myDeletedOrfRank+1);
		delete($deleted{$myDeletedOrfRank}); # delete data that is no longer needed
	}
	# print $DEBUG1 "@hashOut\n";
	# # need to remove undef values from arrays (deleting them just sets value to undef and returns false when using 'exists' fnc)
	# @{$rData->{'orderedORFnames'}} = grep { defined } @{$rData->{'orderedORFnames'}}; # collapses UNDEFS out of list
	# @{$rData->{'orderedValues'}} = grep { defined } @{$rData->{'orderedValues'}}; # collapses UNDEFS out of list
	# # print $DEBUG2 "@$rankedORFsListRef\n";
	#
	#########  Then spin through %interactionsHash to remove noise
	#
	#  Try a trimming routine vs. just re-calculating these from the abbreviated list

	delete($rData->{'ranksOfORFs'});

	# Then remove noisy guys as hits -- build $rData->{'ranksOfORFs'} data structure
	for(my $i=0; $i<@{$rData->{'orderedORFnames'}}; $i++){
		my $A = $rData->{'orderedORFnames'}->[$i];
		push(@{$rData->{'ranksOfORFs'}->{$A}}, $i);
		foreach my $B (@deleted) {
			if(defined $iCounts->{'orfs'}->{$A}->{'interactor'}->{$B} ) {
				delete $iCounts->{'orfs'}->{$A}->{'interactor'}->{$B};
				$iCounts->{'orfs'}->{$A}->{'numInteractions'}--;
			}
		} # end foreach
	} # end for
	my $deleteCount=0;
	if($iData->{'reciprocal'} == 1){
		foreach my $orf(keys %{$iCounts->{'orfs'}}) {
			foreach my $interactor (keys %{$iCounts->{'orfs'}->{$orf}->{'interactor'}}) {#      -> B's
				# if reciprocal does not exist, delete this interaction.
				if(!defined $iCounts->{'orfs'}->{$interactor}->{'interactor'}->{$orf}){
					$iCounts->{'orfs'}->{$orf}->{'numInteractions'}--;
					delete $iCounts->{'orfs'}->{$orf}->{'interactor'}->{$interactor};
					$deleteCount++;
				}
			}
		}
	}


	if($numberRemoved>0){
		$trimInfo .= "Noise reduction accomplished -- $numberRemoved identifiers (genes) removed from rank list [rank(s) in dataset is in parenthesis]:\n";
		foreach(@deleted){
			$trimInfo.= "$_ (". join(', ', @{$deleted{$_}})."), ";
		}
		chop($trimInfo);chop($trimInfo);
		$trimInfo.="\n\n";
	}
	else{$trimInfo .= "Noise reduction analysis performed -> 0 identifiers had more than $iData->{'promiscuousCutoff'} interactions within your dataset";}
	return ($numberRemoved, $trimInfo);
}

sub validateGoodTextFile{
	my $file = shift;
	if(!$file){return 0;}
	local $/ = \1000; # read first 1000 bytes
	local $_ = <$file>; # read
	if(!$_ || (! -r $file) || (-z $file) || (! -T $file) ){return 0;}
	return 1;
}

#################################################################
# subroutine to trim off the white space, carriage returns, pipes, and commas from both ends of each string or array
sub trimErroneousCharacters {
	my $guy = shift;
	return $guy if(!$guy);
	my $type = (ref(\$guy) eq 'REF') ? ref($guy) : ref(\$guy);
	if ( $type eq 'ARRAY') { # Reference to an array
		foreach(@{$guy}) {  #for each element in @{$guy}
			s/^\s+|\s+|\|+|\r+|\015\012+|\012+|\n+|,+$//g;  #replace one or more spaces at the end of it with nothing (deleting them)
		}
	}
	elsif ( $type eq 'SCALAR' ) { # Reference to a scalar
		$guy=~ s/^\s+|\s+$//g;
	}
	return $guy;
}

sub exitProgram{
	my ($userMsg, $debugMsg, $exitProgram) = @_;
	# stop progress...
	# &progressHook($session,100,"finished!");
	if(!$q->{'.header_printed'}){	print $q->header();}
	# this print statement is important to print errors to the screen
	print "<div id='clikError' style='color : #FF3300;font-weight: bold;padding:5px;font-family: tahoma, arial, verdana, sans-serif;margin:5px'>$userMsg</div>";
	if(!$exitProgram){
		&progressHook("error", "printToBrowserExit:<div id='clikError' style='color : #FF3300;font-weight: bold;padding:5px;font-family: tahoma, arial, verdana, sans-serif;'>$userMsg</div>", 'no_exit_program');
	}
	else{die "$userMsg -- $debugMsg";}
	if($debugMsg){	&sendEmail($debugMsg);}
	else{&sendEmail($userMsg);}
	exit(0);
}

################################### RANDOMIZE AN ARRAY
sub fisher_yates_shuffle {
	my $array = shift;
	my $i;
	for ($i = @$array; --$i; ) {
		my $j = int rand ($i+1);
		next if $i == $j;
		@$array[$i,$j] = @$array[$j,$i];
	}
}

################ John's subroutines for n-choose-k ###########################

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
# Returns the natural log of n choose k
sub ln_n_choose_k {
	my ($n, $k) = @_;
	if($nk{"$n-$k"}){return $nk{"$n-$k"};}
	die "improper k: $k, n: $n\n" if $k > $n or $k < 0;
	$k = ($n - $k) if ($n - $k) < $k;
	$LNfact{$n} = &LNfact($n) unless $LNfact{$n};
	$LNfact{$k} = &LNfact($k) unless $LNfact{$k};
	$LNfact{$n-$k} = &LNfact($n-$k) unless $LNfact{$n-$k};
	my $result = $LNfact{$n}-$LNfact{$k}-$LNfact{$n-$k};
	$nk{"$n-$k"}=$result;
	return $result;
}

# Returns the natural log of the factorial of the value passed to it.  Uses Stirling's approximation for large factorials
sub LNfact {
	my ($z) = @_;
	my $GoStirling = @fact;
	my $result;
	if ($z >= $GoStirling) {$result = &LNstirling($z); }# print "approx of z ($z) = $result$lb";
	elsif ($z < $GoStirling) {$result = $fact[$z]}
	return $result;
}

# Returns the p-value for a particular overlap
sub LNhypergeometric {
	my ($gp, $tg, $tp, $t) = @_;
	#print "2nd -> ($gp, $tg, $tp, $t)$lb";
	return 0 if $t - $tg < $tp - $gp;
	return &ln_n_choose_k($tg, $gp) + &ln_n_choose_k($t - $tg, $tp - $gp) - &ln_n_choose_k($t, $tp);
}

# For large values of n, (n/e)n square root(2n pi) < n! < (n/e)n(1 + 1/(12n-1)) square root(2n pi): Stirling's Formula.
sub LNstirling {
	my ($x) = @_;
	my $S = 0.5*(log (2*$pi)) + 0.5*(log $x) + $x*(log $x) - $x;
	my $upadd = log(1 + (1/(12*$x - 1)));
	my $approx = $S + $upadd; # using the upper bound gives more conservative (and accurate) p-values.
	return $approx;
}

sub cum_hyperg_pval_info {
	my ($gp, $tg, $tp, $t) = @_;
#	print "-> $gp, $tg, $tp, $t$lb";
	if($tg==$t){return (1, "tg == t, what did you expect?");}
	if($tg==0){return (1, "tg == 0, what did you expect?");}
	if($tp==$t && $tg == $gp){return (1, "represented?: $gp|$tp|$tg|$t");}
	if ($gp<0 or $gp>$tg or $gp>$tp or $tg<0 or $tg>$t or $tp<0 or $tp>=$t or $t<0){
		warn "gp = $gp, tg = $tg, tp = $tp, t = $t";
		die "ERROR: improper input values for hypergeometric distribution.\n";
	}
	if ($tg < $tp){ # setting B to the smaller of the two counts optimizes the p-value calculation
		my $temp = $tp;
		$tp = $tg;
		$tg = $temp;
	}
	#print "1st -> ($gp, $tg, $tp, $t)$lb";
	my ($resultR,$resultL);
	for (my $i = $gp; $i<=$tp; $i++){ # sum from AB to right in distribution
		# exp = e ^ x (inverse of ln)
		my $right = &LNhypergeometric($i,$tg,$tp,$t);
		if($right != 0){$right = exp($right);}
		$resultR += $right;
	}
	for (my $i = 0; $i<=$gp; $i++){ # sum from left to AB in distribution
		my $left = &LNhypergeometric($i,$tg,$tp,$t);
		if($left != 0){$left = exp($left);}
		$resultL += $left;
	}
	# pick the smaller of the two sections of the distribution as it is the one that is in the tail instead of around the mean and a tail...meaning that
	# which ever is smaller tells us if we are over or under represented....
	if ($resultR < $resultL){return ($resultR, "over-represented")}
	else{return ($resultL, "under-represented")}
}

sub eDistance{
	my ($x1,$y1,$x2,$y2) = @_;
	return sqrt( ($x1-$x2)**2+($y1-$y2)**2);
}

sub sendEmail{
	my ($body,$from_address,$subject,$to_address)=@_;
	$from_address = 'web_tools@rothsteinlab.com' if(! defined $from_address);
 	$to_address = 'jcd2133@columbia.edu' if(! defined $to_address);
	$subject = "CLIK ERROR!" if(! defined $subject);
	warn $body;
	eval{
		my $mailer = Mail::Mailer->new("sendmail");
		$mailer->open({	From	 	=> $from_address,
										To			=> $to_address,
										Subject	=> $subject,
									})
				or die "Can't open: $!\n";
		print $mailer $body;
		$mailer->close();
	};
	if($@) {
		# the eval failed
		#print "Could not send email. $@\n";
	}
	else{
		# the eval succeeded
		#print "Success.\n";
	}
}

sub is_numeric{
	no warnings;
	use warnings FATAL => 'numeric';
	return defined eval { $_[ 0] == 0 };
}

1;
