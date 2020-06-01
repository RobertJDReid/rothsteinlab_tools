#!/usr/bin/perl -w
# ******************************************************
# Saved session display
# Program created on 01 - February - 2008
# Authored by: John Dittmar
# ******************************************************

# to do:
# what to do if MAJOR ERROR OCCURs

BEGIN {
	$|=1;
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
	use CGI qw/:standard/;
	$CGI::HEADERS_ONCE = 1;
}

# HTML template allows you insert variables calculated here into a
# properly (hopefully) formated HTML template...helps seperate Perl from HTML
use strict;
use HTML::Template;
my $template = HTML::Template->new(filename => '../templates/dr_show_sessions.tmpl') || die "Could not open template file $!";
use File::Find; # needed for finddepth
use Time::Local; # needed for time/date stuff
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use Modules::ScreenAnalysis qw(:sessions); # use my module and only load routines in sessions
my $asset_prefix = &static_asset_path();
my $size_limit = 1;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 1 MB limit
use Storable qw(retrieve);


#  ********************* start variable declarations *********************
my ($q, $user, $file, $sec, $min, $hours, $day, $month, $year, $how_old,$wday,$yday,$isdat, $form_name);
my (%plate, %normalization_values, %queries, %variables, %dynamicVariables);
my ($total_number_plates, $plate, $queries, $num_screened);
# initial_time holds the current date and time in seconds, $mod_TIME holds
# the date and time that the current directory was last modified, in seconds
my ($initial_TIME, $mod_TIME);
my %temp; # temporary hash used to feed loop info to HTML::Template
my @out_info; # array needed for loops in HTML:Template
my $warning; # used to figure out if we retrieved data structures properly
my @directories; # holds directories that store user saved sessions
my $upload_dir; # directory that we will be working with
my $counter=0;
$q  = CGI->new(); # start a new CGI instance
print $q->header();

# do not conditionalize the following 2 statements b/c they are ajaxy
&initialize($q, $size_limit);
&validateUser(\%variables,$q);

$upload_dir='../../../data/user_data/dr/user_directory';
$upload_dir.="/$variables{'user'}";
# function call to delete old user files
finddepth(sub{&bookkeeper($_)}, $upload_dir);

# open user directory, iterate over it, store all relevant directory paths in array
opendir (DH,"$upload_dir");
my @sessions;
while ($file = readdir DH) {
	if(-d "$upload_dir/$file" && $file ne '.' && $file ne '..'  && $file !~ /\.svn/gi){push(@directories, "$upload_dir/$file");push(@sessions, $file);}
}
close DH;

# retrieve info about todays date
($sec, $min, $hours, $day, $month, $year) = (localtime)[0..5];
# convert date to seconds
$initial_TIME = timelocal($sec, $min, $hours, $day, $month, $year);
if(@directories){
	for(my $i=0; $i<@directories; $i++){

		my $count=0;
		opendir ( DIR, "$directories[$i]" ) || die "Error in opening dir $directories[$i]\n";
		while ( (my $filename = readdir(DIR)) ) {
		  next if $filename =~ /^\.{1,2}$/; # skip . and ..
		  $count++;
		}
		closedir(DIR);
		next if $count < 1;

		# (-M "$directories[$i]") give how old, in days, this directory is since it was last modified multiply that by 86400 to get the number of seconds
		$how_old=86400*(-M "$directories[$i]");
		$mod_TIME=$initial_TIME-$how_old;
		# convert mod_time into a more readable format, $wday=day pf the week, yday = year # day (1-365), $isday=???
		($sec, $min, $hours, $day, $month, $year, $wday, $yday, $isdat)=localtime($mod_TIME);
		$month=$month+1; # month starts at 0 so add 1
		$year=$year+1900; # the year 1901=1 so add 1900 to get a more user freindly readout
		#*************** start retrieving data structures from save location ********************
		$warning=0;
		%plate= eval{%{retrieve("$directories[$i]/plate_data.dat")}};
		if($@){$warning=1;}#warn "$@";}
		elsif(!%plate){ $warning=1;}#warn "I/O error from Storable with plate_data.dat: $!";
		%normalization_values= eval{%{retrieve("$directories[$i]/normalization_values.dat")}};
		if($@){$warning=1;}#warn "$@";}
		elsif(!%normalization_values){ $warning=1;}#warn "I/O error from Storable with normalization_values.dat: $!";
		%queries= eval{%{retrieve("$directories[$i]/queries.dat")}};
		if($@){$warning=1;}#warn "$@";}
		elsif(!%queries){ $warning=1;}#warn "I/O error from Storable with queries.dat: $!";
		%variables= eval{%{retrieve("$directories[$i]/variables.dat")}};
		if($@){$warning=1;}#warn "$@";}
		elsif(!%variables){ $warning=1;}#warn "I/O error from Storable with variables.dat: $!";
		%dynamicVariables= eval{%{retrieve("$directories[$i]/dynamicVariables.dat")}};
		if($@){$warning=1;}#warn "$@";}
		elsif(!%dynamicVariables){ $warning=1;}#warn "I/O error from Storable with dynamicVariables.dat: $!";
		#*************** end retrieving data structures from save location ********************

		if(!$warning){
			# print out key statistics relating to this saved session
			$queries=join(', ', keys %queries);
			$queries=~ s/0000_//g;
			$num_screened=keys %{$dynamicVariables{'plates_reviewed'}};
			if(!$variables{'log_description'} || $variables{'log_description'} eq ""){
				$variables{'log_description'}="n/a";
			}
			$form_name="recover_form$counter";
			# need a fresh hash for HTML::template (b/c we are passing references)...that is why the 'my' is there...
			my $pd = int(100*($num_screened/$variables{'total_number_plates'})+0.5);
			my $ec = $pd > 99 ? 'allRadius' : 'leftRadius';
			my $pd_disp = $pd < 15 ? "&nbsp;$pd" : $pd;
			my %temp = ( queries => $queries,
								density => $variables{'density'},
								replicates => $variables{'replicates'},
								date_saved => "$month-$day-$year",
								info => $variables{'log_description'},
								num_screened => $num_screened,
								percent_done => $pd,
								percent_done_disp => $pd_disp,
								extra_class => $ec,
								at => $q->param('at'),
								total_number_of_plates => $variables{'total_number_plates'},
								directory => $sessions[$i],
								form_name => $form_name,
								root_dir => $asset_prefix->{'base'});
			push (@out_info, \%temp);
		}
		$counter++;
	}
}
else{
	$template->param(no_sessions => "NO SAVED SESSIONS FOUND");
}
$template->param(dir_loop => \@out_info);
print $template->output;
