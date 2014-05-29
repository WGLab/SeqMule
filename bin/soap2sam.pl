#!/usr/bin/perl -w

# Contact: lh3
# Version: 0.1.1

use strict;
use warnings;
use Getopt::Std;

&soap2sam;
exit;

sub mating 
{
    my ($s1, $s2) = @_;
    my $isize = 0;
    if ($s1->[2] ne '*' && $s1->[2] eq $s2->[2]) { # then calculate $isize
	my $x1 = ($s1->[1] & 0x10)? $s1->[3] + length($s1->[9]) : $s1->[3];
	my $x2 = ($s2->[1] & 0x10)? $s2->[3] + length($s2->[9]) : $s2->[3];
	$isize = $x2 - $x1;
    }
    # update mate coordinate
    if ($s2->[2] ne '*') {
	@$s1[6..8] = (($s2->[2] eq $s1->[2])? "=" : $s2->[2], $s2->[3], $isize);
	$s1->[1] |= 0x20 if ($s2->[1] & 0x10);
    } else {
	$s1->[1] |= 0x8;
    }
    if ($s1->[2] ne '*') {
	@$s2[6..8] = (($s1->[2] eq $s2->[2])? "=" : $s1->[2], $s1->[3], -$isize);
	$s2->[1] |= 0x20 if ($s1->[1] & 0x10);
    } else {
	$s2->[1] |= 0x8;
    }
}

sub soap2sam {
    my %opts = ();
    getopts("apo:s:u:", \%opts);
    die("Usage: soap2sam.pl [-a] [-p] [-o outfile] [-s unpaired] [-u unmapped] <aln.soap>\n") if (@ARGV == 0 && -t STDIN);
    my $is_paired = defined($opts{p});
    if (my $out=$opts{o})
    {
	if ($opts{a})
	{
	    open OUT,'>>',$out or die "Can't write to $out: $!\n";
	} else
	{
	    open OUT,'>',$out or die "Can't write to $out: $!\n";
	}
    }

    {
	# core loop
	my ($s_last, $s_curr) = ([], []);
	#aligned, paired (if any) reads
	while (<>) 
	{
	    s/[\177-\377]|[\000-\010]|[\012-\040]//g;
	    next if (&soap2sam_aux($_, $s_curr, $is_paired, 0) < 0);
	    if (@$s_last != 0 && $s_last->[0] eq $s_curr->[0])  #assuming two paired reads appear next to each other
	    {
		mating($s_last, $s_curr);
		print OUT join("\t", @$s_last), "\n";
		print OUT join("\t", @$s_curr), "\n";
		@$s_last = (); @$s_curr = ();
	    } else 
	    {
		print OUT join("\t", @$s_last), "\n" if (@$s_last != 0);
		my $s = $s_last; $s_last = $s_curr; $s_curr = $s;
	    }
	}
	print OUT join("\t", @$s_last), "\n" if (@$s_last != 0);
    }

    #aligned, unpaired reads (if any)
    if (defined $opts{s} && -f $opts{s} && open UNPAIR,'<',$opts{s})
    {
	my ($s_last, $s_curr) = ([], []);
	while(<UNPAIR>)
	{
	    s/[\177-\377]|[\000-\010]|[\012-\040]//g;
	    next if (&soap2sam_aux($_, $s_curr, $is_paired, 1) < 0); #last bit for mate_unpaired
	    if (@$s_last != 0 && $s_last->[0] eq $s_curr->[0])  #assuming two paired reads appear next to each other
	    {
		mating($s_last, $s_curr);
		print OUT join("\t", @$s_last), "\n";
		print OUT join("\t", @$s_curr), "\n";
		@$s_last = (); @$s_curr = ();
	    } else 
	    {
		print OUT join("\t", @$s_last), "\n" if (@$s_last != 0);
		my $s = $s_last; $s_last = $s_curr; $s_curr = $s;
	    }
	}
	print OUT join("\t", @$s_last), "\n" if (@$s_last != 0);
	close UNPAIR;
    }

    #unaligned reads
    if (defined $opts{u} && -f $opts{u} && open UNMAP,'<',$opts{u})
    {
	my ($id,$seq);
	while(<UNMAP>)
	{ 
	    s/[\177-\377]|[\000-\010]|[\012-\040]//g;
	    my $s=[];
	    if (/^>/)
	    {
		$id=$_;
	    } else
	    {
		$seq=$_;
	    }
	    next if &soap2sam_unmapped($id,$seq,$s,$is_paired)<0;
	    print OUT join("\t", @$s), "\n" unless @$s == 0;
	    $id=$seq=undef;
	}
	close UNMAP;
    }

    close OUT;
    warn "NOTICE: SOAP to SAM conversion done.\nOutput written to $opts{o}.\n";
}

