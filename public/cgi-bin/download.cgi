#!/usr/bin/perl -wT

BEGIN {
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);
}

use CGI ':standard';
$CGI::POST_MAX = 1024; # prevent users from posting a ton of data
$CGI::DISABLE_UPLOADS = 1; # prevent users from uploading data

my $q = CGI->new;

# &error("blag");
# # The path to where the downloadable files are.
my $path_to_files = '../temp/images/';

# # The path to the error log file
my $error_log     = 'log/file_download_log.txt';

# To prevent hot-linking to your script
my $url = 'http://www.rothsteinlab.com';

# check the amount of data sent to the script
if (my $error = $q->cgi_error()){
  if ($error =~ /^413\b/o) {error('Maximum data limit exceeded.');  }
  else {error('An unknown error has occurred.'); }
}

# check to see if someone has tried to upload a file to the script. “multi-part/form-data” must be used in a CGI forms “encypt” attribute in order to send files.
if ($ENV{'CONTENT_TYPE'} && $ENV{'CONTENT_TYPE'} =~ m|^multipart/form-data|io ) { error('Invalid Content-Type : multipart/form-data.'); }

# check that the request to use the script comes from your website.
#if ($ENV{'HTTP_REFERER'} && $ENV{'HTTP_REFERER'} !~ m|^\Q$url|io) {error('Access forbidden.');}

# get all the params sent to the script
my %IN = $q->Vars;

my $file = $IN{'file'} or error('No file selected.');
my $userDir = $IN{'dir1'};

if($userDir !~ /^[0-9]+$/){error('bad user directory.');}
my $subDir = $IN{'dir2'};
if($subDir !~ /^[0-9]+$/){error('bad user sub directory.')}
$path_to_files = "$path_to_files/$userDir/$subDir";
# warn "$path_to_files/$file";
if(-e "$path_to_files/$file"){
  &download($file) or error('An unknown error has occurred.');
}
else{error('File does not exist.');}

# check to make sure we have a valid filename
# if ($file =~ /^(\w+[\w.-]+\.\w+\,+\_+)$/) {$file = $1;}
# else {error('Invalid characters in filename.');}

sub download {
  my $file = $_[0] or error('No file selected.');

  # Uncomment the next line only for debugging the script
  #open(my $DLFILE, '<', "$path_to_files/$file") or die "Can't open file '$path_to_files/$file' : $!";

  # Comment the next line if you uncomment the above line
  open(my $DLFILE, '<', "$path_to_files/$file") or error("Could not open download file. --> $path_to_files/$file");

  # this prints the download headers with the file size included
  # so you get a progress bar in the dialog box that displays during file downloads.
  print $q->header(-type            => 'application/x-download',
                  -attachment      => $file,
                  -Content_length  => -s "$path_to_files/$file",
  );

  # The binmode() function tells perl to transfer the file in “binary” mode. There is a small chance that
  # using binary mode will corrupt the file on the receiving end. But in general there is no problem using
  # it and in some cases it is necessary. If you experience problems when using binmode, remove or comment out the line.
  binmode $DLFILE;
  print while <$DLFILE>;
  undef ($DLFILE);
  return(1);
}

sub error {
	#print "ERROR!";
  print $q->header(-type=>'text/html'),
        $q->start_html(-title=>'Error'),
        $q->h3("Error: $_[0]"),
        $q->end_html;
  log_error($_[0]);
  exit(0);
}

sub log_error {
 my $error = $_[0];

 # Uncomment the next line only for debugging the script
 #open (my $log, ">>", $error_log) or die "Can't open error log: $!";

 # Comment the next line if you uncomment the above line
 open (my $log, ">>", $error_log) or return(0);

 flock $log,2;
 my $params = join(':::', map{"$_=$IN{$_}"} keys %IN) || 'no params';
 print $log '"', join('","',time,
                    scalar localtime(),
                    $ENV{'REMOTE_ADDR'},
                    $ENV{'SERVER_NAME'},
                    $ENV{'HTTP_HOST'},
                    $ENV{'HTTP_REFERER'},
                    $ENV{'HTTP_USER_AGENT'},
                    $ENV{'SCRIPT_NAME'},
                    $ENV{'REQUEST_METHOD'},
                    $params,
                    $error),
                    "\"\n";
}