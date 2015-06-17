# SeqMule Manual

#### Please refer to [Tutorial](Tutorial.md) for more explanations and examples.

### seqmule download 

####Synopsis:

	seqmule download <options>

####Options:

	--down,-d       comma-delimited list of databases and BED files by capture kit manufacturer. See details.
	--downdir <dir>           custom download folder. NOT recommended if you want to use default databases. Default to 'installation_dir/database/'.
	-v,--verbose              verbose output.
	-h,--help                 help
	--noclean                 do not clean temporary files

	Details:
	--down  The following list shows all options and their corresponding databases. You can use *hg19all*,*hg18all*,*all* to download all databases corresponding to a specific genome build or all databases. Default location for databases is *installation_directory/database/*.

	'hg18'        =>'hg18 reference genome',      'hg19'  =>      'hg19 reference genome',
	'hg18ibwa'    =>'hg18 bwa index',             'hg19ibwa'=>    'hg19 bwa index',
	'hg18ibowtie' =>'hg18 bowtie index',          'hg19ibowtie'=> 'hg19 bowtie index',
	'hg18ibowtie2'=>'hg18 bowtie2 index',         'hg19ibowtie2'=>'hg19 bowtie2 index',
	'hg18isoap'   =>'hg18 soap index',            'hg19isoap'=>   'hg19 soap index',
	'hg18hapmap'  =>'hg18 HapMap variants',       'hg19hapmap'=>  'hg19 HapMap variants',
	'hg18kg'      =>'hg18 1000 Genomes variants', 'hg19kg'=>      'hg19 1000 Genomes variants',
	'hg18dbsnp137'=>'hg18 dbSNP 137',             'hg19dbsnp137'=>'hg19 dbSNP 137',
	################BED FILES############
	'hg18agilent'   =>'hg18 Agilent SureSelect and HaloPlex capture kit target regions',
	'hg19agilent'   =>'hg19 Agilent SureSelect and HaloPlex capture kit target regions',
	'hg18iontorrent' =>'hg18 IonTorrent AmpliSeq capture kit target regions',
	'hg19iontorrent' =>'hg19 IonTorrent AmpliSeq capture kit target regions',
	'hg18nimblegen' =>'hg18 Nimblegen SeqCap capture kit target regions',
	'hg19nimblegen' =>'hg19 Nimblegen SeqCap capture kit target regions',

####Examples:
	#download all hg19 databases/BEDs to default location (under installation directory)
	seqmule download -down hg19all 

	#same as above, but saved at custom location
	seqmule download -down hg19all -downdir /home/user/database 

### seqmule stats 

####Synopsis:

	seqmule stats <options>

####Options:

	--prefix,-p <STRING>      output prefix. Mandatory for multiple input files.
	--bam <BAM>               a sorted BAM file (used with --capture, --aln)
	--capture <BED>           a BED file for capture regions (or any other regions of interest)
	--vcf <VCF>               output variant stats for a VCF file. If a BED file is supplied, extract variants based on the BED file.
	--aln                         output alignment stats for a BAM file
	--consensus,-c <LIST>     comma separated list of files for extracting consensus calls.
	VCF4 and SOAPsnp *.consensus format or ANNOVAR *.avinput required.
	--union,-u <LIST>         comma separated list of files for pooling variants (same format as above).
	--venn <LIST>             comma separated list of files for Venn diagram plotting (same format as above).
	--c-vcf <LIST>            comma separated list of SORTED VCF files for extracting consensus calls. *.vcf or *.vcf.gz suffix required
	--u-vcf <LIST>            comma separated list of SORTED VCF files for extracting union calls. *.vcf or *.vcf.gz suffix required
	--ref <FASTA>             reference file in FASTA format. Effective for --c-vcf and --u-vcf.
	-s,--sample <STRING>      sample name for VCF file, used for -vcf, -u, -venn, -c options.
	--plink               convert VCF to PLINK format (PED,MAP). Only works with --vcf option.
	--mendel-stat             generate Mendelian error statistics
	--paternal <STRING>       sample ID for paternal ID (case-sensitive). Rest are either maternal or offspring. Only one family allowed.
	--maternal <STRING>       sample ID for maternal ID (case-sensitive). Rest are either paternal or offspring. Only one family allowed.
	-N <INT>                  extract variants appearing in at least N input files. Currently only effective for --c-vcf option.
	-jmem <STRING>            max java memory. Only effective for --c-vcf and --u-vcf. Default: 1750m
	-t <INT>                  number of threads. Only effective for --c-vcf and --u-vcf. Default: 1
	--tmpdir <DIR>        use DIR for storing large temporary files. Default: $TMPDIR(in your ENV variables) or /tmp
	-h,--help                     help
	--noclean                     do not clean temporary files

####Examples:

	#draw Venn Diagram to examine overlapping between different VCF files
	seqmule stats -p gatk-soap-varscan -venn gatk.vcf,soap.avinput,varscan.vcf

	#extract union of all variants, ouput in ANNOVAR format
	seqmule stats -p gatk-soap-varscan -u gatk.vcf,soap.avinput,varscan.vcf

	#extract consensus of all variants, output in ANNOVAR format
	seqmule stats -p gatk_soap_varscan -c gatk.vcf,soap.avinput,varscan.vcf

	#extract consensus of all variants, output in VCF format
	seqmule stats -p gatk_soap_varscan -c-vcf gatk.vcf,soapsnp.vcf,varscan.vcf -ref hg19.fa

	#extract union of all variants, output in VCF format
	seqmule stats -p gatk_soap_varscan -u-vcf  gatk.vcf,soapsnp.vcf,varscan.vcf -ref hg19.fa

	#generate coverage statistics for specified region (region.bed)
	seqmule stats -p sample -capture region.bed --bam sample.bam

	#generate alignment statistics
	seqmule stats -bam sample.bam -aln

	#generate variant statistics
	seqmule stats -vcf sample.vcf

	#extract variants in specified region generate variant statistics
	seqmule stats -vcf sample.vcf -capture region.bed

	#generate Mendelian error statistics
	#NOTE, sample.vcf contains 3 samples!
	seqmule stats -vcf sample.vcf --plink --mendel-stat --paternal father --maternal mother
	

### seqmule pipeline
####Synopsis:

	seqmule pipeline <options>

####Options:

	--prefix,-p       comma-delimited list of sample names, will be used for @RG tag, output file naming. Mandatory for BAM input with merge enabled, or for FASTQ input.
	-a <FASTQ>                1st FASTQ file (or comma-delimited list)
	-b <FASTQ>                2nd FASTQ file (or comma-delimited list)
	--bam <BAM>       BAM file (or comma-delimited list). Exclusive of -a,-b options.
	--merge,-m        merge all FASTQ or BAM files before analysis
	-ms           do multiple-sample variant calling (only valid for GATK VarScan and SAMtools)
	-N <INT>          if more than one set of variants are generated, extract variants shared by at least INT VCF output
	--build <hg18,hg19>   genome build. Default is hg19.
	--readgroup,-rg <TEXT>    readgroup ID. Specify one ID for all input or a comma-separated list. Default: READGROUP_[SAMPLE NAME]
	--platform,-pl <TEXT>     sequencing platform, only Illumina and IonTorrent are supported. Specify one platform for all input or a comma-separated list. Only for FASTQ input. Default: ILLUMINA.
	--library,-lb <TEXT>      sequencing library. Specify one library for all input or a comma-separated list. Only for FASTQ input. Default: LIBRARY.
	--forceOneRG          force use of one readgroup ID when merging is enabled. See details.
	--unionRG         When merging BAM files, combine reads with same readgroup ID, keep reads with different readgroup IDs intact.
	--phred <1,33,64>     Phred score scheme. 1 is default, for auto-detection. Has no effect on BAM input.
	--wes,-e                  the input is captured sequencing data
	--wgs,-g          the input is whole-genome sequencing data
	--capture <BED>       calculate coverage stats and extract (or call) variants over the regions defined by this file. If you do not have a custom BED file, use '-capture default' to use default BED file.
	--no-resolve-conflict     seqmule will NOT try to resolve any conflict among BED, BAM and reference. Run 'seqmule pipeline -h' for details.
	--threads,-t <INT>    number of threads. Default: 1.
	--quick,-q        enable parallel processing at variant calling
	--jmem <STRING>       max memory used for java virtual machine. Default: 1750m.
	--gatknt <INT>        number of threads for GATK. Prevent GATK from opening too many files. Default: 2.
	--advanced [FILE]     generate or use an advanced configuration file
	--tmpdir <DIR>    use DIR for storing large temporary files. Default: $TMPDIR(in your ENV variables) or /tmp
	--norun,-nr       do NOT run analysis, only generate script
	--nostat,-ns          do NOT generate statistics
	--norm            do NOT remove intermediate SAM, BAM and other files
	--forceRmDup          force removal of duplicates. This overrides default behavior which disables duplicate removal for small capture regions.
	--ref <FILE>              reference genome. Override default database (the following is the same). When you use custom databases, make sure they are compatible with each other.
	--index <PREFIX>          prefix for bowtie, bowtie2, soap index files. Including path.
	--bowtie <PREFIX>         prefix ONLY for bowtie index files, including path
	--bowtie2 <PREFIX>        prefix only for bowtie2 index files, including path
	--soap <PREFIX>           prefix only for soap index files, including path
	--hapmap <FILE>           HapMap VCF file for variant quality recalibration
	--dbsnp <FILE>            dbSNP VCF file for variant quality recalibration
	--dbsnpver,-dv <INT>      dbSNP version for variant quality recalibration. By default, it's 138.
	--kg <FILE>               1000 genome project VCF file for variant quality recalibration
	--indel <FILE>        Indel VCF file for GATK realignment and VQSR

	--verbose,-v          verbose output
	--help,-h         show this message

####Examples:

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
	seqmule pipeline -a sample1.1.fq.gz,sample2.1.fq -b sample1.2.fq.gz,sample2.2.fq -e -prefix sample1,sample2 -capture default

	
	

### seqmule run
####Synopsis:

	seqmule run <script_file> [options]

####Options:

	-n <INT>            run from step INT
	-h,--help           help

####Examples:
	#continue run from last executed step
	seqmule run your_analysis.script

	#run from a certain step
	seqmule run -n 10 your_analysis.script

	

Go to [here](tutorial.html#q9) for details about the script file.

### seqmule update

####Synopsis:

	seqmule update <options>

####Options:

	--git           update from GitHub
	--tmpdir <DIR>  temporary folder for storing copy of downloaded stuff. Default is $TMPDIR or /tmp
	-h,--help           help

####Examples:
	#update SeqMule to the latest version hosted on SeqMule website
	seqmule update

	#update SeqMule to the latest version on GitHub
	seqmule update --git

Copyright 2014 [USC Wang Lab](http://genomics.usc.edu)