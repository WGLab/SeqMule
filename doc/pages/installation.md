-   [Home](../home.html)
-   [Install](installation.html)
-   [Tutorial](tutorial.html)
-   [Manual](manual.html)
-   [FAQ](faq.html)
-   [TechNotes](technotes.html)
-   [Example Report](example_report/summary.html)

\

\

SeqMule Installation
--------------------

### Supported platform

x86-64 Linux

\

### Prerequisites

make, cmake, gcc, g++, curses.h, R, unzip, automake, autoconf, git,
gzip, tar, java

\

### Install

Executables of SeqMule itself are basically some scripts in Perl, you
can use them right after unpacking. However, external programs do need
installation. SeqMule ignores what you have outside seqmule directory
for sake of compatibility.

\

The following commands will download and install SeqMule for you. \# and
texts after it are just comments.

\

`         wget seqmule.usc.edu/seqmule.latest.tar.gz            tar zxvf seqmule.latest.tar.gz         cd SeqMule-master          ./Build freshinstall              `

Alternatively, you can use the following command to just install MISSING
programs:\

./Build installexes\
 \

Due to copyright limitations, you have to download and install GATK (one
of default variant callers) yourself. Use **./Build gatk** to get
instructions. If everything goes smooth, you are ready to go. Good luck!

\

### NOTES

To install prerequisites, on RedHat, CentOS, Fedora, run\

`sudo yum install -y gcc gcc-c++ make cmake ncurses-devel ncurses R unzip automake autoconf git-core gzip tar`
\

If you fail to install R on Centos, please run the following command.

`         rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm                  sudo yum install R     `
\

To install prerequisites, on Ubuntu, run\

`sudo apt-get update`
`sudo apt-get install -y cmake build-essential gcc g++ ncurses-base ncurses-bin ncurses-term libncurses5 libncurses5-dev r-base unzip automake autoconf git gzip tar`
\
 \

To use seqmule without typing entire path, please modify your PATH
environmental variable. \
Don't forget to replace 'absolute\_path\_to\_seqmule' by the actual path
to seqmule folder \
If you use bash:

`echo 'export PATH=$PATH:absolute_path_to_seqmule/bin' >> ~/.bashrc`\
 `source ~/.bashrc`\
 \
 \

If you use tcsh:

`echo 'setenv PATH absolute_path_to_seqmule/bin:$PATH' >> ~/.tcshrc`\
 `source ~/.tcshrc`\

If you don't know which shell (bash/tcsh/csh etc.) you are using, type
the following command to figure out

\
 `echo $0` \
 \

Copyright 2014 [USC Wang Lab](http://genomics.usc.edu) | Designed by
[Free CSS Templates](http://www.templatemo.com)