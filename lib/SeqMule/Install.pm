#------------------------------------------------------------------------
#----                          SeqMule.pm                            ----
#------------------------------------------------------------------------
package SeqMule::Install; 
use strict;
use warnings;
use POSIX;
use Config;
use File::Copy;
use File::Path;
use File::Find qw/find/;
use File::Spec;
use vars qw($bin);
use Cwd qw/cwd/;
use Carp qw/carp croak/;
use SeqMule::Utils;

my @unlink;
my $INSTALLATION_GUIDELINE="To install prerequisites, on RedHat, CentOS, Fedora, run:
sudo yum install -y make cmake gcc gcc-c++ ncurses-devel ncurses R unzip automake autoconf git-core gzip tar
#for java, please follow instructions on http://java.com

To install prerequisites, on Ubuntu, run:
sudo apt-get update
sudo apt-get install -y cmake build-essential gcc g++ ncurses-base ncurses-bin ncurses-term libncurses5 libncurses5-dev r-base unzip automake autoconf git gzip tar default-jre
#for java, please follow instructions on http://java.com
";

sub install_dev_tools
{
    &GNU_Cplusplus;
    &gcc;
    &unzip;
    &make;
    &cmake;
    &automake;
    &autoconf;
    &git;
    &tar;
    &gzip;
    &java;
}


END
{
    unlink @unlink;
}

sub version
{
    my $install_dir=shift;
    my $ver=`cat $install_dir/version`;
    chomp $ver;
    warn "SeqMule Version: $ver\n";
}

sub clean
{
    warn "NOT Implemented.\n";
    exit;
}
sub freshinstall
{
    my $install_dir=shift;
    my %sys_require=%{shift @_};
    my %exe_require=%{shift @_};
    #compilation tools
    &install_dev_tools;
    for my $exe ((keys %exe_require,keys %sys_require))
    {
	eval ("&$exe(\$install_dir)");
    }
	&status($install_dir,\%sys_require,\%exe_require);
}
sub installexes
{
    my $install_dir=shift;
    my %sys_require=%{shift @_};
    my %exe_require=%{shift @_};
    my @exe_notinstall;
    warn "NOTICE: Checking prerequisites...\n";
    for (keys %sys_require)
    {
	push @exe_notinstall,$_ unless &search(1,$install_dir,@{$sys_require{$_}});
    }
    for (keys %exe_require)
    {
	push @exe_notinstall,$_ unless &search(0,$install_dir,@{$exe_require{$_}});
    }
    if (@exe_notinstall)
    {
	#compilation tools
	&install_dev_tools();
	for my $exe (@exe_notinstall)
	{
	    eval ("&$exe(\$install_dir)");
	}
	&status($install_dir,\%sys_require,\%exe_require);
    } else
    {
	warn "Nothing to do\n";
    }
}
sub debug
{
    my $install_dir = shift;
    my $debug_for_opt = shift;
    eval "&".$debug_for_opt."(\"$install_dir\",\"$install_dir/misc/exe_locations\")" or die "ERROR: failed to run $debug_for_opt under debug mode\n";
}

sub parse_locations 
{
    my $install_dir=shift;
    my $locfile=shift;
    my $nonempty_locfile;
    if ($locfile)
    {
	croak "ERROR: empty exe location file $locfile\n" unless -s $locfile;
	$nonempty_locfile = $locfile;
    } else
    {
	$locfile = "exe_locations";
	$nonempty_locfile="$install_dir/misc/$locfile";
    }
    my %exe_locations;
    open IN,"<",$nonempty_locfile or croak "Cannot open $nonempty_locfile\n";
    carp "NOTICE: Reading program URLs...\n";
    while (<IN>)
    {
	#assuming program\tURL format
	next if /^#|^\s*$/; #skip comments and empty lines
	chomp;
	unless (/^([^\t]+)\t([^\t]+)$/)
	{
	    warn "Malformed file\n";
	    return undef;
	}
	my ($key,$value)=($1,$2);
	if (defined $exe_locations{$key})
	{
	    warn "Duplicate paramter!\n";
	    return undef;
	}
	unless ( $key && $value )
	{
	    warn "Missing program name or its URL\n";
	    return undef;
	}
	$exe_locations{$key}=$value;
    }
    return %exe_locations;
}

sub downfail
{
    my $exe=shift;
    my $url=shift;
    warn "Downloading $exe from $url failed.\n";
    exit 0;
}

sub unpackfail
{
    my $file=shift;
    warn "Unpacking $file failed.\n";
    &rm_existing($file);
    exit 0;
}

