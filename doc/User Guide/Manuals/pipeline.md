# NAME

seqmule-pipeline generates an analysis script based on options and/or advanced configuration.

# SYNOPSIS

        seqmule pipeline <options>

# DESCRIPTION

This command takes FASTQ/BAM files, various options and an optional advanced configuration file as input and generates a script file containing a set of commands, along with their resource requirements and dependencies. The script will then be given to seqmule-run for execution unless otherwise directed.

# OPTIONS

        --prefix,-p               comma-delimited list of sample names, will be used for output file naming.
                                  Mandatory for FASTQ input or BAM input with merge enabled.

        -a <FASTQ>                1st FASTQ file (or comma-delimited list)
        -b <FASTQ>                2nd FASTQ file (or comma-delimited list)
        --bam <BAM>               BAM file (or comma-delimited list). Exclusive of -a,-b options.
        -a2 <FASTQ>               1st FASTQ file (or comma-delimited list) from tumor tissue.
        -b2 <FASTQ>               2nd FASTQ file (or comma-delimited list) from tumor tissue.
        --bam2 <BAM>              BAM file (or comma-delimited list) from tumor tissue. Exclusive of FASTQ input.

        --merge,-m                merge FASTQ or BAM files before analysis
        --mergingrule <TEXT>      comma-delimited numbers for how many files merged for each sample.
                                  Default: equal number of files for each samples.
        -ms                       do multiple-sample variant calling (only valid for GATK,VarScan and SAMtools)

        -N <INT>                  if more than one set of variants are generated, extract variants shared by at least INT VCF output
        --build <hg18,hg19>       genome build. Default is hg19.
        --readgroup,-rg <TEXT>    readgroup ID. Specify one ID for all input or a comma-separated list. Default: READGROUP_[SAMPLE NAME]
        --platform,-pl <TEXT>     sequencing platform, only Illumina and IonTorrent are supported. Specify one platform for all input or a comma-separated list. Only for FASTQ input. Default: ILLUMINA.
        --library,-lb <TEXT>      sequencing library. Specify one library for all input or a comma-separated list. Only for FASTQ input. Default: LIBRARY.
        --forceOneRG              force use of one readgroup ID for BAM when merging is enabled. See details.
        --unionRG                 When merging BAM files, combine reads with same readgroup ID, keep reads with different readgroup IDs intact.
        --phred <1,33,64>         Phred score scheme. 1 is default, for auto-detection. Has no effect on BAM input.
        --wes,-e                  the input is captured sequencing data
        --wgs,-g                  the input is whole-genome sequencing data
        --capture <BED>           calculate coverage stats and extract (or call) variants over the regions defined by this file. If you do not have a custom BED file, use '-capture default' to use default BED file.
        --no-resolve-conflict     seqmule will NOT try to resolve any conflict among BED, BAM and reference. Run 'seqmule pipeline -h' for details.
        --no-check-chr            skip checking chromosome consistency. By default, SeqMule forces chromosomes in input to be consistent with builtin reference.
        --threads,-t <INT>        number of threads, also effective for -sge. Default: 1.
        --sge <TEXT>              run each command via Sun Grid Engine. A template with XCPUX keyword required. See examples.
        --nodeCapacity,-nc <INT>  max number of processes/threads for a single node/host. Default: unlimited.
        --quick,-q                enable parallel processing at variant calling
        --jmem <STRING>           max memory used for java virtual machine. Default: 1750m.
        --jexe <STRING>           Java executable path. Default: java
        --gatknt <INT>            number of threads for GATK. Prevent GATK from opening too many files. Default: 2.
        --advanced [FILE]         generate or use an advanced configuration file
        --tmpdir <DIR>            use DIR for storing large temporary files. Default: $TMPDIR(in your ENV variables) or /tmp
        --norun,-nr               do NOT run analysis, only generate script
        --nostat,-ns              do NOT generate statistics
        --norm                    do NOT remove intermediate SAM, BAM and other files
        --forceRmDup              force removal of duplicates. This overrides default behavior which disables duplicate removal for small capture regions.
        --overWrite,-ow           overwrite files whose names conflict with current analysis.

        --ref <FILE>              reference genome. Override default database (the following is the same). 
                                  When you use custom databases, make sure they are compatible with each other.
        --index <PREFIX>          prefix for bowtie, bowtie2, soap index files. Including path.
        --bowtie <PREFIX>         prefix ONLY for bowtie index files, including path
        --bowtie2 <PREFIX>        prefix only for bowtie2 index files, including path
        --soap <PREFIX>           prefix only for soap index files, including path
        --hapmap <FILE>           HapMap VCF file for variant quality recalibration
        --dbsnp <FILE>            dbSNP VCF file for variant quality recalibration
        --dbsnpver,-dv <INT>      dbSNP version for variant quality recalibration. By default, it's 138.
        --kg <FILE>               1000 genome project VCF file for variant quality recalibration
        --indel <FILE>            Indel VCF file for GATK realignment and VQSR

        --verbose,-v              verbose output
        --help,-h                 show this message

