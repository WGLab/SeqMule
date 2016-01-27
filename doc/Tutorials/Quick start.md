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
