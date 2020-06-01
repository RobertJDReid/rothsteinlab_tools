#!/usr/bin/perl -w


BEGIN {
	my $log;
	use CGI::Carp qw(carpout); # prints errors to browser
	open ($log, '>>', 'log/perlErrorLog.log') or die "Cannot open file: $!\n";
	carpout($log);

}
use strict;
# HTML template allows you insert variables calculated here into a
# properly (hopefully) formated HTML template...helps separate Perl from HTML
use HTML::Template;
# my $template = HTML::Template->new(filename => 'mutator.tmpl') || die "Could not open template file $!";

use Modules::ScreenAnalysis qw(:asset);

# analyze a DNA sequence for restriction enzymes
use Bio::Restriction::Analysis;
use Bio::PrimarySeq;
use Bio::Tools::CodonTable;

#############  Codon stuff   #################
my $myCodonTable   = Bio::Tools::CodonTable->new();

use CGI;
#use CGI::Ajax;
my $cgi  = CGI->new();
#my $ajax = CGI::Ajax->new( calculate_mutation => \&calculate_mutation );

#$ajax->JSDEBUG(1);
#print $ajax->build_html( $cgi, \&main );
&main();

sub main{
	my $input=uc($cgi->param('sequence'));
	my $temp="";
	my $mid=(split /\./,"".(length($input)/3/2).".")[0];
	my $count=0;
	my (@out_codons, @codons);
	for(my $i=0;$i<length($input);$i+=3){
		$temp=substr($input, $i, 3);
		push(@codons, $temp);
		if($count==$mid){$temp="<span style=\"color:red;font-weight:bold;\">$temp</span>";}
	  my %temp=( codon => $temp );
	  push(@out_codons, \%temp);
		$count++;
	}
	# add some error checking, e.g. is it 15 nt?
	# work in a routine to remove whitespace etc

	my (@out_aa,@aa);
	$count=0;
	foreach my $codon(@codons){
		$temp=$myCodonTable->translate($codon);
		push (@aa, $temp);
		if($count==$mid){$temp="<span style=\"color:red;font-weight:bold;\">$temp</span>";}
		my %temp1 = ( aa => $temp);
		push (@out_aa, \%temp1);
		$count++;
	}

	print $cgi->header();

	if($cgi->param('doIT')){calculate_mutation(\@codons, \@aa);}
	else{
		my $asset_prefix = &static_asset_path();
		my $template = HTML::Template->new(filename => 'templates/aa_mutator/mutator.tmpl') || die "Could not open template file $!";
		$template->param(initial_seq_loop => \@out_codons);
		$template->param(aa_loop => \@out_aa);
		my $temp1 = defined $aa[$mid] ? $aa[$mid] : '';
		$template->param(variable_aa => "<span style=\"color:red;font-weight:bold;\">$temp1</span>");
		$template->param(sequence => $input);
		$template->param(base => $asset_prefix->{'base'});
		$template->param(asset_prefix => $asset_prefix->{'images'});
		print $template->output;
	}

}