sub rm_file
{
    my $file=shift;
    return unless -e $file;
    warn "Removing $file\n";
    unlink $file or die "Cannot remove existing $file\n";
}

sub movefail
{
    my ($dir,$exe)=@_;
    warn "Failed to rename $dir to $exe\n";
    exit 0;
}

sub chmodfail
{
    my $exe=shift;
    warn "Failed to make $exe executable\n";
    exit 0;
}

sub sys_rmdir
{
    my $dir=shift;
    return unless -d $dir;
    warn "Removing existing $dir\n";
    !system("rm -rf $dir") or die "Cannot remove: $!\n";
}
sub makefail
{
    my $exe=shift;
    die "!!!!!!!!!!!!!!!!!!!!!!!!!\nERROR: Failed to make $exe\n";
}



sub GNU_Cplusplus
{
    die "Error: g++ NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("g++");
}
sub gzip
{
    die "Error: gzip NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("gzip") && &sys_which("gunzip");

}
sub tar
{
    die "Error: tar NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("tar");

}

sub gcc
{
    die "Error: gcc NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("gcc");
}

sub git
{
    die "Error: git NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("git");
}

sub make
{
    die "Error: make NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("make");
}
sub cmake
{
    die "Error: cmake NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("cmake");
}

sub automake
{
    die "Error: automake NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("automake");
}
sub autoconf
{
    die "Error: autoconf NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("autoconf");
}
sub unzip
{
    die "Error: unzip NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("unzip");
}
sub java
{
    die "Error: java NOT found.\n$INSTALLATION_GUIDELINE\n" unless &sys_which("java");
}

#########################START OF INDIVIDUAL PROGRAMS##############################
sub fastqc
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='fastqc';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.zip"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/fastqc";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my $dir = "FastQC"; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chmod 0755,$executable or return &chmodfail($executable);
    die "Failed to find executables for $exe\n" unless (-f $executable);
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}


sub bowtie
{

    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='bowtie';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.zip"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/bowtie";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <bowtie-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chdir($exe);
    if (-f "bowtie_main.cpp")
    {
	!system("make") and -f $executable or &makefail($exe);
    }
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}

sub bwa
{

    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='bwa';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.bz2"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/bwa";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <bwa-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chdir($exe);
    if (-f "bwa.c")
    {
	!system("make") and -f $executable or &makefail($exe);
    }
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}

sub samtools
{

    #my $check_curses=`locate curses.h 2>/dev/null`;
    #die "ERROR: curses.h NOT found. It is required by samtools tview.\nPlease use 'yum install ncurses-devel ncurses'\n" if $check_curses !~ /curses\.h$/;

    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='samtools';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.bz2"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/samtools";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <samtools-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    system("chmod -R +rx $exe");
    chdir($exe);
    if (-f "sam.c")
    {
	!system("make") and -f $executable or &makefail($exe);
    }
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub gatk
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='gatk';
    my $executable="GenomeAnalysisTK.jar";
    mkdir "$exe_base/$exe";
    warn "\n\n\n";
    warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"x3;
    warn "CAUTION: SeqMule cannot automatically install GATK due to license limitations.\n",
         "Please download, unpack it and copy $executable to $exe_base/$exe\n";
    warn "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"x3;
    warn "\n\n\n";
    sleep 5;
}

sub gatklite
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='gatklite';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.bz2"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/GenomeAnalysisTKLite.jar";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <GenomeAnalysisTKLite-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    die "Failed to find executables for $exe\n" unless (-f "$exe_base/$exe/GenomeAnalysisTKLite.jar");
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub snver
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='snver';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe/$exe.tar.gz"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/SNVerIndividual.jar";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    mkdir "$exe_base/$exe" unless -d "$exe_base/$exe";
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,"$exe_base/$exe") or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    die "Failed to find executables for $exe\n" unless -f $executable;
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub jdk8
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='jdk8';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.gz"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/bin/java";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    !system("wget -O- --no-check-certificate --no-cookies --header 'Cookie: oraclelicense=accept-securebackup-cookie' $url > $file") or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my $dir = "jdk1.8.0_131"; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chmod 0755,$executable or return &chmodfail($executable);
    die "Failed to find executables for $exe\n" unless (-f $executable);
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}

sub picard
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='picard';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.zip"; #file to save to
    my $url = $exe_locations{$exe};
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <picard-tools-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    die "Failed to find executables for $exe\n" unless (-f "$exe_base/$exe/MarkDuplicates.jar" && -f "$exe_base/$exe/SortSam.jar");
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}

