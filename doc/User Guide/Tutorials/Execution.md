## Execution

### Quick mode

Add `-q` or `-quick` option to `seqmule pipeline` will put variant calling under parallel execution. This applies to all variant callers in SeqMule except for SOAPsnp. The region of interest will be split into `N` parts, and variant calling is performed over each interval independently. `N` refers to number of CPU cores. Quick mode does not require any cluster computing infrastructure by itself. However, when `N` is large, it is recommend to run quick mode with SGE as some system resources may be depleted easily. For instance, running ~20 GATK-HaplotypeCaller instances simultaneously may generate over 1000 threads and exceed `nproc` (number of processes) limit easily.

### Running SeqMule with SGE

#### Run with SGE from the beginning
SGE stands for Sun Grid Engine. SGE is a popular resource management system in computation cluster environment. SeqMule normally achieves multiprocessing by forking child process to execute commands. With SGE, SeqMule will submit tasks to the system and waits for them to finish. The `-threads` option controls total number of CPUs requested at any given time when it is used with `-sge` option. An example command looks like the following:

```
seqmule pipeline -ow -prefix sample -a sample.1.fastq.gz -b sample.2.fastq.gz -e -capture default -t 4 -jmem 1750m --advanced seqmule/predefined_config/bowtie2_gatk.config -sge "qsub -V -cwd -pe smp XCPUX" --nodeCapacity 4
```

Here, the double quoted string following `-sge` is a template for job submission. `XCPUX` is a keyword that will be replaced by actual number of CPUs needed for each task. SeqMule has to be run on a submission node. Do NOT specify `-e`,`-o`,`-S` options in the template as SeqMule will do it for you. SeqMule adds `-S /bin/bash` for all tasks. You can specify other options like queue name, memory request, email address in the template. Because some programs require lots of memory, you may want to try different arguments for `-jmem`, `-threads` and request larger amount of memory in the template in case you are not sure. `--nodeCapacity` tells SeqMule maximum number of threads to run on a single node, usually this is just the number of CPU cores on your compute node.

#### Run with SGE when resuming stopped analysis
When you resume your analysis by `seqmule run`, it is necessary to specify the SGE parameters again. The following is an example.

```
seqmule run -sge 'qsub -V -cwd -pe smp XCPUX' prefix.script
```

### Running in the cloud 

With increasing popularity of cloud computing, more users may want to run large computational jobs in the cloud. SeqMule now can be deployed in the cloud via a program called *StarCluster*. Here are the steps:

+ Install [StarCluster](http://star.mit.edu/cluster/docs/latest/quickstart.html)
+ Use one of the following Amazon Machine Images (AMI) to launch a cluster by specifying the desired AMI-ID for `NODE_IMAGE_ID` in StarCluster config file. This image comes with SeqMule and necessary databases for hg19. If you want to launch a starcluster in other regions, please copy the image to another region first, see [here](http://serverfault.com/a/506687/175299) for how to copy. All these images use HVM (Hardware Virtual Machine) virtualization, and are only supported by current generation instances and a few previous generation instances. See [details about HVM](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/virtualization_types.html).


|Region   			|AMI-ID  	|
|---				|---		|
|us-west-1(northern California)	|ami-6b4dbd2f  	|
|eu-west-1(Ireland) 		|ami-9289c4e5	|
|ap-northeast-1(Tokyo)  	|ami-7859f778   |


+ Log into the virtual cluster and run SeqMule. All the executables and database files are located in `/usr/share/seqmule`. If you want to make changes to this folder, please log in as user `ubuntu`.
+ Users interested in running SeqMule in Amazon cloud should get familiar with some concepts like [EBS](http://aws.amazon.com/ebs/), [S3](http://aws.amazon.com/s3/), [regions](http://docs.aws.amazon.com/AWSEC2/latest/UserGuide/using-regions-availability-zones.html). [qwikLABS](https://qwiklabs.com/) provides some hands-on labs for free.