sub calculate_mutation{
	my ($codons, $aa) = @_;
	# start calculations
	my %frq_table = (
		GGG => '0.01',
		GGA => '0.02',
		GGT => '0.91',
		GGC => '0.06',
		GAG => '0.1',
		GAA => '0.9',
		GAT => '0.48',
		GAC => '0.52',
		GTG => '0.04',
		GTA => '0.03',
		GTT => '0.56',
		GTC => '0.37',
		GCG => '0.01',
		GCA => '0.06',
		GCT => '0.65',
		GCC => '0.28',
		AGG => '0.01',
		AGA => '0.83',
		AGT => '0.05',
		AGC => '0.04',
		AAG => '0.78',
		AAA => '0.22',
		AAT => '0.22',
		AAC => '0.78',
		ATG => '1',
		ATA => '0.02',
		ATT => '0.52',
		ATC => '0.46',
		ACG => '0.01',
		ACA => '0.06',
		ACT => '0.5',
		ACC => '0.43',
		TGG => '1',
		TGA => '0.09',
		TGT => '0.89',
		TGC => '0.11',
		TAG => '0.1',
		TAA => '0.8',
		TAT => '0.19',
		TAC => '0.81',
		TTG => '0.69',
		TTA => '0.18',
		TTT => '0.27',
		TTC => '0.73',
		TCG => '0.01',
		TCA => '0.06',
		TCT => '0.52',
		TCC => '0.33',
		CGG => '0',
		CGA => '0',
		CGT => '0.15',
		CGC => '0',
		CAG => '0.05',
		CAA => '0.95',
		CAT => '0.35',
		CAC => '0.65',
		CTG => '0.02',
		CTA => '0.07',
		CTT => '0.03',
		CTC => '0',
		CCG => '0.01',
		CCA => '0.8',
		CCT => '0.18',
		CCC => '0.02',
	);

	my $input=uc($cgi->param('sequence'));
	#	This is wt seq to look for RFLPs
	my $primary_seq=new Bio::PrimarySeq
	  (-seq => $input,
	   -primary_id => 'wt',
	   -molecule => 'dna');
	my @init_seq_array = split (//,$primary_seq->seq);
	my $change_aa = uc($cgi->param('aa'));

	my $wt_yeastiness = $frq_table{$codons->[1]}*$frq_table{$codons->[2]}*$frq_table{$codons->[3]};

	########### get list of REs that cut and store in array
	# The following code is from example files at CPAN for the BioPERL module


	# this makes a restriction analysis object for the input sequence

	my $ra_primary = Bio::Restriction::Analysis->new(-seq=>$primary_seq);
	# and generates a list of cutters that is passed into the "primary_cutlist" array

	my $primary_cutters=$ra_primary->cutters;
	my @primary_cutlist = ();
	foreach ($primary_cutters->each_enzyme) {
		push (@primary_cutlist, $_->name)
	};

	############ translate the primary sequence
	my $primary_trans = join('', @{$aa});
	##############
	#
	#  first and last codon will not vary in this example, but the program can be expanded to include them later

	my $first_codon = $codons->[0];
	my $last_codon = $codons->[(@{$codons}-1)];

	#print "first codon is $first_codon and last codon is $last_codon\n";

	############## ask what the codon change is
	#
	#  But right now I am just setting it as a Thr to Ala change, or whatever...
	#print "changing $three_codon to $change_aa\n";
	#$change_aa = "L";

	############## set up loops to go trough all possible ways of coding for middle three AAs

	# setup data array

	#my @out_array = ();

#	my $outfile = ">out.tab";

#	open (OUT,$outfile) || die "can't open for output moron\n";

	# reverse translation gets all the codons that can make the particular AA in the sequence

	# $trans_array[2] = $change_aa;

	my @second_codon = $myCodonTable->revtranslate($aa->[1]);
	my @third_codon = $myCodonTable->revtranslate($change_aa);
	my @fourth_codon = $myCodonTable->revtranslate($aa->[3]);
	#print "two @second_codon three @third_codon & four @fourth_codon \n";

	#  This is printed with an arbitrarily high leading number so that the wt sequence stays at the top of the list on a sort
	#my $template = HTML::Template->new(filename => 'template/aa_mutator/results_table.tmpl') || die "Could not open template file $!";

	#print OUT "10\t$outstring\t@primary_cutlist\n";	# thought this would make sort easier, but it is nice to know the wt value too

	# set up the three nested loops
	my %resultsA;
	my %resultsB;
	my $count=0;
	foreach my $codon2 (@second_codon) {
		foreach my $codon3 (@third_codon) {
			foreach my $codon4 (@fourth_codon) {

				# cobble the sequence back together based on the fixed (outer) and computed codons

				my $seq_string = join ('',($first_codon, $codon2, $codon3, $codon4, $last_codon));
				# calculate a product of the inner three codon frequencies based on the yeast frq table above
				# note that the hash is upper case codons and the reverse translate returned lower case

				my $yeastiness = $frq_table{uc($codon2)}*$frq_table{uc($codon3)}*$frq_table{uc($codon4)};  # only using the three changed codons right now, but would have to expand this if more AAs were included in anal

				if(defined $yeastiness && $yeastiness > 0 ){
					# make a sequence object with the new sequence string
					my $seq_opt = new Bio::PrimarySeq
					  (-seq =>$seq_string,
					   -molecule => 'dna');
					# run a restriction analysis as above

					my $ra=Bio::Restriction::Analysis->new(-seq=>$seq_opt);
					my $cutters=$ra->cutters;
					my @cut_list = ();
					foreach ($cutters->each_enzyme) {push (@cut_list, $_->name)};

					# I thought that we would do some conditional statement here but for now I am jsut printing to a table
					#print "\b. \n";
					#unless(exist $results{$yeastiness}){$yeastiness="$yeastiness-a";}
					$seq_string = join ('',("$first_codon<em> ", $codon2, $codon3, $codon4, " </em>$last_codon"));
					$resultsA{$seq_string}=$yeastiness;
					$resultsB{$seq_string}=join(', ', @cut_list);
				}
			}	# end fourth
			#print ".";
		}	# end third
		#print " o\n";
	}	# end second
	my @resultsArray;
	foreach my $seq(sort {$resultsA{$b} <=> $resultsA{$a}} keys %resultsA){
		my %output_Row=( yeastiness => $resultsA{$seq},
										 seq_string => $seq,
										 cut_list => $resultsB{$seq});
		push(@resultsArray, \%output_Row);
	}
	my $template = HTML::Template->new(filename => 'templates/aa_mutator/resultsTable.tmpl') || die "Could not open template file $!";
	$template->param(o_yeastiness => $wt_yeastiness);
	$template->param(o_seq_string => $input);
	$template->param(o_cut_list => join(", ", @primary_cutlist));
	$template->param(result_table_loop => \@resultsArray);
	print $template->output;
		#my $primary_trans = $myCodonTable->translate($results{$result});
	#	printf "%5.6f --> $results{$result}<br/><br/>", $result;

	print "\n\n\nDone!<br/>";
}
