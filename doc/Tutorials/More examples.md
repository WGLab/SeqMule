*This document demonstrates some common scenarios and corresponding SeqMule commands. Assume SeqMule is installed under `seqmule/` folder.

#Examples for `seqmule download`

##download all hg19 databases/`BED`s to default location (under installation directory)

        seqmule download -down hg19all 

##same as above, but saved at custom location

        seqmule download -down hg19all -downdir /home/user/database 

#Examples for `seqmule pipeline`

##Typical exome analysis

Scenario: I sequenced an exome (with four `FASTQ` files) by nimblegen v3 array, and I want to call the variants by BWA+GATK. If you have NOT downloaded capture kit regions, please download them first:

	seqmule download -d hg19bed

Then analyze the data by the following command:

	seqmule pipeline -a sample_lane1_R1.fq.gz,sample_lane2_R1.fq.gz -b sample_lane1_R2.fq.gz,sample_lane2_R2.fq.gz -capture seqmule/database/hg19nimblegen/hg19_nimblegen_SeqCap_exome_v3.bed -e -advanced seqmule/misc/predefined_config/bwa_gatk_HaplotypeCaller.config -quick -t 4 -prefix mySample

Explanations: `-quick` enables faster variant calling at the expense of higher memory usage; `-t 4` tells SeqMule to use 4 CPUs; `-e` for exome or captured sequencing analysis.

## Fast turnaround whole genome analysis

Scenario: I sequenced a genome with 30X and I need the variant asap (snap+freebayes). 

	seqmule pipeline -a sample_R1.fq.gz -b sample_R2.fq.gz -advanced seqmule/misc/predefined_config/snap_freebayes.config -quick -t 12 -g -prefix mySample

Explanations: `-g` for whole genome analysis; `-t 12` asks SeqMule to use 12 CPUs; `-quick` enables faster variant calling at the expense of higher memory usage.

## I sequenced a trio (or quartet) by exome and I want to find de novo variants. I want to use SGE for this analysis.


##generate a copy of `advanced_config` for modification. You can find some predefined configurations under `seqmule/misc/predefined_config` folder.

        seqmule pipeline -advanced

##run analysis using custom advanced configuration on captured sequencing data.

`1.fastq` is raw data for first reads in paired-end sequencing, and `2.fastq` is for second reads. Number of CPUs is 12, `@RG` tag is `READGROUP` plus your sample name which is specified by `-prefix`. all output files have prefix `exomeData` followed by an underscore. An html report will be generated automatically using default `BED` file(from SureSelect manufacturer).

        seqmule pipeline -a 1.fastq -b 2.fastq -prefix exomeData -threads 12 -rg READGROUP -e -advanced advanced_config -capture default

##same as above, except that coverage stats will be calculated using custom `BED` file

        seqmule pipeline -a 1.fastq -b 2.fastq -prefix exomeData -threads 12 -rg READGROUP -e -advanced advanced_config -capture region.bed

##same as above except that the data comes from whole-genome sequencing.

        seqmule pipeline -a 1.fastq -b 2.fastq -prefix genomeData -threads 12 -rg READGROUP -g -advanced advanced_config

##same as above except that no report webpage will be generated

        seqmule pipeline -a 1.fastq -b 2.fastq -prefix genomeData -threads 12 -rg READGROUP -g -advanced advanced_config -nostat

##Input is multi-sample, paired-end exome or other captured sequencing data, output files have 'sampleA' prefix for sampleA.1.fq and sampleA.2.fq, and 'sampleB' for sampleB.1.fq and sampleB.2.fq. FQ is just abbreviation for FASTQ. Without custom advanced_config, default pipeline 'bwa+gatk+samtools' will be used.
        seqmule pipeline -a sampleA.1.fq,sampleB.1.fq -b sampleA.2.fq,sampleB.2.fq -e -prefix sampleA,sampleB -capture default

##same as above except that multi-sample variant calling is enabled. Multi-sample variant calling means we assume the two samples come from the same family.
        seqmule pipeline -a sampleA.1.fq,sampleB.1.fq -b sampleA.2.fq,sampleB.2.fq -e -prefix sampleA,sampleB

##analysis beginning with BAM files. BAM files store the alignment information of your data. Output files will have same prefixes as BAM files.
        seqmule pipeline -bam 1.bam,2.bam,3.bam -e -capture default

