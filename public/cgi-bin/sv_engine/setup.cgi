#!/usr/bin/perl -w

# ******************************************************
# Image Comparison tool
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
use Storable qw(store retrieve); # the storable data persistence module
use Modules::ScreenAnalysis qw(:sv_engine); # use my module and only load routines in analysis

my %replicateDivisors = (
														'1' => [1, 1],
														'2h' => [1, 2],
														'2v' => [2, 1],
														'4' => [2, 2],
														'16' => [4, 4]
);

my $size_limit = 20;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 20 MB limit
$|=1;
my $q=new CGI;
my %variables;
unless(&initialize($q, $size_limit)){exit;}
unless(&validateUser(\%variables,$q)){exit;} # validate user

my $asset_prefix = &static_asset_path();

# temporary directory where we will store stuff
# set $variables{'base_upload_dir'} and $variables{'base_dir'}
&getBaseDirInfo(\%variables,'sv',$q);
# generate user specific directories
&directory_setup(\%variables, $q);

# retreive current working directory (the temporary directory specific to this user where data structures are stored via storable)
if(!&setSession('sv_engine_setup', \%variables, $q)){
	&update_error("Error setting user session, please make sure you have cookies enabled on your browser and retry. ".&try_again_or_contact_admin(), $q);
	die "Could not set user session $! --> $variables{'save_directory'}";
}

# verify that the page we came from is correct
my $referer=$ENV{HTTP_REFERER};

