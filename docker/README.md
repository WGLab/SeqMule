# How to test the docker container?
```
cd /opt/SeqMule/example
seqmule pipeline -a normal_R1.fastq.gz -b normal_R2.fastq.gz -prefix example -N 2 -capture default -threads 4 -e
seqmule pipeline --advanced ../misc/predefined/bwa_gatk_HaplotypeCaller.config -a normal_R1.fastq.gz -b normal_R2.fastq.gz -prefix example -N 2 -capture default -threads 4 -e
```
