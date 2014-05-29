#!/usr/bin/env perl

use warnings;
use strict;
use FindBin qw/$RealBin/;
use File::Spec;
use lib File::Spec->catdir($RealBin,"..","lib");
use SeqMule::Utils;

die "Usage: $0 <samtools-location> <sorted-bam> [bed-region]\n" unless @ARGV==2 or @ARGV==3;

my ($samtools, $bamfile, $bedfile)=@ARGV;
my $original_bed=$bedfile; #bed file could be modified (add or rm 'chr') later
die "No $bamfile.\n" unless -f $bamfile;

#check if BED chr and BAM header agree
if ($bedfile && -f $bedfile)
{
    my $chr_status=&SeqMule::Utils::compareChr({file1=>$bedfile,type1=>'bed',file2=>$bamfile,type2=>'bam',samtools=>$samtools});
    if ( $chr_status ==0)
    {
	die "ERROR: Chromosome name in BED doesn't match BAM header\n";
    } elsif ($chr_status ==1)
    {
	warn "NOTICE: all chromosome names in BED can be found in BAM header.\n";
    } else
    {
	#add or remove chr
	$bedfile=&SeqMule::Utils::addOrRmChrInBED($bedfile);
    }

    #check if some regions overlap, if yes, merge overlapping regions
    $bedfile=&SeqMule::Utils::rmOverlapBED($bedfile);

    warn "NOTICE: Calculating coverage ...\n";
    open (FH, "$samtools depth -b $bedfile $bamfile | cut -f 3 |") or die "Error: cannot read from SAMTools output: $!\n";
    warn "NOTICE: Start reading from SAMTools depth command ...\n";

    my %dist;		#coverage distribution
    while (<FH>) {
	chomp;
	$dist{$_}++; #one line represents one base pair
    }

    close FH;

    #count total base
    my $total_base=0;
    open (FH, "$samtools depth $bamfile | cut -f 3 |") or die "Error: cannot read from SAMTools output: $!\n";
    while(<FH>)
    {
	chomp;
	$total_base+=$_;
    }
    close FH;

    my ($total_len,$total_base_inside,$capture_percent)=(0,0,0);
    $total_len = &SeqMule::Utils::bed2total($bedfile); 
    map {$total_base_inside += $dist{$_}*$_} keys %dist;
    if($total_base<=0)
    {
	$capture_percent=0;
    } else
    {
    $capture_percent=$total_base_inside/$total_base*100;
}

    warn "NOTICE: $original_bed contains $total_len base pairs\n";
    print "total length (defined by $original_bed) = ";
    if ($total_len<1000)
    {
	print $total_len,"bp\n";
    } elsif ($total_len<1_000_000)
    {
	print sprintf("%.2f",$total_len/1000),"Kb\n";
    } else
    {
	print sprintf("%.2f",$total_len/1000_000),"Mb\n";
    }

    print "Fraction of reads mapped to target region = ", ($capture_percent<0.01? "<0.01":sprintf("%.2f",$capture_percent)),"%\n";

    if ($total_base_inside/$total_len >= 0.01)
    {
	print "Average coverage in target region = ", sprintf("%.2f",$total_base_inside/$total_len) , "\n";
    } else
    {
	print "Average coverage in target region = <0.01\n";
    }

    my $covered_base_count = 0;
    for my $key (sort {$b<=>$a} keys %dist) 
    {
	#when output changes, remember to change 'stats' program too!!!
	#when output changes, remember to change 'stats' program too!!!

	$covered_base_count += $dist{$key};
	my $percent= sprintf("%.2f",100*$covered_base_count/$total_len);
	if ($percent<0.01)
	{
	    $percent="<0.01";
	}
	print "coverage = $key count = $dist{$key} cum_frac = $percent%\n";
    }
} else
{
    warn "WARNING: $bedfile does NOT exist, ignore it...\n" if $bedfile;
    warn "NOTICE: No capture region, use BAM header instead.\n";
    warn "NOTICE: Calculating coverage ...\n";
    open (FH, "$samtools depth $bamfile | cut -f 3 |") or die "Error: cannot read from SAMTools output: $!\n";
    warn "NOTICE: Start reading from SAMTools depth command ...\n";

    my %dist;		#coverage distribution
    while (<FH>) {
	chomp;
	$dist{$_}++; #one line represents one base pair
    }
    close FH;

#count total base
    my ($total_base,$total_len)=(0,0);
    my %chr=map {($$_[0] => $$_[1])} &SeqMule::Utils::getBAMHeader($samtools,$bamfile);

    map { $total_base+=$_*$dist{$_};} keys %dist;
    map { $total_len+=$_ } values %chr;

    warn "NOTICE: $bamfile reference contains $total_len base pairs\n";
    print "total length (defined by $bamfile) = ";
    if ($total_len<1000)
    {
	print $total_len,"bp\n";
    } elsif ($total_len<1_000_000)
    {
	print sprintf("%.2f",$total_len/1000),"Kb\n";
    } else
    {
	print sprintf("%.2f",$total_len/1000_000),"Mb\n";
    }

    if ($total_base/$total_len>=0.01)
    {
	print "Average coverage = ", sprintf("%.2f",$total_base/$total_len) , "\n";
    } else
    {
	print "Average coverage = <0.01\n";
    }

    my $covered_base_count = 0;
    for my $key (sort {$b<=>$a} keys %dist) 
    {
	#when output changes, remember to change 'stats' program too!!!
	#when output changes, remember to change 'stats' program too!!!

	$covered_base_count += $dist{$key};
	my $percent= sprintf("%.2f",100*$covered_base_count/$total_len);
	if ($percent<0.01)
	{
	    $percent="<0.01";
	}
	print "coverage = $key count = $dist{$key} cum_frac = $percent%\n";
    }
}
