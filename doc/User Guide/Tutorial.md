#Tutorial

After you have downloaded and installed SeqMule (assume in `seqmule` folder), this tutorial will tell you most important steps to get your analysis done.

### EXAMPLE OUTPUT 

Click [here](http://seqmule.usc.edu/example/trio_report/summary.html) to see what output report looks like.

You can find an application example in my [poster](../misc/SeqMule-ASHG-2012.pdf) at 2012 ASHG meeting.

### QUICK START 

#### Step 1: Prepare database

Reference genome, index of reference genome, various SNP and INDEL databases are needed for alignment and variant calling. The following command will download all necessary files.

	seqmule download -down hg19all

#### Step 2: Prepare input

Once external databases are downloaded. SeqMule is ready for analysis!  If you do not have data yet, please download the following example files:[normal_R1.fastq.gz](http://seqmule.usc.edu/example/normal_R1.fastq.gz),[normal_R2.fastq.gz](http://seqmule.usc.edu/example/normal_R2.fastq.gz).



#### Step 3: Run pipeline

	seqmule pipeline -a normal_R1.fastq.gz -b normal_R2.fastq.gz -prefix example -N 2 -capture default -threads 4 -e 

`normal_R1.fastq.gz` and `normal_R2.fastq.gz` are the FASTQ files you get from a sequencer, in gzipped format. They contain reads and read qualities. Assuming you did paired-end sequencing, there are two files.  `-prefix example` tells SeqMule your sample name is `example`.  `-capture default` asks SeqMule to use default region definition file, which is hg19 exome region from Agilent SureSelect kit. `-threads 4` asks SeqMule to use 4 threads wherever possible.  Change it if you don't have 4 CPUs to use. `-e` means this data set is exome or captured sequencing data set (not whole genome data set). `-N 2` means at the end of analysis, SeqMule will extract variants shared by at least 2 sets of variants. The default analysis pipeline conists of BWA-MEM, GATKLite, FreeBayes and SAMtools, so 3 sets of variants will be generated: BWA+GATKLite, BWA+FreeBayes, BWA+SAMtools.

#### Step 4: Check results

Wait until all executions are finished (approximately an hour). In the directory where you run your analysis, `example_report` contains a report in HTML format (webpage), `example_result` contains alignment results (in BAM format) and variants (in VCF format). Download the report folder as a whole to your computer, open `Summary.html` with any browser to view summary statistics about your analysis. We also provide a [report](http://seqmule.usc.edu/example/example_report/) from the same data set for comparison . The exact numbers may differ a little due to stochastic behavior of some algorithms.

### DATABASE PREPARATION 

SeqMule requires external databases to work. You can either use your own databases, or download default databases using the following commands.  Refer to manual of a specific tool to figure out what database exactly is needed. We recommend you use DEFAULT databases due to software compatibility issues. All databases will be downloaded to `seqmule/database` directory. Right now only human genome is supported.

The following commands download default databases to seqmule directory for hg19(GRch37) and hg18(GRch36) genome build, respecitvely. The default location for storing databases is `seqmule/database`.

	seqmule download -down hg19all
	seqmule download -down hg18all

All region definition (BED) files are also downloaded along with databases and saved inside individual folders with manufacture name.

### USE REGION DEFINITION (BED) FILE 

If you have downloaded region definition files for different capture kits, you can use them in your analysis. By default they are located inside `seqmule/database`. Find your region definition file according to manufacture and capture kit. Then use `-capture path_to_your_file` along with other options for pipeline command.  For example



	seqmule pipeline -a example.1.fq.gz -b example.2.fq.gz -prefix exomeData -capture seqmule/database/hg19agilent/hg19_SureSelect_Human_All_Exon_V5.bed -threads 4 -e

Each line in BED represents a region in your captured sequence.  Definition of BED format can be found on [UCSC genome browser.](http://genome.ucsc.edu/FAQ/FAQformat.html#format1)

### EXTRACT SHARED VARIANTS 

When you use 1 aligner, 3 variant callers, 3 sets of variants will be generated at the end. When you use 2 aligners, 2 variant callers, 4 sets of variants will be generated at the end. By default, SeqMule will try to extract variants shared by all sets of variants at the end. You can change this behavior by `-N INT` option. Only variants shared by at least INT sets will be retained. For an example, see Step 3 in QUICK START.


### CHANGE PIPELINE (CHANGE advanced_config) 

If you want to change the default pipeline:

	seqmule pipeline -advanced

This will generate a copy of `advanced_config`. This configuration file specifies every step of the pipeline. If you want to add or remove a program from the pipeline, just navigate to that line, change the bit `0` or `1` after the equal sign `=`. For example, if you want to use bowtie2 instead of bwa-mem for alignment, change the following lines:

	2P_bwamem=1         2P_bowtie2=0

To:

	2P_bwamem=0         2P_bowtie2=1

Some lines between them are not shown here. Comments begin with `#`, they have no effects on other parts of the file. Read the comments at the beginning of file for detailed instructions on how to modify it.

After you have modified the `advanced_config` file, you can use it by append `-advanced advanced_config` to your analysis command.

	seqmule pipeline -a 1.fastq -b 2.fastq -prefix exomeData -capture default -threads 4 -e -advanced advanced_config

Some users maybe don't know how to edit a file on Linux if they don't have graphics user interface (GUI). The easiest way is download it to your PC, change it with NotePad, upload it. Alternatively, you can refer to a [VIM tutorial](https://www.math.northwestern.edu/resources/computer_information/vimtutor).

### WHOLE GENOME ANALYSIS 

Change `-e` to `-g` in seqmule command.

### MULTIPLE SAMPLES 

Suppose you have two samples, sampleA and sampleB, how to perform basic analysis? (`.fq` is the same thing as `.fastq`)

	seqmule pipeline -a sampleA.1.fq,sampleB.1.fq -b sampleA.2.fq,sampleB.2.fq -e -prefix sampleA,sampleB 

Basically you concatenate input files or sample names by commas. If you know your samples come from a single family, you can do multi-sample variant calling by simply adding `-ms` to the above command. It is believed that multi-sample calling could be more accurate.

### ANALYSIS EXIT WITH ERROR (CONTINUE STOPPED ANALYSIS) 

If your analysis exits erroneously. You can examine the runtime logging information to identify the error, then fix it by changing `advanced_config` or the script, and at last continue the analysis. Commands are shown below.

	seqmule run your_analysis.script

This command will resume the analysis.

	seqmule run -n 10 your_analysis.script

This command will run your analysis from step 10.

### FINETUNE PIPELINE (MODIFY SCRIPT) 

Each time you run `seqmule pipeline`, a script file *.script will be generated in your working directory. The prefix of this file is the same as the prefix for your output (it is also your sample name). An example script file is shown below.

````
    #step   command message nCPU_requested  nCPU_total  status  pid
    1   seqmule/bin/secondary/mod_status father-mother-son.script 1 seqmule/bin/secondary/phred64to33 father_result/father.1.fastq mother_result/mother.1.fastq son_result/son.1.fastq father_result/father.1_phred33.fastq mother_result/mother.1_phred33.fastq son_result/son.1_phred33.fastq Convert phred64 to phred33  8   8   finished    31171
    2   seqmule/bin/secondary/mod_status father-mother-son.script 2 seqmule/bin/secondary/phred64to33 father_result/father.2.fastq mother_result/mother.2.fastq son_result/son.2.fastq father_result/father.2_phred33.fastq mother_result/mother.2_phred33.fastq son_result/son.2_phred33.fastq Convert phred64 to phred33  8   8   finished    526
    3   seqmule/bin/secondary/mod_status father-mother-son.script 3 seqmule/exe/fastqc/fastqc --extract -t 8 father_result/father.1_phred33.fastq mother_result/mother.1_phred33.fastq son_result/son.1_phred33.fastq father_result/father.2_phred33.fastq mother_result/mother.2_phred33.fastq son_result/son.2_phred33.fastq  QC assesment on FASTQ files 8   8   finished    2438
````
Every line consists of some tab-delimited fields, the column name is shown on the first line. Any line that is blank or begins with `#` will be ignored. The 1st field shows the step number. 2nd shows the exact command for each step. Second last column shows the status of this step, it can be `finished`, `waiting`, `started` or `error`. The 2nd field begins with `mod_status your_analysis.script step_no`, where `mod_status` is an internal program handling this script. This begining part has nothing to do with analysis itself, so no need to change it. Only change commands after it.

This script is not meant to be changed by users. If you really want to, modify the 2nd field `ONLY`. Do `NOT` add or remove any tabs. You are free to add any number of spaces, though. Shell metacharacters <strong>*$><&?;|`</strong> are not allowed.

Most of the commands in this script will not make sense to users, because many internal wrappers are used. The only kind of commands recommended for modification is a command involving SeqMules explicit programs (e.g. `stats`).

### GENERATE MENDELIAN ERROR STATISTICS 

Assume you get a VCF with a family trio. The sample ID is `father` for father, `mother` for mother, `son` for offspring, respectively. To generate Mendelian error statistics (e.g. how many genotypes are impossible in son based on parents' genotypes), simply run the following command:

	seqmule stats -vcf sample.vcf --plink --mendel-stat --paternal father --maternal mother

The VCF file will be converted to PLINK format (PED and MAP) first, and then statistics is obtained. If not all your samples are in the same VCF, you need to combine them first, and the ID for each sample must be unique. Merging VCF can be done with `seqmule stats --u-vcf 1.vcf,2.vcf,3.vcf -p 123combo -ref hg19.fa`, where `123combo` is the prefix for the merged VCF.

### RUNNING SEQMULE WITH SGE

SGE stands for Sun Grid Engine. SGE is a popular resource management system in computation cluster environment. SeqMule normally achieves multiprocessing by forking child process to execute commands. With SGE, SeqMule will submit tasks to the system and waits for them to finish. The `-threads` option controls total number of CPUs requested at any given time when it is used with `-sge` option. An example command looks like the following:

```
seqmule pipeline -ow -prefix sample -a sample.1.fastq.gz -b sample.2.fastq.gz -e -capture default -t 4 -jmem 1750m --advanced seqmule/predefined_config/bowtie2_gatk.config -sge "qsub -V -cwd -pe smp XCPUX" --nodeCapacity 4
```

Here, the double quoted string following `-sge` is a template for job submission. `XCPUX` is a keyword that will be replaced by actual number of CPUs needed for each task. SeqMule has to be run on a submission node. Do NOT specify `-e`,`-o`,`-S` options in the template as SeqMule will do it for you. SeqMule adds `-S /bin/bash` for all tasks. You can specify other options like queue name, memory request, email address in the template. Because some programs require lots of memory, you may want to try different arguments for `-jmem`, `-threads` and request larger amount of memory in the template in case you are not sure. `--nodeCapacity` tells SeqMule maximum number of threads to run on a single node, usually this is just the number of CPU cores on your compute node.

### RUNNING IN THE CLOUD (under construction)

With increasing popularity of cloud computing, more users may want to run large computational jobs in the cloud. SeqMule now can be deployed in the cloud via a program called *StarCluster*. Steps to run in the cloud:

+ Install [StarCluster](http://star.mit.edu/cluster/docs/latest/quickstart.html)
+ Start SeqMule-customized AMI (Amazon Machine Image) via StarCluster
+ Log into the virtual cluster and run SeqMule

### CALL SOMATIC VARIANTS

Calling somatic variants requires two sets of sequencing data, one from normal tissue, the other from tumor tissue. An example looks like this:

```
seqmule pipeline -ow -a normal_R1.fastq.gz -b normal_R2.fastq.gz -a2 tumor_R1.fastq.gz -b2 tumor_R2.fastq.gz -capture somatic_calling.bed -e -t 4 -rg PatientX -prefix PatientXsomatic -advanced ~/Downloads/SeqMule/misc/predefined_config/forSomatic_bwa_varscan.config
```

`-a`,`-b` specify two paired-end sequencing files ([normal_R1.fastq.gz](http://seqmule.usc.edu/example/normal_R1.fastq.gz), [normal_R2.fastq.gz](http://seqmule.usc.edu/example/normal_R2.fastq.gz)) from normal tissue; `-a2`,`-b2` specify two paired-end sequencing files ([tumor_R1.fastq.gz](http://seqmule.usc.edu/example/tumor_R1.fastq.gz), [tumor_R2.fastq.gz](http://seqmule.usc.edu/example/tumor_R2.fastq.gz)) from tumor tissue. [somatic_calling.bed](http://seqmule.usc.edu/example/somatic_calling.bed) defines the region of interest. Multiple samples are supported. You can use commas to separate them. Somatic variant calling is enabled for SAMtools and VarScan2 in SeqMule. In this example, *bwa+varscan* combination is used. Look into `predefined_config/` folder for more tested configuration files.

The analysis takes 20 minutes to finish on a machine with Xeon E5345 2.33GHz and 16GB memory using 4 threads. The result should look similar to what is reported [here](http://seqmule.usc.edu/example/PatientXsomatic_report/).

### MERGING MULTIPLE RUNS FROM MULTIPLE SAMPLES

Say you have generated 2 runs for sample father, and 2 runs for sample mother. Each run was done by paired-end sequencing, so there are 2 FASTQ files for each run, and 4 for each sample. How to analyze them with SeqMule?

```
seqmule pipeline -a fa_run1.1.fq.gz,fa_run2.1.fq.gz,ma_run1.1.fq.gz,ma_run2.1.fq.gz -b fa_run1.2.fq.gz,fa_run2.2.fq.gz,ma_run1.2.fq.gz,ma_run2.2.fq.gz -capture default -e -t 12 -prefix father,mother -merge -mergingrule 2,2 -advanced ~/Downloads/SeqMule/misc/predefined_config/bwa_samtools.config
```

The above command specifies 8 input files which can be found [here](http://seqmule.usc.edu/example/). `fa_run1.1.fq.gz` and `fa_run1.2.fq.gz` are for first run of sample father, `fa_run2.1.fq.gz` and `fa_run2.2.fq.gz` are for second run of sample father. It is the same case for mother. `-merge` options asks SeqMule to merge all alignments of the same sample. `-mergingrule 2,2` means the first 2 pairs of input files are for the first sample, and the last 2 pairs of input files are for the second sample. If `-mergingrule` is not specified, SeqMule will assume numbers of input files for each sample are equal. This command can be modified to take only one sample (by removing `-mergingrule` option) or more than two samples (by adding more files and chaging the string after `-mergingrule`). A report for the above multi-sample merging command is available [here](http://seqmule.usc.edu/example/multi-sample_merging_report/summary.html).

### CAVEAT 

NOT all combinations of alingers and variant callers work. For example, SOAPaligner and SOAPsnp don't support SAM, BAM formats natively, so they don't work well with the rest of algorithms. Also, bowtie doesn't report mapping quality, so it shouldn't be used with GATK. For combinations we have tested, please use predefined configuration files under `seqmule/misc/predefined_config` folder.

Copyright 2014 [USC Wang Lab](http://genomics.usc.edu) 
