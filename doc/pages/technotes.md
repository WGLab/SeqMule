-   [Home](../home.html)
-   [Install](installation.html)
-   [Tutorial](tutorial.html)
-   [Manual](manual.html)
-   [FAQ](faq.html)
-   [TechNotes](technotes.html)
-   [Example Report](example_report/summary.html)

\

\

SeqMule Technical Notes
=======================

### Small contigs in human genome {#q2}

Contigs like GL000192.1 will be treated the same way as chromomsome 1
and others since some genes are mapped to these contigs.

\

### Description of some files in misc {#q3}

db\_locations: database names, URLs, MD5 hash\
 advanced\_config: pipeline configuration template\
 exe\_locations: external program package download links\
 predefined\_config: folder containging pre-tested configuration files\

\

### CPUs for GATK genotyping {#q4}

Since Linux will limit number of files opened, sometimes GATK
UnifiedGenotyper will encounter problems. An easy solution is to
decrease CPUs used. I have set this option to a relatively safe number
based on my experience, users can change it by '-gatknt' option.

\

### Parallelization {#q5}

SeqMule can run scripts in a non-parallel or parallel (quick mode)
fashion. Some of its external programs can run themselves in parallel
mode, though. Under quick mode, SeqMule will go through all steps before
variant calling as in regular mode, then splits region of interest into
N pieces, where N is determined by the number of threads. Variant
calling is done separately for each piece. At last, all resulting VCF
files will be merged together.

\

### Output naming rules {#q6}

All output files specific to a particular sample should have a filename
beginning with 'samplename' (specified by -prefix) and no underscore
allowed in prefix. For BAM file input, the file name prefix remains the
same, unless '-merge' option is in effect.

\

### Multiple alignments {#q7}

SeqMule only outputs primary alignments because secondary alignments
really do not help too much for variant calling, and they make it more
difficult to calculate alignment statistics.

\
 \

Copyright 2014 [USC Wang Lab](http://genomics.usc.edu) | Designed by
[Free CSS Templates](http://www.templatemo.com)
