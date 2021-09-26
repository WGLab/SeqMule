FROM centos/devtoolset-4-toolchain-centos7:4 AS centos7
USER 0
RUN yum update -y \
&& yum install -y centos-release-scl \
make cmake ncurses-devel ncurses R automake autoconf \
zlib-devel curl less vim bzip2 git wget unzip epel-release \
java-1.7.0-openjdk-devel \
&& yum install -y R \
&& yum clean all 
ENV EDITOR=vi
		
FROM centos7 AS centos7_seqmule		
ARG branch_of_interest		
ENV VERSION=$branch_of_interest
RUN cd /opt \
&& git clone https://github.com/WGLab/SeqMule.git \
&& cd /opt/SeqMule && git checkout ${VERSION} \
&& ./Build freshinstall \
&& ./bin/seqmule download -down hg19,hg19ibwa,hg19kg,hg19indel,hg19dbsnp138,hg19hapmap \
&& mkdir -p example && cd example \
&& wget http://www.openbioinformatics.org/seqmule/example/normal_R1.fastq.gz http://www.openbioinformatics.org/seqmule/example/normal_R2.fastq.gz
ENV PATH=/opt/SeqMule/bin:/opt/SeqMule/exe/jdk8/bin:/usr/lib/jvm/java-1.7.0/bin:${PATH}
