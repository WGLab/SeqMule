#!/usr/bin/env perl

use strict;
use warnings;
use File::Basename qw/basename/;

die "Usage: $0 <perl pod embeded program ...>\n" unless @ARGV>=1;
for my $i(@ARGV) {
    my $outfile = basename($i).".md";
    !system("pod2markdown $i > $outfile") or die "perldoc $i: $!\n";
    warn "$outfile done\n";
}
warn "All done\n";
