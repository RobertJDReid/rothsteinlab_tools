#!/usr/bin/perl -w
use strict;
use File::Find;

my @uds = ("../data/user_data/", "../public/temp/", "../public/temp/screenTrollOutput/");
my $ud = '';
foreach my $ud1(@uds){
	warn $ud1;
	&checkDir($ud1,0);	
	$ud = $ud1;
	find(\&bookkeeper, $ud);
	find(\&bookkeeper, $ud);
}


sub bookkeeper {
	# Delete out old sessions that have been abandoned (ie have not been modified) for greater then 1 day
	my $dir=$_;
	if(-d $dir){
		my $temp = $File::Find::name;
		$temp =~ s/^$ud//;		
		if($temp !~ /^\./ && $temp !~ /\/\./ && $temp !~ /^\.{1,2}$/){ # ignore stuff that starts with a period
			&checkDir($dir,1);
		}
	}
}

sub checkDir {
	my ($dir,$deleteDirs) = @_;
	opendir (DH,"$dir");		
	while (my $file = readdir DH) {
		# the next if line below will allow us to only consider files with extensions
		next if ($file =~ /^\.{1,2}$/);	# skip . and ..
		#  if this 'file' is a directory
		#warn "$dir/$file";
		if(-d "$dir/$file"){
			opendir ( DIR, "$dir/$file" ) || die "Error in opening dir $dir/$file\n";
			my $count=0;
			while ( (my $filename = readdir(DIR)) ) {
			  next if $filename =~ /^\.{1,2}$/; # skip . and ..
			  $count++;
			}
			closedir(DIR);
			# if there are no files in this directory, deleted it
			if($count < 1 && $deleteDirs){print "deleting $dir/$file - empty dir\n";rmdir("$dir/$file");}
		}
		# else this is a file, if it is older than 30 days, delete it
		elsif (-M "$dir/$file" > 15){ 
			print "deleting $dir/$file age ==";
			print -M "$dir/$file";
			print "\n";
			# warn -d "$dir/$file";
			unlink "$dir/$file";
		}
	}
}