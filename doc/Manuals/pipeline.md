# NAME

seqmule-pipeline generates an analysis script based on options and/or advanced configuration.

# SYNOPSIS

        seqmule pipeline <options>

# DESCRIPTION

This command takes FASTQ/BAM files, various options and an optional advanced configuration file as input and generates a script file containing a set of commands, along with their resource requirements and dependencies. The script will then be given to seqmule-run for execution unless otherwise directed.

# OPTIONS

        --prefix,-p               comma-delimited list of sample names, will be used for
                                  output file naming. Mandatory for FASTQ input or BAM input
                                  with merge enabled.

        -a <FASTQ>                1st FASTQ file (or comma-delimited list)
        -b <FASTQ>                2nd FASTQ file (or comma-delimited list)
        --bam <BAM>               BAM file (or comma-delimited list). Exclusive of -a,-b 
                                  options.
        -a2 <FASTQ>               1st FASTQ file (or comma-delimited list) from tumor tissue.
        -b2 <FASTQ>               2nd FASTQ file (or comma-delimited list) from tumor tissue.
        --bam2 <BAM>              BAM file (or comma-delimited list) from tumor tissue. 
                                  Exclusive of FASTQ input.

        --merge,-m                merge FASTQ or BAM files before analysis
        --mergingrule <TEXT>      comma-delimited numbers for how many files merged for 
                                  each sample.
                                  Default: equal number of files for each samples.
        -ms                       do multiple-sample variant calling (only valid for GATK
                                  ,VarScan and SAMtools)

        -N <INT>                  if more than one set of variants are generated, extract
                                  variants shared by at least INT VCF output
        --build <hg18,hg19>       genome build. Default is hg19.
        --readgroup,-rg <TEXT>    readgroup ID. Specify one ID for all input or a comma-
                                  separated list. Default: READGROUP_[SAMPLE NAME]
        --platform,-pl <TEXT>     sequencing platform, only Illumina and IonTorrent are 
                                  supported. Specify one platform for all input or a comma-
                                  separated list. Only for FASTQ input. Default: ILLUMINA.
        --library,-lb <TEXT>      sequencing library. Specify one library for all input or 
                                  a comma-separated list. Only for FASTQ input. Default:
                                  LIBRARY.
        --forceOneRG              force use of one readgroup ID for BAM when merging is 
                                  enabled. See details.
        --unionRG                 When merging BAM files, combine reads with same readgroup 
                                  ID, keep reads with different readgroup IDs intact.
        --phred <1,33,64>         Phred score scheme. 1 is default, for auto-detection. 
                                  Has no effect on BAM input.
        --wes,-e                  the input is captured sequencing data
        --wgs,-g                  the input is whole-genome sequencing data
        --capture <BED>           calculate coverage stats and extract (or call) variants
                                  over the regions defined by this file. If you do not have
                                  a custom BED file, use '-capture default' to use default
                                  BED file.
        --no-resolve-conflict     seqmule will NOT try to resolve any conflict among BED,
                                  BAM and reference. Run 'seqmule pipeline -h' for details.
        --no-check-chr            skip checking chromosome consistency. By default, SeqMule
                                  forces chromosomes in input to be consistent with builtin
                                  reference.
        --no-check-idx            skip checking index files for aligners. This is recommended
                                  when using non-default reference genome.
        --threads,-t <INT>        number of threads, also effective for -sge. Default: 1.
        --sge <TEXT>              run each command via Sun Grid Engine. A template with 
                                  XCPUX keyword required. See examples.
        --nodeCapacity,-nc <INT>  max number of processes/threads for a single node/host.
                                  Default: unlimited.
        --quick,-q                enable parallel processing at variant calling
        --jmem <STRING>           max memory used for java virtual machine. Default: 1750m.
        --jexe <STRING>           Java executable path. Default: java
        --gatknt <INT>            number of threads for GATK. Prevent GATK from opening 
                                  too many files. Default: 2.
        --advanced [FILE]         generate or use an advanced configuration file
        --tmpdir <DIR>            use DIR for storing large temporary files. Default: 
                                  $TMPDIR(in your ENV variables) or /tmp
        --norun,-nr               do NOT run analysis, only generate script
        --nostat,-ns              do NOT generate statistics
        --norm                    do NOT remove intermediate SAM, BAM and other files
        --forceRmDup              force removal of duplicates. This overrides default 
                                  behavior which disables duplicate removal for small capture regions.
        --overWrite,-ow           overwrite files whose names conflict with current analysis.

        --ref <FILE>              reference genome. Override default database (the following
                                  is the same). 
                                  When you use custom databases, make sure they are 
                                  compatible with each other.
        --index <PREFIX>          prefix for bowtie, bowtie2, soap index files. Including 
                                  path.
        --bowtie <PREFIX>         prefix ONLY for bowtie index files, including path
        --bowtie2 <PREFIX>        prefix only for bowtie2 index files, including path
        --soap <PREFIX>           prefix only for soap index files, including path
        --hapmap <FILE>           HapMap VCF file for variant quality recalibration
        --dbsnp <FILE>            dbSNP VCF file for variant quality recalibration
        --dbsnpver,-dv <INT>      dbSNP version for variant quality recalibration. By 
                                  default, it's 138.
        --kg <FILE>               1000 genome project VCF file for variant quality 
                                  recalibration
        --indel <FILE>            Indel VCF file for GATK realignment and VQSR

        --verbose,-v              verbose output
        --help,-h                 show this message

# EXAMPLES

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
        
                seqmule pipeline -a fa_R1.fq.gz,mo_R1.fq.gz,son_R1.fq.gz -b fa_R2.fq.gz,mo_R2.fq.gz,son_R2.fq.gz -ms -e -q -t 36 -prefix father,mother,son -capture default -sge "qsub -V -cwd -pe smp XCPUX" -nc 12
        
        Explanations: `-e` for whole-exome or captured sequencing; `-ms` for multi-sample variant calling, which more accurate for a family trio than separate variant calling; `-capture default` tells SeqMule to use [default exome definition](/Miscellaneous/FAQ.md# How are default exome regions defined? Where do they come from?) for extracting variants; `-sge "qsub -V -cwd -pe smp XCPUX` tells SeqMule proper SGE commands and options for job submission, in particular, `XCPUX` is a special keyword reserved for SeqMule to specify number of CPUs for each job; `-q` enables faster variant calling at the expense of higher memory usage; `-prefix father,mother,son` specifies 3 prefixes for 3 sets of reads; `-t 36` asks SeqMule to use 36 CPUs, in a cluster environment, these CPUs might no reside on the same machine; `-nc 12` tells SeqMule that a compute node has at most 12 CPUs. By default, the combination of BWA-MEM+FreeBayes+SAMtools+GATKLite will be used for analysis. A consensus VCF file (from 3 variant callers) will be generated at the end.

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
