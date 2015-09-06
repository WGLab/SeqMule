### Database preparation 

SeqMule requires external databases to work. You can either use your own databases, or download default databases using the following commands.  Refer to manual of a specific tool to figure out what database exactly is needed. We recommend you use DEFAULT databases due to software compatibility issues. All databases will be downloaded to `seqmule/database` directory. Right now only human genome is supported.

The following commands download default databases to seqmule directory for hg19(GRch37) and hg18(GRch36) genome build, respecitvely. The default location for storing databases is `seqmule/database`.

	seqmule download -down hg19all
	seqmule download -down hg18all

All region definition (BED) files are also downloaded along with databases and saved inside individual folders with manufacture name.

### Use region definition (BED) file 

If you have downloaded region definition files for different capture kits, you can use them in your analysis. By default they are located inside `seqmule/database`. Find your region definition file according to manufacture and capture kit. Then use `-capture path_to_your_file` along with other options for pipeline command.  For example


	seqmule pipeline -a example.1.fq.gz -b example.2.fq.gz -prefix exomeData -capture seqmule/database/hg19agilent/hg19_SureSelect_Human_All_Exon_V5.bed -threads 4 -e

Each line in BED represents a region in your captured sequence.  Definition of BED format can be found on [UCSC genome browser.](http://genome.ucsc.edu/FAQ/FAQformat.html#format1)

### Extract shared variants 

When you use 1 aligner, 3 variant callers, 3 sets of variants will be generated at the end. When you use 2 aligners, 2 variant callers, 4 sets of variants will be generated at the end. By default, SeqMule will try to extract variants shared by all sets of variants at the end. You can change this behavior by `-N INT` option. Only variants shared by at least INT sets will be retained. For an example, see Step 3 in QUICK START.


### Change pipeline (change ADVANCED_CONFIG) 

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

### Whole genome analysis 

Change `-e` to `-g` in seqmule command. Consequently, SeqMule will use whole genome as the region definition for analysis.

### Multiple samples 

Suppose you have two samples, sampleA and sampleB, how to perform basic analysis? (`.fq` is the same thing as `.fastq`)

	seqmule pipeline -a sampleA.1.fq,sampleB.1.fq -b sampleA.2.fq,sampleB.2.fq -e -prefix sampleA,sampleB 

Basically you concatenate input files or sample names by commas. If you know your samples come from a single family, you can do multi-sample variant calling by simply adding `-ms` to the above command. It is believed that multi-sample calling could be more accurate.

### Analysis exit with error (resume stopped analysis) 

If your analysis exits due to errors. You can examine the runtime logging information (in output from SeqMule or `seqmule.*.logs` folder) to identify the error, then fix it by changing `advanced_config` or the command line, and at last resume the analysis. Commands are shown below.

	seqmule run your_analysis.script

This command will resume the analysis from where it stops.

	seqmule run -n 10 your_analysis.script

This command will run your analysis from step 10 regardless of what happened before.


### Generate Mendelian error statistics 

Assume you get a VCF with a family trio. The sample ID is `father` for father, `mother` for mother, `son` for offspring, respectively. To generate Mendelian error statistics (e.g. how many genotypes are impossible in son based on parents' genotypes), simply run the following command:

	seqmule stats -vcf sample.vcf --plink --mendel-stat --paternal father --maternal mother

The VCF file will be converted to PLINK format (PED and MAP) first, and then statistics is obtained. If not all your samples are in the same VCF, you need to combine them first, and the ID for each sample must be unique. Merging VCF can be done with `seqmule stats --u-vcf 1.vcf,2.vcf,3.vcf -p 123combo -ref hg19.fa`, where `123combo` is the prefix for the merged VCF.


### Call somatic variants

Calling somatic variants requires two sets of sequencing data, one from normal tissue, the other from tumor tissue. An example looks like this:

```
seqmule pipeline -ow -a normal_R1.fastq.gz -b normal_R2.fastq.gz -a2 tumor_R1.fastq.gz -b2 tumor_R2.fastq.gz -capture somatic_calling.bed -e -t 4 -rg PatientX -prefix PatientXsomatic -advanced ~/Downloads/SeqMule/misc/predefined_config/forSomatic_bwa_varscan.config
```

`-a`,`-b` specify two paired-end sequencing files ([normal_R1.fastq.gz](http://www.openbioinformatics.org/seqmule/example/normal_R1.fastq.gz), [normal_R2.fastq.gz](http://www.openbioinformatics.org/seqmule/example/normal_R2.fastq.gz)) from normal tissue; `-a2`,`-b2` specify two paired-end sequencing files ([tumor_R1.fastq.gz](http://www.openbioinformatics.org/seqmule/example/tumor_R1.fastq.gz), [tumor_R2.fastq.gz](http://www.openbioinformatics.org/seqmule/example/tumor_R2.fastq.gz)) from tumor tissue. [somatic_calling.bed](http://www.openbioinformatics.org/seqmule/example/somatic_calling.bed) defines the region of interest. Multiple samples are supported. You can use commas to separate them. Somatic variant calling is enabled for SAMtools and VarScan2 in SeqMule. In this example, *bwa+varscan* combination is used. Look into `predefined_config/` folder for more tested configuration files.

The analysis takes 20 minutes to finish on a machine with Xeon E5345 2.33GHz and 16GB memory using 4 threads. The result should look similar to what is reported [here](http://www.openbioinformatics.org/seqmule/example/PatientXsomatic_report/).

### Merging multiple runs from ONE sample

Say you have generated 4 runs of data for a sample X. Each run was done by paired-end sequencing, so there are 2 FASTQ files for each run, and 8 for sample X in total. How to analyze them with SeqMule?

```
seqmule pipeline -a x_run1.1.fq.gz,x_run2.1.fq.gz,x_run3.1.fq.gz,x_run4.1.fq.gz -b x_run1.2.fq.gz,x_run2.2.fq.gz,x_run3.2.fq.gz,x_run4.2.fq.gz -capture default -e -t 12 -prefix sampleX -merge -advanced ~/Downloads/SeqMule/misc/predefined_config/bwa_samtools.config
```

The above command specifies 8 input files. `x_run1.1.fq.gz` and `x_run1.2.fq.gz` are for first run of sample X, `x_run2.1.fq.gz` and `x_run2.2.fq.gz` are for second run. It is the same case for 3rd run and 4th run. `-merge` options asks SeqMule to merge all alignments of the same sample.


### Merging multiple runs from MULTIPLE samples

Say you have generated 2 runs for sample father, and 2 runs for sample mother. Each run was done by paired-end sequencing, so there are 2 FASTQ files for each run, and 4 for each sample. How to analyze them with SeqMule?

```
seqmule pipeline -a fa_run1.1.fq.gz,fa_run2.1.fq.gz,ma_run1.1.fq.gz,ma_run2.1.fq.gz -b fa_run1.2.fq.gz,fa_run2.2.fq.gz,ma_run1.2.fq.gz,ma_run2.2.fq.gz -capture default -e -t 12 -prefix father,mother -merge -mergingrule 2,2 -advanced ~/Downloads/SeqMule/misc/predefined_config/bwa_samtools.config
```

The above command specifies 8 input files which can be found [here](http://www.openbioinformatics.org/seqmule/example/). `fa_run1.1.fq.gz` and `fa_run1.2.fq.gz` are for first run of sample father, `fa_run2.1.fq.gz` and `fa_run2.2.fq.gz` are for second run of sample father. It is the same case for mother. `-merge` options asks SeqMule to merge all alignments of the same sample. `-mergingrule 2,2` means the first 2 pairs of input files are for the first sample, and the last 2 pairs of input files are for the second sample. If `-mergingrule` is not specified, SeqMule will assume numbers of input files for each sample are equal. This command can be modified to take only one sample (by removing `-mergingrule` option) or more than two samples (by adding more files and changing the string after `-mergingrule`). A report for the above multi-sample merging command is available [here](http://www.openbioinformatics.org/seqmule/example/multi-sample_merging_report/summary.html).

### Finetune pipeline (modify script) 

Each time you run `seqmule pipeline`, a script file *.script will be generated in your working directory. The prefix of this file is the same as the prefix for your output (it is also your sample name). An example script file is shown below.

````
[SETTING_SECTION]
CPUTOTAL=12
LOGDIR=/home/user/project/diseaseX/seqmule.09052015.2227.logs
STEPTOTAL=24
VERSION=1.2

[1]
JOBID=0
PID=2639
command=/home/user/usr/seqmule/SeqMule/bin/secondary/../../bin/secondary/worker /home/user/project/diseaseX/seqmule.09052015.2227.logs 1 "/home/user/usr/seqmule/SeqMule/bin/secondary/../../bin/secondary/phred64to33 test1_result/test1.0.fastq test1_result/test1.0_phred33.fastq"
dependency=
message=Convert phred64 to phred33
nCPU_requested=1
status=finished

[2]
JOBID=0
PID=2652
command=/home/user/usr/seqmule/SeqMule/bin/secondary/../../bin/secondary/worker /home/user/project/diseaseX/seqmule.09052015.2227.logs 2 "/home/user/usr/seqmule/SeqMule/bin/secondary/../../bin/secondary/phred64to33 test1_result/test1.1.fastq test1_result/test1.1_phred33.fastq"
dependency=
message=Convert phred64 to phred33
nCPU_requested=1
status=waiting

...
````
The script file is written by Perl `Config::Tiny` module. There is a `SETTING_SECTION` specifying global settings. Global settings include total number of CPU cores (`CPUTOTAL`), logging folder (`LOGDIR`), total number of steps (`STEPTOTAL`), and version number (`VERSION`). The remaining sections consist of steps. One step is a section. In each section, there are a few fields specifying job ID, process ID, etc. This script is not meant to be changed by users. If you really want to, only modify the `command` field. The string enclosed by double quotes is the actual command that will be executed. Most of the commands will not make sense to users, because many internal wrappers are used. Shell metacharacters <strong>*$><&?;|`</strong> are not allowed.