sub soap
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='soap';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.gz"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/soap";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <soap2*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    die "Failed to find executables for $exe\n" unless (-f $executable);
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}

sub varscan
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='varscan';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.jar"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/varscan.jar";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <soap2*>; #dir got after unpacking
    mkdir $exe or die "Cannot create directory $exe\n"; 
    &File::Copy::move($file,$exe) or return &movefail($exe,$exe);
    die "Failed to find executables for $exe\n" unless (-f $executable);
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub soapsnp
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='soapsnp';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.gz"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/soapsnp";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    push(@unlink, $file);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file

    chdir($exe_base);
    my ($dir) = grep {-d $_} <SOAPsnp*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chdir($exe);
    if (-f "soap_snp.h")
    {
	$ENV{CPLUS_INCLUDE_PATH}="$install_dir/inc/boost_lib";
	!system("make") and -f $executable or return &makefail($exe);
    }
    warn "Installing accessory program: msort\n";
    &msort($install_dir,$exe_loc);
    warn "Installing accessory program: soap2sam\n";
    &soap2sam($install_dir,$exe_loc);
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub msort 
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='msort';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.gz"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/msort";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    push(@unlink, $file);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file

    my $dir = "msort"; #dir got after unpacking
    chdir("$exe_base/$dir");
    warn "Configuring $exe...\n";
    !system("make") and -f $executable or return &makefail ($exe);
    warn "NOTICE: \nNOTICE: Finished installing accessoary program: $exe\n";
    chdir($cwd);
}
sub soap2sam 
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='soap2sam';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.gz"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/soap2sam.pl";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    push(@unlink, $file);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    chdir($exe_base);
    mkdir $exe unless -d $exe;
    &File::Copy::move("soap2sam.pl",$exe) or return &movefail("soap2sam.pl",$exe);
    die "Failed to find executables for $exe\n" unless (-f $executable);
    warn "\nNOTICE: Finished installing accessoary program: $exe\n";
    chdir($cwd);
}
sub bowtie2
{

    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='bowtie2';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.zip"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/bowtie2";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <bowtie2-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chdir($exe);
    if (-f "bowtie_main.cpp")
    {
	!system("make") and -f $executable or &makefail($exe);
    }
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub freebayes
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='freebayes';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.gz"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/bin/freebayes";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    chdir($exe);
    !system("make") and -f $executable or &makefail($exe);
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub tabix
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='tabix';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.bz2"; #file to save to
    my $url = $exe_locations{$exe};
    my $executable="$exe_base/$exe/tabix";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <tabix-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    system("chmod -R +rx $exe");
    chdir($exe);
    if (-f "main.c")
    {
	!system("make") and -f $executable or &makefail($exe);
    }
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub vcftools
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='vcftools';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.tar.gz"; #file to save to
    my $url = $exe_locations{$exe} or die "No URL for $exe\n";
    my $executable="$exe_base/$exe/bin/vcftools";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <vcftools_*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chdir($exe);
    if (-f "Makefile")
    {
	!system("make") and -f $executable or &makefail($exe);
    }
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub snap
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='snap';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.zip"; #file to save to
    my $url = $exe_locations{$exe} or die "No URL for $exe\n";
    my $executable="$exe_base/$exe/snap";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <snap-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chdir($exe);
    if (-f "Makefile")
    {
	!system("make") and -f $executable or &makefail($exe);
    }
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}
sub vt
{
    my $install_dir=shift;
    my $exe_loc = shift;
    my $exe_base="$install_dir/exe";
    mkdir $exe_base unless -d $exe_base;
    my $exe='vt';
    my %exe_locations=&parse_locations($install_dir,$exe_loc) or die "Cannot get URLs\n";
    my $file = "$install_dir/exe/$exe.zip"; #file to save to
    my $url = $exe_locations{$exe} or die "No URL for $exe\n";
    my $executable="$exe_base/$exe/vt";
    my $cwd=cwd();

    &rm_file($file);
    &sys_rmdir("$exe_base/$exe");
    print "Downloading $exe...\n";
    &SeqMule::Utils::getstore($url, $file) or return &downfail($exe,$url);
    print "Unpacking $exe archive...\n";
    &SeqMule::Utils::extract_archive($file,$exe_base) or return &unpackfail($file); #feed extract_archive full path to zipped file
    push(@unlink, $file);

    chdir($exe_base);
    my ($dir) = grep {-d $_} <vt-*>; #dir got after unpacking
    &File::Copy::move($dir,$exe) or return &movefail($dir,$exe);
    chdir($exe);
    if (-f "Makefile")
    {
	!system("make -j 10") and -f $executable or &makefail($exe);
    }
    warn "\nNOTICE: Finished installing $exe\n";
    chdir($cwd);
}

