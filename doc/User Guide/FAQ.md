### Is there a log file showing the runtime error? 

SeqMule only saves runtime parameters to `*.log` file. If you want to check the runtime output after running SeqMule in the background (or submitted to a cluster), please use `nohup your_seqmule_command > output.txt &`. `nohup` can run your command even after you log out. All messages that were printed on screen will be saved in `output.txt` file. Alternatively, you can append `2>stderr.txt` to your SeqMule command. The STDERR message (all error messages) will be saved in output.txt and stderr.txt, respectively. 

### Why did I get *set: Variable name must begin with a letter.* error when I tried to run the analysis script by qsub? 

SeqMule added `set -e` at the begining of script to make it exit at first error. If your job scheduling system (e.g. SGE) tries to execute the script by csh or tcsh, it will return the above error. Please use bash at qsub instead. For example, under SGE, you can use: 

	echo 'your_seqmule_command' | qsub -V -cwd -S /bin/bash -N sample

### How to solve GATK `ERROR MESSAGE: Unable to parse header with error: /tmp/org.broadinstitute.sting.gatk.io.stubs.VariantContextWriterStub116224981.tmp (Too many open files), for input source: /tmp/org.broadinstitute.sting.gatk.io.stubs.VariantContextWriterStub116224981.tmp`? 

This happens because Linux limits the number of files opened. The easiest way is to use `-gatknt` option in seqmule to specify a lower number of CPUs (eg 1 or 2) used for GATK genotyping. Another option is to request your system administer to increase the limit.

### Does SeqMule support merging of BAM files? 

Yes. Run `seqmule pipeline -m` with other arguments. In this case, all BAM files will be merged and therefore only one sample prefix is needed.

### What if GATK complains for insufficient memory? 

Please use `-jmem` option to give GATK more memory. Note, however, you have to request more memory than specified by `-jmem` if you run your analysis on a computation cluster as there is memory overhead for java virtual machine.

### How does the QUICK mode work? 

Under QUICK mode, total region to be called will be split into N parts.  N is the number of threads. Variant calling is then performed on each part simultaneously. Afterwards, the resulting VCF will be merged. For GATK, variant filtering is not done until after merging because VQSR filtering requires a lot of variants to calculate some statistics.

### Why are the numbers on Venn diagram different from the statistics I got from the consensus VCF file? 

Venn Diagram is plotted this way: ANNOVAR is used to convert VCF to AVINPUT; then for each variant, *chromosome+start+end+reference allele+observed allele* is used as an ID (alleles are not used for indels) to determine whether two variants overlap. Statistics for consensus result is calculated this way: GATK CombineVariants is used to extract consensus calls from multiple VCFs; if a VCF contains multiple samples, consensus extraction will be carried out on a per-sample basis; at last, VCFtools is used to calculate statistics for the resulting consensus VCF. Both the Venn Diagram and the statistics consist of two parts: SNV and indels. For SNV, the difference is very small (usually >0.5%). For indels, this is expected since there is no unique way to represent them in some cases. Besides, indels are intervalized (ignoring alleles) and extended by 10bp towards both ends for calculating statistics. Intervalization and extension are not done for obtaining consensus results as the alleles must be reported.

### What if `/tmp` is too small or I got error message `No space left on device`? 

You can specify a larger folder for storing temporary files. There are 2 ways to do this: first, set `$TMPDIR` in your environment variables; second, use `-tmpdir YOUR_TMP_DIRECTORY` option in `seqmule pipeline` or `seqmule stats` program.

Copyright 2014 [USC Wang Lab](http://genomics.usc.edu)