# EXAMPLES

        #generate a copy of 'advanced_config' for modification. You can find some predefined configurations under 'seqmule/misc/predefined_config' folder.
        seqmule pipeline -advanced

        #run analysis using custom advanced configuration on captured sequencing data. 1.fastq is raw data for first reads in paired-end sequencing, and 2.fastq is for second reads. Number of CPUs is 12, @RG tag is 'READGROUP' plus your sample name which is specified by -prefix. all output files have prefix 'exomeData' followed by an underscore. An html report will be generated automatically using default BED file(from SureSelect manufacturer).
        seqmule pipeline -a 1.fastq -b 2.fastq -prefix exomeData -threads 12 -rg READGROUP -e -advanced advanced_config -capture default

        #same as above, except that coverage stats will be calculated using custom BED file
        seqmule pipeline -a 1.fastq -b 2.fastq -prefix exomeData -threads 12 -rg READGROUP -e -advanced advanced_config -capture region.bed

        #same as above except that the data comes from whole-genome sequencing.
        seqmule pipeline -a 1.fastq -b 2.fastq -prefix genomeData -threads 12 -rg READGROUP -g -advanced advanced_config

        #same as above except that no report webpage will be generated
        seqmule pipeline -a 1.fastq -b 2.fastq -prefix genomeData -threads 12 -rg READGROUP -g -advanced advanced_config -nostat

        #Input is multi-sample, paired-end exome or other captured sequencing data, output files have 'sampleA' prefix for sampleA.1.fq and sampleA.2.fq, and 'sampleB' for sampleB.1.fq and sampleB.2.fq. FQ is just abbreviation for FASTQ. Without custom advanced_config, default pipeline 'bwa+gatk+samtools' will be used.
        seqmule pipeline -a sampleA.1.fq,sampleB.1.fq -b sampleA.2.fq,sampleB.2.fq -e -prefix sampleA,sampleB -capture default

        #same as above except that multi-sample variant calling is enabled. Multi-sample variant calling means we assume the two samples come from the same family.
        seqmule pipeline -a sampleA.1.fq,sampleB.1.fq -b sampleA.2.fq,sampleB.2.fq -e -prefix sampleA,sampleB

        #analysis beginning with BAM files. BAM files store the alignment information of your data. Output files will have same prefixes as BAM files.
        seqmule pipeline -bam 1.bam,2.bam,3.bam -e -capture default

        #same as above, except the BAM files will be merged before proceeding. Output has mandatory prefix 'sample' here. Merging is useful when you sequenced your sample multiple times and want to pool the data together. 12 CPUs are used.
        seqmule pipeline -bam 1.bam,2.bam,3.bam -e -merge -prefix sample -t 12

        #same as above except that the variant calling will be carried out in a parallel fashion. 12 CPUs are used.
        seqmule pipeline -bam 1.bam,2.bam,3.bam -e -merge -prefix sample -quick -t 12

        #analyze gzipped FASTQ files (.fq.gz) and unzipped files (.fq). Gzipped files will be unpacked temporarily and be removed after analysis.
        eqmule pipeline -a sample1.1.fq.gz,sample2.1.fq -b sample1.2.fq.gz,sample2.2.fq -e -prefix sample1,sample2 -capture default

        #merge multiple pairs of FASTQ files and do multiple sample variant calling
        #--forceOneRG must be used along with -rg to assign same @RG tag to input files
        #input files belonging to same sample have same @RG tag
        #--mergingrule 1,1,2 means sample1 has 1 (pair of) input file, sample2 has 1 (pair of) input file, sample3 has 2 (pairs of) input files.
        seqmule pipeline -a sample1.1.1.fastq,sample2.1.1.fastq,sample3.1.1.fastq,sample3.2.1.fastq -b sample1.1.2.fastq,sample2.1.2.fastq,sample3.1.2.fastq,sample3.2.2.fastq -p sample1o3,sample2o3,sample3o3 -g -merge --forceOneRG -rg READGROUP --mergingrule 1,1,2 -ms

        #merge with default method
        #if 4 (pairs of) input files are given for 2 samples, each sample gets 2 by default
        #here multi-sample variant calling is not enabled
        seqmule pipeline -a sample1.1.1.fastq,sample1.2.1.fastq,sample2.1.1.fastq,sample2.2.1.fastq -b sample1.1.2.fastq,sample1.2.2.fastq,sample2.1.2.fastq,sample2.2.2.fastq -p sample1o2,sample2o2 -g -merge --forceOneRG -rg READGROUP 

        #run via Sun Grid Engine (a job scheduling system)
        seqmule pipeline -a 1.fastq -b 2.fastq -prefix genomeData -threads 12 -rg READGROUP -g -advanced advanced_config -nostat -sge "qsub -V -cwd -pe smp XCPUX"