my $plates_per_page = 3;
my($dataPlate, $normalization_values);
my $current_page=0;
$variables{'control'}=$q->param('control');# control query
$variables{'originalData'}->{'control'}=$variables{'control'};
$variables{'control'}="\L$variables{'control'}";
$variables{'authenticity_token'}=$q->param('authenticity_token');
if( $variables{'control'} =~ m/[^a-zA-Z0-9_'"\,\-\.\?!\(\)\s]+/ ){
	&update_error("There is something wrong with the query you entered as a comparer.  Acceptable characters include a-z, A-Z, 0-9, '_', '-', '?', '!',
				 '(', ')', periods, commas, and single and double quotes.<br/>Whatever name you choose <u>MUST</u> match the name you used for identify
				 comparer plates in your log file (which should be the same as in your original scanned images).  ".&try_again_or_contact_admin(), $q);
	die "Comparer query error (".$variables{'control'}."): $!";
}
# set the number of pairs of rows and column for a particular density
# this assumes that the number of replicates is 4....

$variables{'processing_choice'}=$q->param('processing_choice'); # should we use images stored on server or should we recapitulate them from log file

# check if plateIDs should be ignored...
$variables{'ignoreID'} = ($q->param('ignoreID') eq 'true') ? 1 : undef;
$variables{'dontDorryAboutMissingValues'} = ($q->param('dontDorryAboutMissingValues') eq 'true') ? 1 : undef;
&update_message('Processing ScreenMillStats-all data file...', $q);
my ($dinfo, $controlInfo)=&processOutAllFile($q, \%variables);
my @alphabet=("A".."ZZ");
foreach my $query(keys %{$variables{'sample_size'}}){
	foreach my $condition(keys %{$variables{'sample_size'}->{$query}}){
		if(! defined $variables{'pthresh'}->{$query}->{$condition}){
			$variables{'pthresh'}->{$query}->{$condition} = 0.05 / $variables{'sample_size'}->{$query}->{$condition};
			foreach my $plate(sort keys %{$dinfo}){
				if($dinfo->{$plate}->{$query}->{$condition}){ # if this plate exists
					for(my $col=1; $col<=$variables{'cols'}; $col++) {
						for (my $row=0; $row<$variables{'rows'}; $row++){
							my $pval=$dinfo->{$plate}->{$query}->{$condition}->{$alphabet[$row]}[$col]->[1];
							if(&is_numeric($pval)
									&& $pval <= $variables{'pthresh'}->{$query}->{$condition}
									&& $dinfo->{$plate}->{$query}->{$condition}->{$alphabet[$row]}[$col]->[3] !~/^ex|^dead|^blank/i){
								# count number of guys below threshold for current condition
								$variables{'num_sigs'}->{$query}->{$condition}++;
								$variables{'hit_list'}->{$query}->{$condition}.="<li>$dinfo->{$plate}->{$query}->{$condition}->{$alphabet[$row]}[$col]->[0]"." ($plate - $alphabet[$row]$col)</li>";
							}
						}
					}
				}
			}
		}
		$variables{'orig_pthresh'}->{$query}->{$condition}= $variables{'pthresh'}->{$query}->{$condition};
	}
}


if(!$variables{'replicates'} || $variables{'replicates'} !~ /^(1|2|4|16|2v|2h)$/i){
	$variables{'replicates'} = (defined($variables{'replicates'})) ? $variables{'replicates'} : 'n/a';
	&update_error("Could not determine the number of replicates you screened in<br/>Please ensure that your ScreenMillStats-All Data File contains this information<br/>  ".&try_again_or_contact_admin(), $q);
	die "Could not determine the number of replicates you screened in.\n";
}
# START picture specific shtuff
if($variables{'processing_choice'} eq 'pictures'){
	$variables{'imageSize'}=$q->param("imageSize");
	$variables{'picture_dir'}='../../screen_mill/public/pics';
	$variables{'picture_dir_html'} = "/tools/pics";
	# define image size to display
	if($variables{'imageSize'} eq 'a') { $variables{'imageX'}=690; $variables{'imageY'}=460;}
	elsif($variables{'imageSize'} eq 'b') { $variables{'imageX'}=587; $variables{'imageY'}=391;}
	elsif($variables{'imageSize'} eq 'c') { $variables{'imageX'}=470; $variables{'imageY'}=313;}
	elsif($variables{'imageSize'} eq 'd') { $variables{'imageX'}=376; $variables{'imageY'}=250;}
	else{
		&update_error("Invalid image size entered. Image size entered = $variables{'imageSize'}.  ".&try_again_or_contact_admin(), $q);
		die "Invalid image size: $variables{'imageSize'}.  $!\n";
	}
	&update_message('Processing log file...', $q);
	($dataPlate, $normalization_values) = &processLogFile($q, 'ic', \%variables, $controlInfo->{'controlLocations'});
	$variables{'height'} = $variables{'imageY'} / $variables{'rows'};
	$variables{'width'} = ($variables{'imageX'} / $variables{'cols'});
	$variables{'span'}=$variables{'imageX'};
	#my $in_span=$variables{'imageX'}-($variables{'imageX'}/$variables{'cols'});
	#my $offset=$variables{'imageX'}/$variables{'cols'};
}
# END picture specific shtuff
# START LOG FILE specific shtuff
elsif($variables{'processing_choice'} eq "log_file"){
	&update_message('Processing Plate Images...', $q);
	($dataPlate, $normalization_values) = &processLogFile($q, 'ic', \%variables, $controlInfo->{'controlLocations'});
	$variables{'height'} = $variables{'cell_size'}* $replicateDivisors{$variables{'replicates'}}[0];
	$variables{'width'} = $variables{'cell_size'}* $replicateDivisors{$variables{'replicates'}}[1];
	$variables{'span'}=$variables{'cell_size'}*$variables{'data_cols'}+($variables{'cell_size'});
}
# END LOG FILE specific shtuff
# ELSE, BAD INPUT
else{
	&update_error("Something is wrong with the processing choice input.  ".&try_again_or_contact_admin(), $q);
	die "Something is wrong with the processing choice input ($variables{'processing_choice'}), contact administrator: $!\n";
}

{ # dont really want any of these variables to exist outside of this loop, except for the stuff in %variables...
	my ($i, $ii)=(0,0);
	my %tempHash;
	my ($previousPlate, $previousQuery) = ('','');
	foreach my $plateID(@{$variables{'plate_order'}}){
		# warn "$variables{'control'} ==> 0000_$plateID->{'query'}";
		# 		warn "0000_$plateID->{'query'}" !~ /^$variables{'control'}$/i;
		if("0000_$plateID->{'query'}" !~ /^$variables{'control'}$/i){
			my @data = keys %{$dataPlate->{$plateID->{'plateNum'}}->{$plateID->{'query'}}};
			$plates_per_page = (scalar(@data) % 2 == 0) ? 2 : 3;
			foreach my $condition(sort @data){
				if(! defined $tempHash{"$plateID->{'query'},$condition,$plateID->{'plateNum'}"}){
					if($i == $plates_per_page || $plateID->{'plateNum'} !~ /^$previousPlate$/ || $plateID->{'query'} !~ /^$previousQuery$/){$ii++;$i=0;}
					my %tempHash1 = ('query'=>$plateID->{'query'},'condition'=>$condition,'plateNum'=>$plateID->{'plateNum'});
					push(@{$variables{'plates_on_page'}->[$ii]}, {%tempHash1});
					$i++;
					$previousPlate = $plateID->{'plateNum'};
					$previousQuery = $plateID->{'query'};
					$tempHash{"$plateID->{'query'},$condition,$plateID->{'plateNum'}"}=1;
				}
			}
		}
	}
}
if(! defined $variables{'plates_on_page'}->[0]){
	shift(@{$variables{'plates_on_page'}});
}
$variables{'num_pages'} = scalar(@{$variables{'plates_on_page'}});
$variables{'from_page'}=-1;
eval {store(\%variables, "$variables{'save_directory'}/variables.dat")};
if($@){ die 'Serious error from Storable, storing %variables: '.$@.'\n';}
# use Data::Dumper;
# #warn Dumper (\%variables);
# warn Dumper($variables{'plates_on_page'});
# warn $variables{'num_pages'};


&update_message('Validating plate names. ', $q);
my @p_data;

foreach my $plateInfo(@{$variables{'plate_order'}}){
	# plateINfo is a hash with the following structure --> 'plateNum'=>plate, 'query'=>query, 'condition'=>condition
	my $query = $plateInfo->{'query'};
	if("0000_$query" ne $variables{'control'}){
		if(!$dinfo->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}}){
			$query=~ s/^0000_//; # remove 0000_ tag used to present controls first
			my $plateLabel = $variables{'originalData'}->{$plateInfo->{'plateNum'}}->{$query}->{$plateInfo->{'condition'}};
			$plateInfo->{'condition'} = 'n/a' if ($plateInfo->{'condition'} eq '' || $plateInfo->{'condition'} eq '-');
			&update_error("The plate with:<br>Plate ID (number): $plateInfo->{'plateNum'}, Query: $plateLabel->{'query'}, Condition: $plateLabel->{'condition'}<br>is in your log file but could not be found in your ScreenMillStats-All file. Please ensure all plates in your log file are in your ScreenMillStats-All file and that their identifiers (names) are identical. ".&try_again_or_contact_admin(), $q);
			die "Could not find plate $plateInfo->{'plateNum'} --> $query --> $plateInfo->{'condition'} in dinfo\n";
		}
	}
}
&update_message('Validation complete, redirecting to cartoon rendering. ', $q);

print <<SCRIPT;
<form action="$asset_prefix->{'base'}/screen_mill/sv_engine" name="next_plates" method = "post" target="_parent">
<input type="hidden" name="none" value="" />
<input type="hidden" name="authenticity_token" value="$variables{'authenticity_token'}" />
<input type="submit" value="Go.">
</form>
<script type="text/javascript">document.next_plates.submit();parent.document.getElementById("flashMessageBackground").style.display="none";</script>
</body></html>
SCRIPT
