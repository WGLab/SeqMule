# SeqMule Installation

### Supported platform

x86-64 Linux

#### Tested Linux distributions

If you successfully run SeqMule on other platforms or distributions, please email [me](mailto:yunfeigu@usc.edu).

+ CentOS release 6.6 (Final)
+ CentOS release 6.5 (Final)
+ Amazon Linux AMI release 2015.03
+ Ubuntu 12.04LTS

### Prerequisites

perl, make, cmake, gcc, g++ (4.4.7 or 4.6.3), curses.h, R, unzip, automake, autoconf, git,
gzip, tar, java

### Install

Executables of SeqMule itself are basically some scripts in Perl, you can use them right after unpacking. However, external programs do need installation. SeqMule ignores what you have outside seqmule directory for sake of compatibility.

The following commands will download and install SeqMule for you. \# and texts after it are just comments.

	wget seqmule.usc.edu/seqmule.latest.tar.gz            
	tar zxvf seqmule.latest.tar.gz
	cd SeqMule-master
	./Build freshinstall

Alternatively, you can use the following command to just install MISSING programs:

	./Build installexes

Due to copyright limitations, you have to download and install GATK (one of default variant callers) yourself. Use `./Build gatk` to get instructions. If everything goes smooth, you are ready to go. Enjoy!

### NOTES

####Install prerequisites, on RedHat, CentOS, Fedora

	sudo yum install -y gcc gcc-c++ make cmake ncurses-devel ncurses R unzip automake autoconf git-core gzip tar

If you fail to install R on Centos, please run the following command.

	rpm -Uvh http://dl.fedoraproject.org/pub/epel/6/x86_64/epel-release-6-8.noarch.rpm
	sudo yum install R     `

####Install prerequisites, on Ubuntu

	sudo apt-get update
	sudo apt-get install -y cmake build-essential gcc g++ ncurses-base ncurses-bin ncurses-term libncurses5 libncurses5-dev r-base unzip automake autoconf git gzip tar

####SOAPsnp installation failure

If you got the following error installing SOAPsnp and msort (a dependency program), please try changing `g++` to 4.4.x version.

```
stdhashc.cc:72:51:   required from here
stdhash.hh:496:81: error: ‘direct_insert_aux’ was not declared in this scope, and no declarations were found by argument-dependent lookup at the point of instantiation [-fpermissive]
int ret = direct_insert_aux(key, this->n_capacity, this->keys, this->flags, &i);
^
stdhash.hh:496:81: note: declarations in dependent base ‘__lh3_hash_base_class<unsigned int>’ are not found by unqualified lookup
stdhash.hh:496:81: note: use ‘this->direct_insert_aux’ instead
make: *** [stdhashc.o] Error 1
```

####Putting SeqMule in your path
To use seqmule without typing entire path, please modify your PATH environmental variable.  Don't forget to replace `absolute_path_to_seqmule` by the actual path to seqmule folder 
If you use bash:

	echo 'export PATH=$PATH:absolute_path_to_seqmule/bin' >> ~/.bashrc
	source ~/.bashrc
If you use tcsh:

	echo 'setenv PATH absolute_path_to_seqmule/bin:$PATH' >> ~/.tcshrc
	source ~/.tcshrc

If you don't know which shell (bash/tcsh/csh etc.) you are using, type the following command to figure out

	echo $0

####SOAPsnp compilation

SOAPsnp can only be compiled by certain versions of g++. We have tested 4.4.7 and 4.6.3. Please use these versions if you encounter compilation issues for SOAPsnp. If you don't plan to use SOAPsnp, you can ignore this issue.


Copyright 2014 [USC Wang Lab](http://genomics.usc.edu)
