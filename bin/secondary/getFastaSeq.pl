#!/usr/bin/env perl

use strict;
use warnings;

die "Usage: $0 <FASTA> <1:1-1000 2:3-999 ...>\n" unless @ARGV>=2;

my $fa=shift @ARGV;
my $idx="$fa.fai";
my @regions=@ARGV;

die "ERROR: index file missing or empty\n" unless -s $idx;

my %contig=&readIdx($idx);


open IN,'<',$fa or die "Failed to read $fa: $!\n";

for my $i(@regions)
{
    die "1:1-1000 format expected: $i\n" unless $i=~/(.*?):(\d+)-(\d+)/;
    my ($id,$start,$end)= ($1,$2,$3);
    my $len;
    my $offset;
    my $return;
    my $nbreak_start;
    my $nbreak_end;

    #check if contig exists
    die "$id doesn't exist\n" unless exists $contig{$id};
    #check if the region is out of bound
    die "Region out of bound or end smaller than start: $i\nContig length: $contig{$id}{length}\n" 
    unless ($end>=1 && 
	$start>=1 && 
	$end >= $start && 
	$end <= $contig{$id}{length});

    my $nchar_ln=$contig{$id}{nchar_ln};

    #atcG\n
    #Ccga\n
    #G and C should have different nbreaks
    $nbreak_start=&getNbreak($start,$nchar_ln);
    $nbreak_end=&getNbreak($end,$nchar_ln);

    #contig start	  position	line breaks
    $offset=$contig{$id}{offset}+($start-1) + $nbreak_start;

    $len= ($end-$start+1) + ($nbreak_end-$nbreak_start);

    seek IN,$offset,0;
    read IN,$return,$len;

    $return=~s/[\r\n]+//g;
    print ">$i\n";
    print "$return\n";
}

close IN;

###################SUBROUTINES##########################
sub readIdx
{
    my $fai=shift;
    my %return;
    open IN,"<",$fai or die "Failed to read $fai: $!\n";
    while (<IN>)
    {
	my @f=split /\t/;
	die "5 fields expected at line $. of $fai: $_\n" unless @f==5;
	my ($id,$len,$offset,$nchar_ln,$nbyte_ln)=@f;

	$return{$id}={
	    length=>$len, #length of contig
	    offset=>$offset, #offset where first character in that contig appears
	    nchar_ln=>$nchar_ln, #number of characters per line
	    nbyte_ln=>$nbyte_ln, #number of bytes per line
	};
    }
    close IN;
    return %return;
}
sub getNbreak
{
    my $nbreak;
    my ($start,$nchar_ln)=@_;
    if ($start % $nchar_ln == 0)
    {
	$nbreak=$start/$nchar_ln-1;
    } else
    {
	$nbreak=int($start/$nchar_ln);
    }
    return $nbreak;
}
