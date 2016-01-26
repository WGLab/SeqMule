# NAME

SeqMule an automatic pipeline for next-generation sequencing data analysis

# SYNOPSIS

seqmule stats <options>

For details, please use 'seqmule stats -h':

Options:

        --prefix,-p <STRING>      output prefix. Mandatory for multiple input files.
        --bam <BAM>               a sorted BAM file (used with --capture, --aln)
        --capture [BED]           a BED file for capture regions (or any other regions of interest). Effective for --bam and --vcf.
        --vcf <VCF>               output variant stats for a VCF file. If a BED file is supplied, extract variants based on the BED file.
        --aln                     output alignment stats for a BAM file
        --consensus,-c <LIST>     comma separated list of files for extracting consensus calls. 
                                  VCF4 and SOAPsnp *.consensus format or ANNOVAR *.avinput required.
        --union,-u <LIST>         comma separated list of files for pooling variants (same format as above).
        --venn <LIST>             comma separated list of files for Venn diagram plotting (same format as above).
        --c-vcf <LIST>            comma separated list of SORTED VCF files for extracting consensus calls. *.vcf or *.vcf.gz suffix required
        --u-vcf <LIST>            comma separated list of SORTED VCF files for extracting union calls. *.vcf or *.vcf.gz suffix required
        --ref <FASTA>             reference file in FASTA format. Effective for --c-vcf and --u-vcf.
        -s,--sample <STRING>      sample name for VCF file, used for -vcf, -u, -venn, -c options.
        --plink                   convert VCF to PLINK format (PED,MAP). Only works with --vcf option.
        --mendel-stat             generate Mendelian error statistics
        --paternal <STRING>       sample ID for paternal ID (case-sensitive). Rest are either maternal or offspring. Only one family allowed.
        --maternal <STRING>       sample ID for maternal ID (case-sensitive). Rest are either paternal or offspring. Only one family allowed.
        -N <INT>                  extract variants appearing in at least N input files. Currently only effective for --c-vcf option.
        --jmem <STRING>           max java memory. Only effective for --c-vcf and --u-vcf. Default: 1750m
        --jexe <STRING>           Java executable path. Default: java
        -t <INT>                  number of threads. Only effective for --aln, --c-vcf and --u-vcf. Default: 1
        --tmpdir <DIR>            use DIR for storing large temporary files. Default: $TMPDIR(in your ENV variables) or /tmp
        --nofilter                If specified, consider all variants, otherwise, only unfiltered variants.
        -h,--help                 help
        --noclean                 do not clean temporary files
        -v,--verbose              verbose


        EXAMPLE 

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

# OPTIONS

- **--capture**

    SeqMule automatizes analysis of next-generation sequencing data by simplifying program installation, downloading of various databases, generation of analysis script, and customization of your pipeline.
