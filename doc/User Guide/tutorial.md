-   [Home](../home.html)
-   [Install](installation.html)
-   [Tutorial](tutorial.html)
-   [Manual](manual.html)
-   [FAQ](faq.html)
-   [TechNotes](technotes.html)
-   [Example Report](example_report/summary.html)

\

\

Tutorial
--------

After you have downloaded and installed SeqMule (assume in **seqmule**
folder), this tutorial will tell you most important steps to get your
analysis done.

\

#### Didn't find what you want?

### EXAMPLE OUTPUT {#q7}

Click here to see what output report looks like. [Example
output](example_report/summary.html)

You can find an application example in my
[poster](../images/SeqMule-ASHG-2012.pdf) at 2012 ASHG meeting.

\
 \

### QUICK START {#q1}

#### Step 1: Prepare database

Reference genome, index of reference genome, various SNP and INDEL
databases are needed for alignment and variant calling. The following
command will download all necessary files.

\
`seqmule download -down hg19all` \

#### Step 2: Prepare input

Once external databases are downloaded. SeqMule is ready for analysis!
If you do not have data yet, please download the following example files
([example.1.fq.gz](../example/example.1.fq.gz),[example.2.fq.gz](../example/example.2.fq.gz)).

\

#### Step 3: Run pipeline

\

`     seqmule pipeline -a example.1.fq.gz -b example.2.fq.gz -prefix exomeData -N 2 -capture default -threads 4 -e     `

**example.1.fq.gz** and **example.2.fq.gz** are the FASTQ files you get
from a sequencer, in gzipped format. They contain reads and read
qualities. Assuming you did paired-end sequencing, there are two files.
**-prefix exomeData** tells SeqMule your sample name is 'exomeData'.
**-capture default** asks SeqMule to use default region definition
file.**-threads 4** asks SeqMule to use 4 threads wherever possible.
Change it if you don't have 4 CPUs to use. **-e** means this data set is
exome or captured sequencing data set (not whole genome data set). **-N
2** means at the end of analysis, SeqMule will extract variants shared
by at least 2 sets of variants (3 sets of variants will be generated
using default pipeline). The default analysis pipeline conists of
BWA-MEM, GATK, FreeBayes and SAMtools.

\

#### Step 4: Check results

Wait a few hours until all executions are finished. In the directory
where you run your analysis, **exomeData\_report** contains a report in
HTML format (webpage), **exomeData\_result** contains alignment results
(in BAM format) and variants (in VCF format). Download the report folder
as a whole to your computer, open **Summary.html** with any browser to
view summary statistics about your analysis. We also provide a report
from the same data set for comparison
([here](../misc/sample_exomeData_report.zip)). The exact numbers may
differ a little due to stochastic behavior of some algorithms.

\
 \
\

### DATABASE PREPARATION {#q2}

SeqMule requires external databases to work. You can either use your own
databases, or download default databases using the following commands.
Refer to manual of a specific tool to figure out what database exactly
is needed. We recommend you use DEFAULT databases due to software
compatibility issues. All databases will be downloaded to
**seqmule/database** directory. Right now only human genome is
supported.

\

The following commands download default databases to seqmule directory
for hg19(GRch37) and hg18(GRch36) genome build, respecitvely. The
default location for storing databases is **seqmule/database**.

\

`         seqmule download -down hg19all         seqmule download -down hg18all`
\

All region definition (BED) files are also downloaded along with
databases and saved inside individual folders with manufacture name.

\

### USE REGION DEFINITION (BED) FILE {#q3}

If you have downloaded region definition files for different capture
kits, you can use them in your analysis. By default they are located
inside **seqmule/database**. Find your region definition file according
to manufacture and capture kit. Then use **-capture
path\_to\_your\_file** along with other options for pipeline command.
For example

\

`         seqmule pipeline -a example.1.fq.gz -b example.2.fq.gz -prefix exomeData -capture seqmule/database/hg19agilent/hg19_SureSelect_Human_All_Exon_V5.bed -threads 4 -e     `

