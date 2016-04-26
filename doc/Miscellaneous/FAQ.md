### I submitted a SeqMule job to SGE, it aborted without any error, what's wrong here?

One possible cause is that SeqMule exceeded the requested memory limit. How to troubleshoot? First, run `qacct -j JOBID` to identify job exit status. Make sure to replace `JOBID` with your actual job ID assigned by SGE. Then you will see something like this(assume `accounting_summary` to set to `TRUE`):

```
$ qacct -j 584552
==============================================================
qname        all.q
hostname     compute-0-3.local
group        wanglab
owner        user
project      NONE
department   defaultdepartment
jobname      STDIN
jobnumber    584552
taskid       undefined
account      sge
priority     0
qsub_time    Sat Jan 30 14:53:20 2016
start_time   Sat Jan 30 14:53:31 2016
end_time     Sat Jan 30 21:11:33 2016
granted_pe   smp
slots        12
failed       100 : assumedly after job
exit_status  137 #137-128=9, which is SIGKILL
ru_wallclock 22682
ru_utime     0.080
ru_stime     0.037
ru_maxrss    2760
ru_ixrss     0
ru_ismrss    0
ru_idrss     0
ru_isrss     0
ru_minflt    16265
ru_majflt    0
ru_nswap     0
ru_inblock   16
ru_oublock   32
ru_msgsnd    0
ru_msgrcv    0
ru_nsignals  0
ru_nvcsw     337
ru_nivcsw    62
cpu          66629.510
mem          338134.237
io           1547.102
iow          0.000
maxvmem      52.969G
arid         undefined
```
The line `exit_status` indicates that exit code is `137 - 128 = 9` which means `SIGKILL`. The line `maxvmem` tells us maximum memory used is `52.969G`, if we only asked for `4G` for each CPU, we were supposed to use only a total of `4G * 12 = 48G` memory. This explains why SGE killed our job without letting SeqMule complain. Under such circumstances, we can request more memory by adjusting `-l h_vmem` option in `qsub` command, for example we can change `-l h_vmem=4G` to `-l h_vmem=6G`. Alternatively, we can decrease SeqMule memory usage by changing `-jmem` option in `seqmule pipeline` command, for example, we can change `-jmem 1750m` (the default) to `-jmem 1024m`. **WARNING**: changing `-jmem` only works if GATK is using too much memory and may have a side effect of insufficient memory for GATK.

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

### After I finish seqmule analysis, I realized that I used a wrong capture file. How should I address this? Can I just manually change 'finished' to 'waiting' in that step (in the script file)?

Capture file is typically used in multiple stages of analysis (variant calling, stats calculation). Therefore it might not enough to change only one step of the analysis. One way you can try is that run `seqmule pipeline -norun` with the correct capture file, and then rerun analysis right after alignment `seqmule run -n X` (X stands for the step number after alignment). If you understand the script, you can modify the bed file name and rerun steps involving that file manually. Note however, right now it is not possible to rerun one particular step (unless that step is the last step) by `seqmule run`, SeqMule will run the script from a specified step (or resume where it stops) to the end.

### How to solve the `java.lang.NullPointerException` problem?

Some users may see the following error message with GATK or GATKLite:
```
##### ERROR ------------------------------------------------------------------------------------------
##### ERROR stack trace
    java.lang.ExceptionInInitializerError
    at org.broadinstitute.sting.gatk.GenomeAnalysisEngine.<init>(GenomeAnalysisEngine.java:160)
    at org.broadinstitute.sting.gatk.CommandLineExecutable.<init>(CommandLineExecutable.java:53)
    at org.broadinstitute.sting.gatk.CommandLineGATK.<init>(CommandLineGATK.java:54)
at org.broadinstitute.sting.gatk.CommandLineGATK.main(CommandLineGATK.java:90)
    Caused by: java.lang.NullPointerException
    at org.reflections.Reflections.scan(Reflections.java:220)
    at org.reflections.Reflections.scan(Reflections.java:166)
    at org.reflections.Reflections.<init>(Reflections.java:94)
at org.broadinstitute.sting.utils.classloader.PluginManager.<clinit>(PluginManager.java:77)
    ... 4 more
```
This error is likely to be caused by Java version incompatibility. Please make sure you are using Java 1.7 and put make it your default java program (put the folder containing java at the beginning of your PATH variable).

### How are default exome regions defined? Where do they come from?

The default exome defintions (to use them, specify `-capture default` with `seqmule pipeline` command) came from UCSC genome browser's RefSeq Gene track (refGene table). Only exons were included plus 5bp at each end of each region. The regions were sorted and further processed to only retain chromosomes 1 to 22, X and Y for hg18 and hg19 genome builds. Overlapping regions were merged. Exonic variants and splicing variants can therefore be included in the results. However, variants in UTR and other regions may not show up. If you want to restrict your analysis for a particular capture kit, please refer to `seqmule download -help` to download common region definitions or use your own `BED` file.

### How to solve `ERROR MESSAGE: Bad input: Error during negative model training. Minimum number of variants to use in training is larger than the whole call set. One can attempt to lower the --minNumBadVariants arugment but this is unsafe.` issue?

