# How to test the docker container?
```
export PATH=/opt/SeqMule/bin:/opt/SeqMule/exe/jdk8/bin:/usr/lib/jvm/java-1.7.0/bin:${PATH}
cd /opt/SeqMule/example
seqmule pipeline -a normal_R1.fastq.gz -b normal_R2.fastq.gz -prefix example-default -N 2 -capture default -threads 4 -e
seqmule pipeline --advanced ../misc/predefined_config/bwa_gatk_HaplotypeCaller.config -a normal_R1.fastq.gz -b normal_R2.fastq.gz -prefix example-bwa-gatkhc -N 2 -capture default -threads 4 -e
```