# DETAILS

- **--sge**

    To run commands via Sun Grid Engine, SGE must be installed first. -e, -o will be added automatically. "-S /bin/bash" is added automatically. Do NOT specify -e,-o or -S in the qsub template. -V, -cwd, -pe options must be present.

- **--platform**

    sequencing platform, default is illumina. Only IonTorrent and Illumina are supported currently

- **--ref**

    specify the reference genome, otherwise it searches inside installation path for default reference genome

- **--index**

    specify prefix for index files, if a program-specific index prefix is supplied, this option will be omitted. If no index prefix is supplied, downloaded files will be searched for index

- **--rg**

    Specify the readgroup of '@RG' tag in SAM/BAM file. Usually one combination of sample/library/lane constitutes a readgroup, but users can make their own choices. Default is 'READGROUP'.

- **--forceOneRG**

    Force all readgroups to be one readgroup when merging is enabled. Some algorithms account for different variabiliy associated with reads from the different readgroups. This option is only effective for BAM input.

- **--unionRG**

    When merging BAM files, combine reads with same readgroup ID, keep reads with different readgroup IDs intact.

- **--mergingrule**

    comma-delimited numbers for how many files merged for each sample. For example, if your prefix list is sample1,sample2, and mergingrule is 2,3, then the first 2 input files are merged as sample1 and the last 3 files are merged as sample2. Positive integers are expected. Default: equal number of files for each samples. So if you have two samples and 4 fastq/bam files, then the first two are merged for 1st sample, the last two are merged for 2nd sample.

- **--hapmap**

    specify the HapMap VCF file for variant quality recalibration, otherwise it searches for default file within installation directory

- **--dbsnp**

    specify the dbSNP file for variant quality recalibration, otherwise it searches for default file within installation directory

- **--kg**

    specify the 1000 genome project VCF file for variant quality recalibration, otherwise it searches for default file inside installation directory

- **--no-resolve-conflict**

    By default, SeqMule will add or trim leading 'chr' to the BED file or BAM file to make the contig names consistent with reference. Modified BED and BAM will be saved to a new file.
