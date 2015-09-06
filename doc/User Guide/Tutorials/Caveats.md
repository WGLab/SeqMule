## Caveats

NOT all combinations of alingers and variant callers work. For example, SOAPaligner and SOAPsnp don't support SAM, BAM formats natively, so they don't work well with the rest of algorithms. Also, bowtie doesn't report mapping quality, so it shouldn't be used with GATK. For combinations we have tested, please use predefined configuration files under `seqmule/misc/predefined_config` folder.
