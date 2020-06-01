#!/usr/bin/perl -w

BEGIN {
	my $log;
	use CGI::Carp qw(carpout);
	open ($log, '>>', '../log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}
use lib '..';
use lib '/home/rothstei/perl5/lib/perl5';
use strict;
use CGI;
use Storable qw(store retrieve); # to store / retrieve data structures on disk
use Modules::ScreenAnalysis qw(:asset);
my $asset_prefix = &static_asset_path();

my $size_limit = 10;
$CGI::POST_MAX = 1024 * 1000 * $size_limit; # 10 MB limit
my $q=new CGI; # initialize new cgi object
if ($q->cgi_error()) {
	print $q->cgi_error();
print <<'EOT';
    <p>
    The file you are attempting to upload exceeds the maximum allowable file size.
    <p>
    Please refer to your system administrator
EOT
	print $q->hr, $q->end_html;
	exit 0;
}

print $q->header(); # the "magic line" that tells the WWW that we are an HTML document
# check if directory exists for this user
my $dir = '../../temp/screenTrollOutput';
if(! -d $dir){
	eval{mkdir($dir, 0750) || die "Could not create directory $dir: $!";};
	if($@){
		&printError("Error generating output0.");
	}
}
&bookkeeper($dir);
my $count = 0;
if(-d $dir){
	# find out what we can name this new directory (by figure out what is already there, or not there)
	opendir(DIR, $dir);
	my @files = readdir(DIR);
	$count = scalar(@files);
	while(-e "$dir/$count"){	$count++;	}
	eval{mkdir("$dir/$count", 0755) || die "Could not create directory $dir/$count: $!";};
	if($@){&printError($@);}
	$dir = "$dir/$count";
}
else{&printError("Error generating output.");}

if($q->param('outputContents')){
	open(my $OUT, ">$dir/screenTrollOutput.xls") or die "$dir/screenTrollOutput.xls.  $!";
	print $OUT $q->param('outputContents');
	close $OUT;
	print '<a href="'.$asset_prefix->{'base'}.'/temp/screenTrollOutput/'.$count.'/screenTrollOutput.xls" id="downloadLink" style="padding-left:10px">';
	print 'Download</a>';
	print '<script type="text/javascript" charset="utf-8">window.location=$(\'#downloadLink\').prop(\'href\');</script>';
}
else{&printError("Error generating output1.");}

sub printError{
	my $dieMsg = shift;
	print "<div class='alert'>Error generating output!</div>";
	die $dieMsg;
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
			if (-M "$dir/$file" > 1){
				if(-d "$dir/$file"){rmdir("$dir/$file") if $dir =~ /\.\.\/$asset_prefix->{'base'}\/temp\/screenTrollOutput/i;} # rmdir will remove any empty directories
				else{unlink "$dir/$file";}
			}
		}
	}
}