sub soap2sam_unmapped {
    my ($id,$seq,$s,$is_paired) = @_;
    return -1 unless defined $id && defined $seq;
    chomp ($id,$seq);
    return -1 if $id!~/^>/ or !$seq;
    # read name
    $s->[0] = $id;
    $s->[0] =~ s/^>|\/[12]$//g;
    # initial flag (will be updated later)
    $s->[1] = 0;
    $s->[1] |= 1 if $is_paired;
    $s->[1] |= 4; #mark as unmapped
    # read & quality
    $s->[9] = $seq;
    $s->[10] = '*';
    # cigar
    $s->[5] = '*';
    # coor
    $s->[2] = '*'; $s->[3] = 0;
    # mapQ
    $s->[4] = 0;
    # mate coordinate
    $s->[6] = '*'; $s->[7] = $s->[8] = 0;
    # aux
    return 0;
}
sub soap2sam_aux {
    my ($line, $s, $is_paired,$mate_unpaired) = @_;
    chomp($line);
    my @t = split(/\s+/, $line);
    return -1 if (@t < 9 || $line =~ /^\s/ || !$t[0]);
    @$s = ();
    # fix SOAP-2.1.x bugs
    @t = @t[0..2,4..$#t] unless ($t[3] =~ /^\d+$/);
    # read name
    $s->[0] = $t[0];
    $s->[0] =~ s/\/[12]$//g;
    # initial flag (will be updated later)
	$s->[1] = 0;
    if ($is_paired)
    {
	$s->[1] |= 1 | 1<<($t[4] eq 'a'? 6 : 7);
	$s->[1] |= 2 ;
	$s->[1] |= 8 if ($mate_unpaired);
    }
    # read & quality
    $s->[9] = $t[1];
    $s->[10] = (length($t[2]) > length($t[1]))? substr($t[2], 0, length($t[1])) : $t[2];
    # cigar
    $s->[5] = length($s->[9]) . "M";
    # coor
    $s->[2] = $t[7]; $s->[3] = $t[8];
    $s->[1] |= 0x10 if ($t[6] eq '-');
    # mapQ
    $s->[4] = $t[3] == 1? 30 : 0;
    # mate coordinate
    $s->[6] = '*'; $s->[7] = $s->[8] = 0;
    # aux
    push(@$s, "NM:i:$t[9]");
    my $md = '';
    if ($t[9]) {
	my @x;
	for (10 .. $#t) {
	    push(@x, sprintf("%.3d,$1", $2)) if ($t[$_] =~ /^([ACGT])->(\d+)/i);
	}
	@x = sort(@x);
	my $a = 0;
	for (@x) {
	    my ($y, $z) = split(",");
	    $md .= (int($y)-$a) . $z;
	    $a += $y - $a + 1;
	}
	$md .= length($t[1]) - $a;
    } else {
	$md = length($t[1]);
    }
    push(@$s, "MD:Z:$md");
    return 0;
}

__END__

=head1 FORMAT

SAM:

FCC073DACXX:8:1202:11262:199317#        103     1       10058   12      39M1D44M7S      =       10058   84      CCCTAACCCTAACCCTAACCCTAACCCTAACCCTAACCCAACCCTAACCCAACCCTAACCCTAACCCTAACCCTAACCCTAACAGATCGG     CC@FFFFFHGHHHJJJIJJJIIHGGHIIJIIIJIG>GHIIJGHIBGBEHGHIGHHIHFFCHFF@BACCCAB=ADCDB??B<?ACC3>A?0      MD:Z:39^T44     PG:Z:MarkDuplicates    RG:Z:READGROUP_father   NM:i:1  AS:i:76 XS:i:72

unpaired read:

FCC073DACXX:8:1101:1421:1972#/2	TTAAGGAAACACAAATCACATTCAGAGCTTCCTTAATTTGAGGATGATGAGACTCATGGACTAGTTCTTCACAAATCCAAATACCTAAAC	BCHC==A77=7HCB8.@=F@=4FB<EIHBAHDCGHGGEIFHD>ECDDB<EE??<IHHH@DFBA;DAEAC<,B>C<+??CA:FADDDDB==	2	b	90	-	14	36125015	0	90M	90

unmapped read:

>FCC073DACXX:8:1101:1421:1972#/1
GATTAGGATCTGAATAATTTTCAAGGGAGAATCAGGCTGGTAAATCTGAAGTCTAGGGACATAATGGACCAGCATGTGAAGCATGCTACA

aligned read:

FCC073DACXX:8:1101:1394:1951#/1	GTGGCACGTAGTTCCCTACCTGGATGAATCTCTTCATCACTTAGACTCTCCAGCGTCAAGTCTTTAGAAACAAAAACACCAGAATAAGTC	#1=DFFFFHGHHHJJJJJJJJJJIJIIJIIJJJJJJJJJJJJJJGIIGJIJJIJJIJJHIFHGGIII@CGEFFHDDFDCDDDBDDCDDCC	1	a	90	+	22	23955457	1	C->0G-29	90M	0C89

One line for One hit. The columns are separated by '\t'.
1)id:	  
id of read;
2)seq:	
full sequence of read. the read will be converted to the complementary sequence if mapped on the reverse chain 
of reference;
3)qual:	
quality of sequence. corresponding to sequence, to be consistent with seq, it will be converted too if mapped 
on reverse chain;
4)number of hits:	
number of equal best hits. the reads with no hits will be ignored;
5)a/b:	
flag only meaningful for pair-end alignment, to distinguish which file the read is belonging to;
6)length:	
length of the read, if aligned after trimming, it will report the information of trimmed read;
7)+/-:	
alignment on the direct(+) or reverse(-) chain of the reference;
8)chr:	
id of reference sequence;
9)location: 
location of first bp on the reference, counted from 1;
10)types:	type of hits.
"0":	exact match.
"1~100	RefAllele->OffsetQueryAlleleQual":	number of mismatches, 
followed by detailed mutation sites and switch of allele types. 
Offset is relative to the initial location on reference. 
'OffsetAlleleQual': offset, allele, and quality.
Example: 
"2 A->10T30	C->13A32" means there are two mismatches, one on location+10 of reference, 
    and the other on location+13	of reference. The allele on reference is A and C respectively,
while query allele type and its  quality is T,30 and A,32.
"100+n Offset":	n-bp insertion on read. Example: "101 15" means 1-bp insertion on read, 
start after location+15 on reference.
"200+n Offset":	n-bp deletion on read. Example: "202 16" means 2-bp deletion on query, 
start after 16bp on reference.


=cut