#########################END OF INDIVIDUAL PROGRAMS##############################



sub sys_which
{
    my $exe=shift;
    return system("which $exe 1>/dev/null 2>/dev/null") ? 0 : 1;
}
#search system PATH and seqmule installation dir for exes
sub search
{
    my $search_sys_path=shift;
    my $install_dir = shift;
    my @targets=@_;
    my @found;
    my @search_path;
    push @search_path, File::Spec->catdir($install_dir,"exe") if -d File::Spec->catdir($install_dir,"exe"); #exe dir contains all external programs
    push @search_path, File::Spec->catdir($install_dir,"bin") if -d File::Spec->catdir($install_dir,"bin"); #bin dir contains some accessory programs
    #don't look at PATH, only look into installation dir
    for my $target(@targets)
    {
	push @found,$target and next if $search_sys_path && &sys_which($target); #++ must precede var otherwise always return 0 at first loop
	for my $single_path(@search_path)
	{
	    my $result=`find -L $single_path -depth -name \'$target\' -type f -print0 -quit`;
	    $result=~s/\0$//; #remove trailling NULL char
	    push @found,$target and last if (-f $result && $result =~ m%/$target$%i);
	}
    }
    return 1 if @found==@targets;
    return 0; #return 1 if found all exes, otherwise 0
}

#prints a nice status message for package configuration and install
sub status 
{
    my $install_dir=shift;
    my %sys_require=%{shift @_};
    my %exe_require=%{shift @_};
    my @exe_notinstall;
    warn "NOTICE: Checking prerequisites...\n";
    warn "NOTICE: SeqMule ignores analysis tools you have in PATH for sake of compatibility.\n";
    for (keys %sys_require)
    {
	push @exe_notinstall,$_ unless &search(1,$install_dir,@{$sys_require{$_}});
    }
    for (keys %exe_require)
    {
	push @exe_notinstall,$_ unless &search(0,$install_dir,@{$exe_require{$_}});
    }
    my $seqmule = 'CONFIGURATION OK';
    $seqmule = '!!!WARNING!!!: MISSING PREREQUISITES' if @exe_notinstall;

    select(STDERR);
    warn "\n"x3;
    warn "==============================================================================\n";
    warn "==============================================================================\n";
    warn "$seqmule\n";
    &version($install_dir);
    warn "==============================================================================\n";
    warn "==============================================================================\n";
    warn "\n"x3;
    if (@exe_notinstall)
    {
	warn "MISSING PROGRAMS\n\n";
	map {s/\t+$//;printf '%-15s',$_; warn "\t\tMISSING\n"} @exe_notinstall;
    }

    warn "\n\nImportant commands:\n".
    "	./Build freshinstall	#(re)install all external programs (Recommended)\n".
    "	./Build installexes	#installs only missing external programs\n".
    "	./Build status		#Shows this status message\n\n".
    "	./Build debug <cmd>	#run an option under debugging mode (only works for individual programs)\n\n".
    "Other Commands:\n".
    "	./Build fastqc		#installs FastQC (for quality control)\n".
    "	./Build bowtie		#installs Bowtie (for read alignment)\n".
    "	./Build bwa		#installs BWA (for read alignment)\n".
    "	./Build bowtie2		#installs Bowtie 2\n".
    "	./Build soap		#installs SOAPaligner\n".
    "	./Build samtools	#installs SAMtools\n". 
    "	./Build gatklite	#installs GATKLite \n".
    "	./Build gatk		#instruction for GATK setup\n".
    "	./Build varscan		#installs VarScan  (variant calling)\n".
    "	./Build picard		#installs Picard tools\n".
    "	./Build soapsnp		#installs SOAPsnp tools\n".
    "	./Build tabix		#installs tabix\n".
    "	./Build jdk8		#installs JDK8\n".
    "	./Build snap		#installs SNAP\n".
    "	./Build freebayes	#installs freebayes\n".
    "	./Build vcftools	#installs vcftools\n".
    "	./Build vt		#installs Vt\n";
    warn "WARNING: Alternatively, you can copy and paste the tools you have outside of SeqMule\n";
    warn "WARNING: into the exe/ folder to skip installation. However, no guarantee to work.\n";
    select(STDOUT);
}

1;