##same as above, except the BAM files will be merged before proceeding. Output has mandatory prefix 'sample' here. Merging is useful when you sequenced your sample multiple times and want to pool the data together. 12 CPUs are used.
        seqmule pipeline -bam 1.bam,2.bam,3.bam -e -merge -prefix sample -t 12

##same as above except that the variant calling will be carried out in a parallel fashion. 12 CPUs are used.
        seqmule pipeline -bam 1.bam,2.bam,3.bam -e -merge -prefix sample -quick -t 12

##analyze gzipped FASTQ files (.fq.gz) and unzipped files (.fq). Gzipped files will be unpacked temporarily and be removed after analysis.
        eqmule pipeline -a sample1.1.fq.gz,sample2.1.fq -b sample1.2.fq.gz,sample2.2.fq -e -prefix sample1,sample2 -capture default

##merge multiple pairs of FASTQ files and do multiple sample variant calling
##--forceOneRG must be used along with -rg to assign same @RG tag to input files
##input files belonging to same sample have same @RG tag
#--mergingrule 1,1,2 means sample1 has 1 (pair of) input file, sample2 has 1 (pair of) input file, sample3 has 2 (pairs of) input files.
        seqmule pipeline -a sample1.1.1.fastq,sample2.1.1.fastq,sample3.1.1.fastq,sample3.2.1.fastq -b sample1.1.2.fastq,sample2.1.2.fastq,sample3.1.2.fastq,sample3.2.2.fastq -p sample1o3,sample2o3,sample3o3 -g -merge --forceOneRG -rg READGROUP --mergingrule 1,1,2 -ms

##merge with default method
##if 4 (pairs of) input files are given for 2 samples, each sample gets 2 by default
##here multi-sample variant calling is not enabled
        seqmule pipeline -a sample1.1.1.fastq,sample1.2.1.fastq,sample2.1.1.fastq,sample2.2.1.fastq -b sample1.1.2.fastq,sample1.2.2.fastq,sample2.1.2.fastq,sample2.2.2.fastq -p sample1o2,sample2o2 -g -merge --forceOneRG -rg READGROUP 

##run via Sun Grid Engine (a job scheduling system)
        seqmule pipeline -a 1.fastq -b 2.fastq -prefix genomeData -threads 12 -rg READGROUP -g -advanced advanced_config -nostat -sge "qsub -V -cwd -pe smp XCPUX"

#Examples for `seqmule run`

##continue run from last executed step

        seqmule run your_analysis.script
        
##run from a certain step

        seqmule run -n 10 your_analysis.script

##run via Sun Grid Engine (a job scheduling system)

        seqmule run -sge "qsub -V -cwd -pe smp XCPUX" your_analysis.script

#Examples for `seqmule stats`

##draw Venn Diagram to examine overlapping between different VCF files
        seqmule stats -p gatk-soap-varscan -venn gatk.vcf,soap.avinput,varscan.vcf

##extract union of all variants, ouput in ANNOVAR format
        seqmule stats -p gatk-soap-varscan -u gatk.vcf,soap.avinput,varscan.vcf

##extract consensus of all variants, output in ANNOVAR format
        seqmule stats -p gatk_soap_varscan -c gatk.vcf,soap.avinput,varscan.vcf

##extract consensus of all variants, output in VCF format
        seqmule stats -p gatk_soap_varscan -c-vcf gatk.vcf,soapsnp.vcf,varscan.vcf -ref hg19.fa

##extract union of all variants, output in VCF format
        seqmule stats -p gatk_soap_varscan -u-vcf  gatk.vcf,soapsnp.vcf,varscan.vcf -ref hg19.fa

##generate coverage statistics for specified region (region.bed)
        seqmule stats -p sample -capture region.bed --bam sample.bam

##generate alignment statistics
        seqmule stats -bam sample.bam -aln

##generate variant statistics
        seqmule stats -vcf sample.vcf

##extract variants in specified region generate variant statistics
        seqmule stats -vcf sample.vcf -capture region.bed

##generate Mendelian error statistics
##NOTE, sample.vcf contains 3 samples!
        seqmule stats -vcf sample.vcf --plink --mendel-stat --paternal father --maternal mother