Here GATK is complaining about too few variants used in model training. This statistical model is used for VQSR (variant quality score recalibration). It is a better method for variant filtering. However, when your capture region is small (e.g. only a few genes), or your average depth is very low, the input might be not sufficient for model training. Hard filtering should be used instead. SeqMule has limited support for automatic hard filtering (when input `BAM` is smaller than 1GB for SNP, and 15GB for INDEL). The automatic detection is not guaranteed to work, so a safe option is to set `forceSNPHardFilter` or `forceINDELHardFilter` to 1 (in `advanced_config`) to enforce hard filtering. Note, there are a separate pair of such flags for each calling method of GATK, namely GATK UnifiedGenotype caller, GATK HaplotypeCaller and GATKLite UnifiedGenotype caller. They work independently.

### How much space is needed for SeqMule databases?

`hg19all` and `hg18all` EACH needs approximately 60GB of space after decompressing, which includes the reference genome, index files for BWA, Bowtie, Bowtie2, SNAP and SOAP, databases for GATK. However, because compressed files and decompressed files must co-exist during decompression, one may need another 30 to 40GB of space during download. Note, the space requirement just mentioned is only for database, your input data typically has over 10GB, 20GB or 100GB of sizes depending on your situation, and two times or three times of additional space (relative to raw data) is needed to store intermediate analysis files. If space is limited, one option is to only download hg19 and its index for bwa (`seqmule download -d hg19,hg19ibwa`), and disable GATK VQSR filtering (set `forceSNPHardFilter` to 1 in `advanced_config`) such that auxillary variant databases are not needed. Using the above option, SeqMule only needs about 10GB of space for databases.

### If I have to manually download all the databases due to unstable Internet connection, how should I place them in the `database/` folder?

The `database/` folder should have the following structure (for *hg19*) after unzipping:

```
database/
|-- 1000G_omni2.5.b36.vcf
|-- 1000G_omni2.5.b36.vcf.idx
|-- 1000G_omni2.5.b37.vcf
|-- 1000G_omni2.5.b37.vcf.idx
|-- bowtie
|   |-- human_g1k_v37.1.ebwt
|   |-- human_g1k_v37.2.ebwt
|   |-- human_g1k_v37.3.ebwt
|   |-- human_g1k_v37.4.ebwt
|   |-- human_g1k_v37.rev.1.ebwt
|   `-- human_g1k_v37.rev.2.ebwt
|-- bowtie2
|   |-- human_g1k_v37.1.bt2
|   |-- human_g1k_v37.2.bt2
|   |-- human_g1k_v37.3.bt2
|   |-- human_g1k_v37.4.bt2
|   |-- human_g1k_v37.rev.1.bt2
|   `-- human_g1k_v37.rev.2.bt2
|-- bwa
|   |-- human_g1k_v37.fasta -> /absolute_path_to/database/human_g1k_v37.fasta
|   |-- human_g1k_v37.fasta.amb
|   |-- human_g1k_v37.fasta.ann
|   |-- human_g1k_v37.fasta.bwt
|   |-- human_g1k_v37.fasta.fai
|   |-- human_g1k_v37.fasta.pac
|   `-- human_g1k_v37.fasta.sa
|-- dbsnp_hg18_138.vcf
|-- dbsnp_hg18_138.vcf.idx
|-- dbsnp_hg19_138.vcf
|-- dbsnp_hg19_138.vcf.idx
|-- hapmap_3.3.b36.vcf
|-- hapmap_3.3.b36.vcf.idx
|-- hapmap_3.3.b37.vcf
|-- hapmap_3.3.b37.vcf.idx
|-- human_b36_both.dict
|-- human_b36_both.fasta
|-- human_b36_both.fasta.fai
|-- human_g1k_v37.dict
|-- human_g1k_v37.fasta
|-- human_g1k_v37.fasta.fai
|-- Mills_and_1000G_gold_standard.indels.b36.vcf
|-- Mills_and_1000G_gold_standard.indels.b36.vcf.idx
|-- Mills_and_1000G_gold_standard.indels.b37.vcf
|-- Mills_and_1000G_gold_standard.indels.b37.vcf.idx
|-- snap
|   |-- human_g1k_v37.fasta
|   |   |-- Genome
|   |   |-- GenomeIndex
|   |   |-- GenomeIndexHash
|   |   `-- OverflowTable
`-- soap
    |-- human_g1k_v37.fasta.index.amb
    |-- human_g1k_v37.fasta.index.ann
    |-- human_g1k_v37.fasta.index.bwt
    |-- human_g1k_v37.fasta.index.fmv
    |-- human_g1k_v37.fasta.index.hot
    |-- human_g1k_v37.fasta.index.lkt
    |-- human_g1k_v37.fasta.index.pac
    |-- human_g1k_v37.fasta.index.rev.bwt
    |-- human_g1k_v37.fasta.index.rev.fmv
    |-- human_g1k_v37.fasta.index.rev.lkt
    |-- human_g1k_v37.fasta.index.rev.pac
    |-- human_g1k_v37.fasta.index.sa
    `-- human_g1k_v37.fasta.index.sai
```    

Copyright 2014 [USC Wang Lab](http://genomics.usc.edu)
