### Small contigs in human genome 

Contigs like GL000192.1 will be treated the same way as chromomsome 1 and others since some genes are mapped to these contigs.

### Description of some files in misc 

*db_locations: database names, URLs, MD5 hash
*advanced_config: pipeline configuration template
*exe_locations: external program package download links
*predefined_config: folder containging pre-tested configuration files

### CPUs for GATK genotyping 

Since Linux will limit number of files opened, sometimes GATK UnifiedGenotyper will encounter problems. An easy solution is to decrease CPUs used. I have set this option to a relatively safe number based on my experience, users can change it by `-gatknt` option.

### Parallelization 

SeqMule runs the script in a parallel fashion. Some of its external programs, e.g. BWA, BOWTIE, can run themselves in parallel mode, while others will be run in parallel within SeqMule's framework. Under quick mode, SeqMule will go through all steps before variant calling as in regular mode, then splits region of interest into N pieces, where N is determined by the number of threads. Variant calling is done independently for each piece. At last, all resulting VCF files will be merged together.

### Output naming rules 

All output files specific to a particular sample should have a filename beginning with `samplename` (specified by -prefix) and no underscore allowed in prefix. For BAM file input, the file name prefix remains the same, unless `-merge` option is in effect.

### Multiple alignments 

SeqMule only outputs primary alignments because secondary alignments really do not help too much for variant calling, and they make it more difficult to calculate alignment statistics.

### Variant quality and genotype in VCF merging
When multiple VCFs from different variant callers are merged, variant quality and genotype quality from the first input file will appear in the combined VCF. The files to be merged will be sorted based on the following priority: GATK>SAMtools>FreeBayes>VarScan>SOAPsnp . We assign variants ‘PASS’ in the filter field only if they are unfiltered in any one of the input VCF files.

Copyright 2014 [USC Wang Lab](http://genomics.usc.edu) 