Each line in BED represents a region in your captured sequence.
Definition of BED format can be found on [UCSC genome
browser.](http://genome.ucsc.edu/FAQ/FAQformat.html#format1)

\

### EXTRACT SHARED VARIANTS {#qusageofN}

When you use 1 aligner, 3 variant callers, 3 sets of variants will be
generated at the end. When you use 2 aligners, 2 variant callers, 4 sets
of variants will be generated at the end. By default, SeqMule will try
to extract variants shared by all sets of variants at the end. You can
change this behavior by **-N INT** option. Only variants shared by at
least INT sets will be retained. For an example, see Step 3 in [QUICK
START](#q7).

\

### CHANGE PIPELINE (CHANGE advanced\_config) {#q4}

If you want to change the default pipeline:

`         seqmule pipeline -advanced     `

This will generate a copy of 'advanced\_config'. This configuration file
specifies every step of the pipeline. If you want to add or remove a
program from the pipeline, just navigate to that line, change the bit
'0' or '1' after the equal sign (=). For example, if you want to use
bowtie2 instead of bwa-mem for alignment, change the following lines:

\
 `         2P_bwamem=1         2P_bowtie2=0     `

To:

`         2P_bwamem=0         2P_bowtie2=1     `

Some lines between them are not shown here. Comments begin with '\#',
they have no effects on other parts of the file. Read the comments at
the beginning of file for detailed instructions on how to modify it.

After you have modified the 'advanced\_config' file, you can use it by
append **-advanced advanced\_config** to your analysis command.

`         seqmule pipeline -a 1.fastq -b 2.fastq -prefix exomeData -capture default -threads 4 -e -advanced advanced_config     `

Some users maybe don't know how to edit a file on Linux if they don't
have graphics user interface (GUI). The easiest way is download it to
your PC, change it with NotePad, upload it. Alternatively, you can refer
to a [VIM
tutorial](https://www.math.northwestern.edu/resources/computer_information/vimtutor).

\

### WHOLE GENOME ANALYSIS {#q5}

\

Change **-e** to **-g** in seqmule command.

\

### MULTIPLE SAMPLES {#q6}

\

Suppose you have two samples, sampleA and sampleB, how to perform basic
analysis? (**.fq** is the same thing as **.fastq**)

`         seqmule pipeline -a sampleA.1.fq,sampleB.1.fq -b sampleA.2.fq,sampleB.2.fq -e -prefix sampleA,sampleB     `

Basically you concatenate input files or sample names by commas. If you
know your samples come from a single family, you can do multi-sample
variant calling by simply adding **-ms** to the above command. It is
believed that multi-sample calling could be more accurate.

\

### SAVE RUNTIME LOGGING INFO {#q10}

Please refer to the [FAQ](http://seqmule.usc.edu/pages/faq.html#q1)
page.

\

### ANALYSIS EXIT WITH ERROR (CONTINUE STOPPED ANALYSIS) {#qAEWE201406090432}

If your analysis exits erroneously. You can examine the runtime logging
information ([how to get it?](http://seqmule.usc.edu/pages/faq.html#q1))
to identify the error, then fix it by [changing advanced\_config](#q4)
or [the script](#q9), and at last continue the analysis. Commands are
shown below.

`seqmule run your_analysis.script`\

This command will resume the analysis.

`seqmule run -n 10 your_analysis.script`\

This command will run your analysis from step 10.

\

### FINETUNE PIPELINE (MODIFY SCRIPT) {#q9}

Each time you run 'seqmule pipeline', a script file \*.script will be
generated in your working directory. The prefix of this file is the same
as the prefix for your output (it is also your sample name). An example
script file is shown below.

    #step   command message nCPU_requested  nCPU_total  status  pid
    1   seqmule/bin/secondary/mod_status father-mother-son.script 1 seqmule/bin/secondary/phred64to33 father_result/father.1.fastq mother_result/mother.1.fastq son_result/son.1.fastq father_result/father.1_phred33.fastq mother_result/mother.1_phred33.fastq son_result/son.1_phred33.fastq Convert phred64 to phred33  8   8   finished    31171
    2   seqmule/bin/secondary/mod_status father-mother-son.script 2 seqmule/bin/secondary/phred64to33 father_result/father.2.fastq mother_result/mother.2.fastq son_result/son.2.fastq father_result/father.2_phred33.fastq mother_result/mother.2_phred33.fastq son_result/son.2_phred33.fastq Convert phred64 to phred33  8   8   finished    526
    3   seqmule/bin/secondary/mod_status father-mother-son.script 3 seqmule/exe/fastqc/fastqc --extract -t 8 father_result/father.1_phred33.fastq mother_result/mother.1_phred33.fastq son_result/son.1_phred33.fastq father_result/father.2_phred33.fastq mother_result/mother.2_phred33.fastq son_result/son.2_phred33.fastq  QC assesment on FASTQ files 8   8   finished    2438
        

Every line consists of some tab-delimited fields, the column name is
shown on the first line. Any line that is blank or begins with '**\#**'
will be ignored. The 1st field shows the step number. 2nd shows the
exact command for each step. Second last column shows the status of this
step, it can be '**finished**', '**waiting**', '**started**' or
'**error**'. The 2nd field begins with '**mod\_status
your\_analysis.script step\_no**', where **mod\_status** is an internal
program handling this script. This begining part has nothing to do with
analysis itself, so no need to change it. Only change commands after it.

This script is not meant to be changed by users. If you really want to,
modify the 2nd field **ONLY**. Do **NOT** add or remove any tabs. You
are free to add any number of spaces, though. Shell metacharacters
(\*\$\>\<&?;|\`) are not allowed.

Most of the commands in this script will not make sense to users,
because many internal wrappers are used. The only kind of commands
recommended for modification is a command involving SeqMule's explicit
programs (e.g. **stats**).

\

### GENERATE MENDELIAN ERROR STATISTICS {#q10}

Assume you get a VCF with a family trio. The sample ID is 'father' for
father, 'mother' for mother, 'son' for offspring, respectively. To
generate Mendelian error statistics (e.g. how many genotypes are
impossible in son based on parents' genotypes), simply run the following
command:
`seqmule stats -vcf sample.vcf --plink --mendel-stat --paternal father --maternal mother`
The VCF file will be converted to PLINK format (PED and MAP) first, and
then statistics is obtained.

\

If not all your samples are in the same VCF, you need to combine them
first, and the ID for each sample must be unique. Merging VCF can be
done with 'seqmule stats --u-vcf 1.vcf,2.vcf,3.vcf -p 123combo -ref
hg19.fa', where '123combo' is the prefix for the merged VCF.

\

### CAVEAT {#q_caveat}

NOT all combinations of alingers and variant callers work. For example,
SOAPaligner and SOAPsnp don't support SAM, BAM formats natively, so they
don't work well with the rest of algorithms. Also, bowtie doesn't report
mapping quality, so it shouldn't be used with GATK. For combinations we
have tested, please use predefined configuration files under
**seqmule/misc/predefined\_config** folder.\

\

Copyright 2014 [USC Wang Lab](http://genomics.usc.edu) | Designed by
[Free CSS Templates](http://www.templatemo.com)