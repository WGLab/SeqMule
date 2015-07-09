#!/usr/bin/env perl

use strict;
use warnings;

my $mapQ = shift @ARGV;
while(<>) {
    print and next if /^@/;
    chomp;
    my @f=split /\t/;
    if ($mapQ>$f[4]) {
	$f[1]=$f[1]+4 unless $f[1] & 0x4;
    }
    print join("\t",@f),"\n";
}
