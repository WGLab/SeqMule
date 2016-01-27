After you have downloaded and installed SeqMule (assume in `seqmule` folder), this tutorial will tell you most important steps to get your analysis done.

## Example output

Click [here](http://www.openbioinformatics.org/seqmule/example/trio_report/summary.html) to see what output report looks like.

You can find an application example in my [poster](http://www.openbioinformatics.org/seqmule/SeqMule-ASHG-2012.pdf) at 2012 ASHG meeting.

## Quick start

### Step 1: Prepare database

Reference genome, index of reference genome, various SNP and INDEL databases are needed for alignment and variant calling. The following command will download all necessary files.

	seqmule download -down hg19all

### Step 2: Prepare input

Once external databases are downloaded. SeqMule is ready for analysis!  If you do not have data yet, please download the following example files:[normal_R1.fastq.gz](http://www.openbioinformatics.org/seqmule/example/normal_R1.fastq.gz),[normal_R2.fastq.gz](http://www.openbioinformatics.org/seqmule/example/normal_R2.fastq.gz).



### Step 3: Run pipeline

	seqmule pipeline -a normal_R1.fastq.gz -b normal_R2.fastq.gz -prefix example -N 2 -capture default -threads 4 -e 

`normal_R1.fastq.gz` and `normal_R2.fastq.gz` are the FASTQ files you get from a sequencer, in gzipped format. They contain reads and read qualities. Assuming you did paired-end sequencing, there are two files.  `-prefix example` tells SeqMule your sample name is `example`.  `-capture default` asks SeqMule to use default region definition file, which is hg19 exome region from Agilent SureSelect kit. `-threads 4` asks SeqMule to use 4 threads wherever possible.  Change it if you don't have 4 CPUs to use. `-e` means this data set is exome or captured sequencing data set (not whole genome data set). `-N 2` means at the end of analysis, SeqMule will extract variants shared by at least 2 sets of variants. The default analysis pipeline conists of BWA-MEM, GATKLite, FreeBayes and SAMtools, so 3 sets of variants will be generated: BWA+GATKLite, BWA+FreeBayes, BWA+SAMtools.

### Step 4: Check results

Wait until all executions are finished (approximately an hour). In the directory where you run your analysis, `example_report` contains a report in HTML format (webpage), `example_result` contains alignment results (in BAM format) and variants (in VCF format). Download the report folder as a whole to your computer, open `Summary.html` with any browser to view summary statistics about your analysis. We also provide a [report](http://www.openbioinformatics.org/seqmule/example/example_report/summary.html) from the same data set for comparison . The exact numbers may differ a little due to stochastic behavior of some algorithms.

## Common use cases

###Typical exome analysis

Scenario: I sequenced an exome (with four `FASTQ` files) by nimblegen v3 array, and I want to call the variants by BWA+GATK. Assume you have [downloaded](#Download all hg19 databases/`BED`s). Analyze the data by the following command:

	seqmule pipeline -a sample_lane1_R1.fq.gz,sample_lane2_R1.fq.gz -b sample_lane1_R2.fq.gz,sample_lane2_R2.fq.gz -capture seqmule/database/hg19nimblegen/hg19_nimblegen_SeqCap_exome_v3.bed -m -e -advanced seqmule/misc/predefined_config/bwa_gatk_HaplotypeCaller.config -quick -t 4 -prefix mySample

Explanations: `-quick` enables faster variant calling at the expense of higher memory usage; `-t 4` tells SeqMule to use 4 CPUs; `-e` for exome or captured sequencing analysis; `-m` for merging two sets of reads.

###Fast turnaround whole genome analysis

Scenario: I sequenced a genome with 30X and I need the variant ASAP. The combination of SNAP+FreeBayes is usually pretty fast. The following command uses this combination to perform analysis:

	seqmule pipeline -a sample_R1.fq.gz -b sample_R2.fq.gz -advanced seqmule/misc/predefined_config/snap_freebayes.config -quick -t 12 -g -prefix mySample

Explanations: `-g` for whole genome analysis; `-t 12` asks SeqMule to use 12 CPUs; `-quick` enables faster variant calling at the expense of higher memory usage. Note, SNAP is very memory-consuming, for best reliability, please make sure to have at least *32GB* memory. Reducing number of CPUs will decrease memory a little bit.

###Trio exome analysis

Scenario: I sequenced a family trio by exome and I want to find disease-causing (e.g. de novo) variants. I want to use SGE for this analysis.

	seqmule pipeline -a fa_R1.fq.gz,mo_R1.fq.gz,son_R1.fq.gz -b fa_R2.fq.gz,mo_R2.fq.gz,son_R2.fq.gz -ms -e -q -t 4 -prefix father,mother,son -capture default -sge "qsub -V -cwd -pe smp XCPUX

Explanations: `-e` for whole-exome or captured sequencing; `-ms` for multi-sample variant calling, which more accurate for a family trio than separate variant calling; `-capture default` tells SeqMule to use [default exome definition](/Miscellaneous/FAQ.md# How are default exome regions defined? Where do they come from?) for extracting variants; `-sge "qsub -V -cwd -pe smp XCPUX` tells SeqMule proper SGE commands and options for job submission, in particular, `XCPUX` is a special keyword reserved for SeqMule to specify number of CPUs for each job; `-q` enables faster variant calling at the expense of higher memory usage; `-prefix father,mother,son` specifies 3 prefixes for 3 sets of reads; `-t 4` asks SeqMule to use 4 CPUs. By default, the combination of BWA-MEM+FreeBayes+SAMtools+GATKLite will be used for analysis. A consensus VCF file (from 3 variant callers) will be generated at the end.
