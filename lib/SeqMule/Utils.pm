package SeqMule::Utils;

use strict;
use warnings;
use POSIX;
use File::Copy;
use File::Path;
use File::Find qw/find/;
use File::Basename qw/basename/;
use Cwd qw/cwd abs_path/;
use Carp qw/carp croak/;
no warnings 'File::Find';
use SeqMule::SeqUtils;


sub get_rank_by_mergingrule
{
    #given index for sample, index for file, and merging rule
    #return rank of that file in all files belonging to that sample
    my $i = shift;
    my $j = shift;
    my @mergingrule = @_;
    my $return = $j-&sum(@mergingrule[0..$i-1]);
    $return = 0 unless $return;
    return $return;
}
sub gen_idx_range_by_mergingrule
{
    #given index of sample and merging rule
    #return range of file indexes for that sample
    my $i = shift;
    my @mergingrule = @_;
    my $idx_start = &sum(@mergingrule[0..$i-1]);
    $idx_start = 0 unless $idx_start;
    my @range = $idx_start..($idx_start+$mergingrule[$i]-1);

    return @range;
}
sub getFQprefix
{
    my $filename = shift;
    if($filename =~ /(.*?)(\.1|\.2)?(_phred33)?\.(fq|fastq|fastq\.gz|fq\.gz)/i)
    {
	return $1;
    } else
    {
	croak "ERROR: regex matching failed for $filename\n";
    }
}
sub file_idx2prefix_idx
{
    #given a file index, return corresponding prefix index
    #the rule_list specifies how many files each prefix correspond to.
    #assume file_idx begins at 0
    my $file_idx = shift;
    my @rule_list = @_;

    if(grep {$_ <= 0} (@rule_list) or $file_idx < 0)
    {
	croak "ERROR: merging rule list cannot be smaller than 1 (0 for file index)\n";
    }
    for my $i(0..$#rule_list)
    {
	if($file_idx < $rule_list[$i])
	{
	    return $i;
	} else
	{
	    $file_idx -= $rule_list[$i];
	}
    }
    croak "ERROR: file index too large or merging rule too small\n";
}
sub sum
{
    my $sum = 0;
    for my $i(@_)
    {
	$sum += $i;
    }
    return $sum;
}
sub abs_path_failsafe
{
    my $result = abs_path $_[0];
    unless($result)
    {
	croak "ERROR: Cwd's abs_path doesn't work as expected.\n".
	"Please check your input file path, make sure there is no\n".
	"'~' symbol and file exists (after resolving symbolic link).\n";
    }
}
sub rndStr
{
    #usage: &rndStr(INT,@stringOfchar)
    #output random string of length INT consisting of characters from @stringOfchar
    join '',@_[ map {rand @_} 1 .. shift ];
}

sub write2outfile
{
    my ($output,$outfile)=@_;
    return unless ($output && $outfile);
    open OUT,'>',$outfile or die "can't write to $outfile:$!\n";
    print OUT $output;
    close OUT;
}
sub md5check
{
    my ($source_file,$md5hash)=@_;
    #read MD5 from downloaded file
    return 0 unless -e $source_file;
    if (&sys_which("md5sum"))
    {
	my $digest=`md5sum $source_file`;
	chomp $digest;
	$digest=~s/\s.*$//; #delete trailing space and filename
	(lc($md5hash)) eq (lc($digest)) ? return 1 : return 0; 

    } else
    {
	warn "Cannot find md5sum to check MD5 hash...\n";
	return 0;
    }
}

sub getstore 
{
    my $url = shift;
    my $file = shift;
    my $arg_ref =shift;
    my @arg=@$arg_ref if defined $arg_ref;
    
    croak "ERROR: no URL\n" unless defined $url;
    if(&sys_which("wget"))
    {
	#2014Jan24 Usually stable connections are expected, so I set the timeout and number of retry to be small.
	my $command = "wget --dns-timeout=30 --connect-timeout=30 --read-timeout=30 --tries=10 \'$url\' -nd  --retr-symlinks -r -O $file --no-check-certificate ";
	$command.=$arg[0] if defined $arg[0];
	return !system($command); 
    }
    elsif(&sys_which("curl"))
    {
	my $command = "curl --connect-timeout 30 -f -L \'$url\' -o $file -C - ";
	$command.=$arg[1] if defined $arg[1];
	return !system($command);
    }
    else
    {
	croak "Cannot find wget or curl, please download $file manually\n";
    }
}

sub readLocFile
{
    #read database location file, return references to loc, name, and md5
    my $file=shift;
    open DBLOC, "<", $file or die "ERROR:Cannot open $file :$!\n";
    my %loc;
    my %name;
    my %md5;

    while (<DBLOC>) 
    {
	#format: item_name\tfile1name\tURL\tmd5\tfile2name\tURL\tmd5
	next if /^#|^\s*$/;
	chomp;
	s/\s+/\t/g;
	my @tmp=split;
	my $item=shift @tmp;
	while(@tmp)
	{
	    push @{$name{$item}},(shift @tmp);
	    push @{$loc{$item}},(shift @tmp);
	    push @{$md5{$item}},(shift @tmp);
	}
    }
    close DBLOC;
    return \%loc,\%name,\%md5;
}
#untars a package. 
sub extract_archive 
{
    my $file = shift;
    my $dir=shift;
    
    return 0 unless ($file && $dir);
    &checkOrCreateTmpdir($dir);
    
    my $cwd=cwd;
    chdir($dir);
    
    if ($file=~/\.zip$/ && &sys_which("unzip")) {
	my $command;
	$command="unzip -o $file";
	my $result=!system($command); #fast
	chdir($cwd);
	return $result;
    } 
    elsif ($file=~/tar\.gz$|\.tgz$|\.bz2?$|\.tbz2?$|\.tar$/ && &sys_which("tar"))
    {
	my $command;
	my $u = scalar getpwuid($>);
	my $g = scalar getgrgid($));
	if($file =~ /\.gz$|\.tgz$/){
	    $command = "tar -zxm -f $file";
	}
	elsif($file =~ /\.bz2?$|\.tbz2?$/){
	    $command = "tar -jxm -f $file";
	}
	elsif ($file=~/\.tar$/) {
	    $command = "tar -xm -f $file";
	}
	$command .= " --owner $u --group $g";
	$command .= " --overwrite";
	
	my $result=!system($command);
	chdir($cwd);
	return $result;
    } 
    elsif ($file=~/\.gz$/ && &sys_which("gunzip")) 
    {
	my $errfile="gunzip.$$.err";
	my $command="gunzip -f $file 2>$errfile";
	my $result=!system($command);
	unless ($result)
	{
	    open IN,"<",$errfile or die "Cannot open $errfile, decompression might be okay but returns error code. Please unpack $file manually\n";
	    while(<IN>)
	    {
		$result=1 if /decompression ok/i;
	    }
	    close IN;
	} #in case there is trailing garbage that lets gunzip returns failure
	unlink $errfile;
	chdir($cwd);
	return $result;
    }
    else
    {
	croak "Incorrect filename suffix or failed to find gunzip, or tar or unzip, please unpack $file manually\n";
    }

}

sub gunzip
{
    #usage: ($fq_list,$gunzip_unlink_list)=&Utils::gunzip(@files) or die "ERROR: Unpacking @files failed: $!\n";
    #accept list of plain fastq files and gzipped files, return gunzipped files and files for removal
    my @return=();
    my @unlink=();
    for my $file(@_)
    {
	if ($file!~/\.gz$/i)
	{
	    push @return,$file;
	} elsif (&sys_which("gunzip"))
	{
	    my $outfile=$file; # $file contains absolute path
	    $outfile=~s/\.gz$//i;

	    my $errfile="gunzip.$$.err";
	    my $command="gunzip -c $file 2>$errfile 1>$outfile";
	    warn "Begin unzipping $file\n";
	    my $result=!system($command);
	    unless ($result)
	    {
		open IN,"<",$errfile or die "Cannot open $errfile, decompression might be okay but returns error code. Please unpack $file manually.\n";
		while(<IN>)
		{
		    $result=1 if /decompression ok/i;
		}
		close IN;
	    } #in case there is trailing garbage that lets gunzip returns failure
	    unlink $errfile;
	    $result? (warn "Done\n" and push @return,$outfile and push @unlink,$outfile) : (warn "Failed\n" and return () );
	} else
	{
	    die "Cannot find gunzip, please unpack all files manually\n";
	}
    }
    return \@return,\@unlink;
}

#update a download link 
sub update_loc 
{
    my $old_url=shift;
    my $new_url=shift;
    my $loc_file=shift;
    
    open LOC,"< $loc_file" or die "Cannot open $loc_file:$!\n";
    my @tmp;
    while (<LOC>) {
	s/$old_url/$new_url/;
	push @tmp,$_;
    }
    close LOC;
    open LOC,"> $loc_file" or die "Cannot modify $loc_file:$!\n";
    for(@tmp) {
	print LOC;
    }
    close LOC;
    print "Download link list updated.\n";
}

sub down_fail 
{
    my ($url,$loc_file,$file,$dir) = @_;
    
    warn "Download $file failed, update the download link?[N]\n";
    chomp(my $y_n=<STDIN>);
    if ($y_n=~/y/i)
    {
	$y_n=1;
    } 
    else {$y_n=0}

    if ($y_n) 
    {
	warn "Please copy a direct download link here and then press ENTER:\n";
	while (1) 
	{
	    chomp (my $new_url=<>);
	    if ($new_url=~ m%^\w+://%)
	    {
		print STDERR "Updating the link list...";
		&update_loc($url,$new_url,$loc_file);
		print STDERR "Done.\nPlease try to download $file again.[Press ENTER to continue]\n";
		my $tmp=<STDIN>;
		return;
	    }
	    print STDERR "Please enter a valid DIRECT download link.\n";
	}
    } else 
    {
	warn "Please download it manually to $dir\n";
    }
    
}
sub config_edit
{
    #functions: insert new programs at specificied level, options should be manually inserted RIGHT AFTER programs
    ##its function is very limited, make sure you've add levels for each program at first
    ##deletion preceeds insertion
    ##deletion <=1 and insertion <=1 each time
    my $args=shift; #accept a hash reference
    my @program_list=@{$args->{programs}} if @{$args->{programs}};
    my $level=$args->{level} if @{$args->{level}};	
    my $file=$args->{file} or die "ERROR: No file\n";
    my $del_target=$args->{del} if defined $args->{del};
    my @lines;
    open IN,"<$file" or die "ERROR: Failed to open $file:$!\n";
    @lines=<IN>;
    close IN;
    my $max_level=0;
    for (@lines) {
	($max_level) = $1 if /^(\d+)[pP]/;
    }
    open OUT,">$file" or die "ERROR: Failed to write to $file:$!\n";
    if ($del_target) {
	croak "ERROR: level out of range\n" unless $del_target<$max_level && $del_target>0;
	my $current_level=0;
	my $del_toggle=0;
	for my $old(@lines) {
	    next unless defined $old;
	    next if $old=~/(^#)|(^go_)|(^\s)/i;
	    ($current_level)=$1 if $old=~/^(\d+)[pP]/;
	    if ($del_target==$current_level) {
		$old=undef;
		$del_toggle=1;
	    }
	    my $after_del_level=$current_level-1;
	    $old=~s/^\d+/$after_del_level/ if $del_toggle && defined $old;
	    
	}
    }
    my @after_del_lines;
    for (@lines) {
	push @after_del_lines,$_ if defined;
    }
    my @insert_lines;
    if ($level) {
	croak "ERROR: Illegal level\n" if $level<1;
	for (@program_list) {
	    push @insert_lines,"$level$_=0\n";
	}
	if ($level>$max_level) {
	    warn "NOTE: level $level goes beyond $max_level, set to $max_level+1 instead\n";
	    $level=$max_level+1;
	    print OUT for (@after_del_lines);
	    print OUT for (@insert_lines);
	} else {
	    my $current_level=0;
	    my $insert_toggle=0;
	    for my $old(@after_del_lines) {
		($current_level)=$1 if $old=~/^(\d+)[pP]/;
		if ($level==$current_level && ! $insert_toggle) {
		    print "got it\n";
		    print OUT for (@insert_lines);
		    $insert_toggle=1;
		}
		if ($insert_toggle) {
		    my $after_insert_level=$current_level+1;
		    $old=~s/^\d+/$after_insert_level/;
		    #fragile, make sure no number before options
		}
		print OUT $old;
	    }
	}
    } else {
	print OUT for (@after_del_lines);
    }
    close OUT;
    return 1;
}

sub search 
{
    my $install_dir = shift;
    my $target=shift;
    my @list;
    my $path_to_target;
    my @search_path=("$install_dir/exe","$install_dir/bin",cwd);
    #push @search_path, (split /:/,$ENV{PATH}); #we have to include PATH, because programs like java will not be installed by SeqMule
    #we do not search global path, we assume &search subroutine only handles locally-installed applications

    for my $single_path(@search_path)
    {
	$single_path=abs_path($single_path) if -d $single_path;
	find(
	    {
		wanted          => sub { no warnings 'all'; $path_to_target=$File::Find::name and return if ( -f $File::Find::name && /\/$target$/i) },
		no_chdir        => 1,
		bydepth		=> 1,
	    }, $single_path);
	#if multiple targets are found, only the last one will be output
	return $path_to_target if $path_to_target;
    }
    croak "ERROR: Failed to find $target\nPlease use \'cd $install_dir\' and then \'./Build installexes\' or add path to $target to PATH environmental variable\n";
}


sub search_db 
{
    #return default database if none supplied
    my $args=shift;
    my $type=$args->{type} or croak "No \'type\'";
    my $target=$args->{target} || "";
    my $build=$args->{build} or croak "No \'build\'";
    my $version=$args->{version} || "";
    my $install_dir=$args->{install_dir} or croak "No \'install_dir\'"; 
    if (! $target) {
	if ($type =~ /ref/) {
	    if ($build eq 'hg19') {
		$target="human_g1k_v37.fasta";
	    } elsif ($build eq 'hg18') {
		$target="human_b36_both.fasta";
	    }
	    $target="$install_dir/database/$target";
	    die "ERROR: No reference genome in $install_dir/database (did you download it?)\n" unless -e $target;
	} elsif ($type =~ /dbsnp/) {
	    $target="$install_dir/database/dbsnp_${build}_$version.vcf";
	    die "ERROR: No dbSNP in $install_dir/database\n" unless -e $target;
	} elsif ($type =~ /hapmap/) {
	    if ($build eq 'hg19') {
		$target ="$install_dir/database/hapmap_3.3.b37.vcf";
	    } elsif ($build eq 'hg18') {
		$target ="$install_dir/database/hapmap_3.3.b36.vcf";
	    }
	    die "ERROR: No HapMap database in $install_dir/database\n" unless -e $target;
	} elsif ($type=~/kg/) {
	    if ($build eq 'hg19') {
		$target="$install_dir/database/1000G_omni2.5.b37.vcf";
	    } elsif ($build eq 'hg18') {
		$target="$install_dir/database/1000G_omni2.5.b36.vcf";
	    }
	    die "ERROR: No 1000g database in $install_dir/database\n" unless -e $target;
	} elsif ($type=~/indel/) {
	    if ($build eq 'hg19') {
		$target="$install_dir/database/Mills_and_1000G_gold_standard.indels.b37.vcf";
	    } elsif ($build eq 'hg18') {
		$target="$install_dir/database/Mills_and_1000G_gold_standard.indels.b36.vcf";
	    }
	    die "ERROR: No Mills and 1000G indel database in $install_dir/database\n" unless -e $target;
	}
	
    }
    return $target;
}
sub install_R_package 
{
    my ($exe_rscript,$package,$libpath)=@_;
    mkdir $libpath unless -d $libpath;
    !system("rm -rf $libpath/*") or die "ERROR: Failed to clean $libpath. Outdated package may exist.\n";
    return ! system("$exe_rscript --vanilla -e 'install.packages(\"$package\",lib=\"$libpath\")'");
}

sub phred_score_check
{
    my ($readcount,@files)=@_;
    warn "Checking Phred score scheme: @files\n";
    #count bases in 0-32&127,33-58,59-126, 3 bins in total
    # 1st bin	1	0	0	0
    # 2nd bin	*	1	0	0
    # 3rd bin	*	*	0	1
    # ouput	error	33	error	64
    my @phred64;
    my @phred33;
    my $count1=0; #counts bases in 0-32&127
    my $count2=0; # counts bases in 33-58
    my $count3=0; # counts bases in 59-126
    my $msg="After examining $readcount reads, unable to recognize base quality score scheme\nPlease manually set it with optin \'-phred\'\n";

    for my $fq (@files)
    {

	my $fh;
	if($fq =~ /\.gz$/i)
	{
	    open $fh, '-|', "gunzip -c $fq" or die "Cannot read $fq: $!\n"; 
	} else
	{
	    open $fh, '<', $fq or die "Cannot read $fq: $!\n"; 
	}
	#disable line counting for speed
	#die "ERROR: not all reads have 4 lines\n$msg\n" unless &countline($fq) % 4 ==0; #this could be wrong since we didn't multiply total number of reads by 4 and compare the result with line_count
	while (<$fh>)
	{
	    next unless $. % 4==0; # $. current line number, base quality appears on 4th line
	    chomp;
	    my @ascii=unpack("C*",$_);
	    #print "DEBUG: @ascii\n";
	    for my $num(@ascii) 
	    {
		if ($num >= 0 && $num <= 32 || $num == 127)
		{
		    $count1++;
		} elsif ($num >= 33 && $num <= 58)
		{
		    $count2++;
		} elsif ($num >= 59 && $num <= 126)
		{
		    $count3++;
		} else
		{
		    die "ERROR: Illegal character with ASCII $num found in $fq\n$msg\n";
		}

	    }
	    last if $.>$readcount*4;

	}
	close $fh;

	#warn "$fq $readcount reads have $count35 phred35 scocres, $count64 phred64 scores\n";
	if ($count1 != 0)
	{
	    die "ERROR: $count1 ASCII 0-32 or 127 characters found in $fq\n$msg\n";
	}
	elsif ($count1 == 0 && $count2 == 0 && $count3 == 0)
	{
	    die "ERROR: no character in ASCII 0-127 in $fq\n$msg\n";
	}
	elsif ($count1 == 0 && $count2 >= 1)
	{
	    push @phred33,$fq;
	}
	elsif ($count1 ==0 && $count2 ==0 && $count3 >=1)
	{
	    warn "NOTE: After examing $readcount reads, $fq is likely to have ASCII+64 score\n";
	    push @phred64,$fq;
	} else
	{
	    die "ERROR: $count1, $count2, $count3 characters in ASCII 0-32&127, 33-58 and 59-126 in $fq, respectively.\n$msg\n";
	}
    }

    if (@phred64==@files)
    {	return 64   }
    elsif (@phred33==@files)
    {	return 33    }
    else 
    {
	warn "@phred64 are ASCII+64 encoded\n@phred33 are ASCII+33 encoded\n";
	die "ERROR: All FASTQ files must have the same base quality score scheme\n";
    }
}
sub sys_which
{
    my $exe=shift;
    return system("which $exe 1>/dev/null 2>/dev/null") ? 0 : 1;
}
sub countline
{
    #count non-empty lines and return total line count
    #usage: $result=&countline($file)
    my $file=shift;
    warn "NOTICE: Counting non-empty lines in $file\n";
    my $line_count;
    if($file =~ /\.gz$/i)
    {
	$line_count = `gunzip -c $file | grep -Pv \'^\\s*\$\' | wc -l`;
    } else
    {
	$line_count = `grep -Pv \'^\\s*\$\' $file | wc -l`;
    }
    chomp $line_count;
    return $line_count;
}
sub phred64to33
{
    #usage: @outfiles=&phred64to33(\@in_file_names,\@outfile) or die
    my $half=(scalar @_)/2;
    my @in=@_[0..$half-1];
    my @out=@_[$half..$#_];
    my $result;

    for my $i (0..$#in)
    {
	my $infile=$in[$i];
	my $outfile=$out[$i];
	warn "ERROR: input file $infile is the same as the output file $outfile\n" and return 0 if $infile eq $outfile;
	warn "ERROR: not all reads have 4 lines\n" and return 0 unless &countline($infile) % 4 ==0; #this could be wrong since we didn't multiply total number of reads by 4 and compare the result with line_count
	warn "Begin converting $infile to standard Phred score\n";
	my ($fhin,$fhout);

	$infile =~ /\.gz$/i ? 
	(open $fhin,"-|","gunzip -c $infile" or die "Cannot open $infile: $!\n"):
	(open $fhin,"<",$infile or die "Cannot open $infile: $!\n");

	$outfile =~ /\.gz$/i ?
	(open $fhout,"|-","gzip -c - > $outfile" or die "Cannot write $outfile\n"):
	(open $fhout,">",$outfile or die "Cannot write $outfile\n");


	while (<$fhin>)
	{
	    if (/^@/)
	    {
		#assume coding sanity has been checked before
		print $fhout $_; #title line
		$_=<$fhin>;
		print $fhout $_; #bases
		$_=<$fhin>;
		print $fhout "+\n";
		$_=<$fhin>;
		chomp;
		my @qual;
		@qual=unpack("C*",$_);
		for my $q(@qual) 
		{$q -= 31 } #64-33
		my $newqual=pack("C*",@qual);
		print $fhout "$newqual\n";
	    }

	}
	close $fhin;
	close $fhout;
	warn "Done\n";
    }
    return 1;
}

sub uniq
{
    #Usage: @uniq=&Utils::uniq(@array)
    #return unique elements in an array
    my @array=@_;
    my %seen;
    return grep {! $seen{$_}++} @array;

}

sub readBED
{
    my $bed=shift;
    my @out;
    open IN,'<',$bed or die "Cannot read $bed: $!\n";
    while(<IN>)
    {
	next if /^browser|^#|^track/;
	next unless /^([^\t]+)\t(\d+)\t(\d+)/;
	if ($3>$2)
	{
	    push @out,[$1,$2,$3];
	} else
	{
	    push @out,[$1,$3,$2];
	}
    }
    close IN;
    return @out;
}

sub readFastaIdx
{
    my $fai=shift;
    my %return;
    open IN,"<",$fai or (carp "Failed to read $fai: $!\n" and return undef);
    while (<IN>)
    {
	my @f=split /\t/;
	die "5 fields expected at line $. of $fai: $_\n" unless @f==5;
	my ($id,$len,$offset,$nchar_ln,$nbyte_ln)=@f;

	$return{$id}={
	    length=>$len, #length of contig
	    offset=>$offset, #offset where first character in that contig appears
	    nchar_ln=>$nchar_ln, #number of characters per line
	    nbyte_ln=>$nbyte_ln, #number of bytes per line
	};
    }
    close IN;
    return %return;
}
sub getFastaContig
{
    my $fa=shift;
    my $idx = "$fa.fai";
    my @out;
    if( -f &abs_path_failsafe($idx))
    {
	my %contig=&readFastaIdx($idx);
	@out = keys %contig;
    }
    if(@out == 0)
    {#when failed to read index, read FASTA instead
	open IN,'<',$fa or die "ERROR: failed to read $fa: $!\n";
	while(<IN>)
	{
	    next unless /^>(\S+)/;
	    push @out,$1;
	}
	close IN;
    }
    return @out;
}

sub getBAMHeader
{
    my ($samtools,$bam)=@_;
    my @chr;

    open IN,'-|',"$samtools view -H $bam" or die "Cannot get header of $bam: $!";
    while(<IN>)
    {
	if(/^\@SQ\s+SN:(\S+)\s+LN:(\d+)/)
	{
	    push @chr,[$1,$2];
	}
    }
    close IN;
    return @chr;
}

sub BAMHeader2BED
{
    my $samtools=shift;
    my $bam=shift;
    my @content;

    for my $line(&getBAMHeader($samtools,$bam))
    {
	my ($chr,$len)=@$line;
	push @content,[$chr,"0",$len];
    }
    return &genBED(\@content);
}

sub getBAMSample
{
    my ($samtools,@bam)=@_;
    my %sample;

    for my $i(@bam)
    {
	open IN,'-|',"$samtools view -H $i" or die "Cannot get header of $i: $!";
	while(<IN>)
	{
	    if (/^\@RG/)
	    {
		for my $i(/SM:(\S+)/g)
		{
		    $sample{$i}=1 unless defined $sample{$i};
		}
	    }
	}
	close IN;
    }
    my @sample=keys %sample;
    if (@sample>=1)
    {
	return wantarray? @sample:$sample[0];
    } else
    {
	return undef;
    }
}

sub getVCFSample
{
    my $vcf=shift;
    my @sample;

    open IN,'<',$vcf or die "Failed to read $vcf: $!\n";
    while (<IN>)
    {
	if (/^#CHROM/)
	{
	    chomp;
	    my @f=split /\t/;
	    @f>=9 or die "At least 9 fields expected in $vcf header: $_\n";
	    map {shift @f} (0..8);
	    @sample=@f;
	    last;
	}
    }
    close IN;
    return @sample;
}

sub bed2total
{
    my $bed=shift;
    my @region=&readBED($bed);
    my $total_len=0;

    for (@region)
    {
	my ($chr,$start,$end)=@{$_};
	$total_len += ($end-$start); #0 start,1 end
    }
    return $total_len;
}

sub samSQ2vcf
{
    my $file=shift;
    my @out;

    open IN,'<',$file or die "Failed to open $file: $!\n";
    while (<IN>)
    {
	#example input
	#@SQ     SN:GL000192.1   LN:547496
	#example output
	##contig=<ID=1,length=249250621>
	next unless /^\@SQ/;
	my ($id,$ln) = /^\@SQ\tSN:([^\t]+)\tLN:(\d+)/;
	push @out,"##contig=<ID=$id,length=$ln>";
    }
    close IN;
    return @out;
}

sub parsePipeline
{
    my $file=shift; #advanced_config file
    my @return;

    my $program; #this declaration overlaps later declaration but they don't conflict
    my $subprogram;
    my %options;

    my $program_enable;
    my $level=0;
    my $exclusive_flag=0; #record whether a level requies exclusive program
    my $mandatory_flag=0; #record whether a level is mandatory
    my $enabled_mandatory_count;
    my $enabled_exclusive_count;

    open IN,'<',$file or die "Cannot read $file: $!\n";

    while(<IN>)
    {
	next if /(^#)|(^go_)|(^\s*$)/i;
	#entering next program
	if (/^\d+[pP][a-zA-Z]?_/)
	{
	    if (! /^${level}p/i)
	    {
		die "ERROR: Mandatory program disabled at level $level\nNOTICE: in configuration, any line beginning with 'P'(upper-case) should ALWAYS be enabled (=1). SeqMule will skip that step if it is unnecessary, though.\n" if ($mandatory_flag && $enabled_mandatory_count<1);
		die "ERROR: Multiple exclusive programs enabled at level $level\n" if ($exclusive_flag && $enabled_exclusive_count>1);
		($level)= /^(\d+)p/i;

		$enabled_mandatory_count=0;
		$enabled_exclusive_count=0;
		$mandatory_flag=0;
		$exclusive_flag=0;
	    }
	    #save command, reset program and option related global variables
	    push @return,[$program,$subprogram,{%options}] if ($program_enable); #braces are necessary: only pass a copy, not the original hash
	    $program=undef;
	    $subprogram=undef;
	    %options=();
	    $program_enable=0;
	}
	#nonmandatory exclusive programs
	if (/^\d+p[xX]_/)
	{
	    $exclusive_flag=1; #while this flag is changed at each program, it is actually level-wide
	    ($program,$subprogram,$program_enable)= /^\d+p[xX]_([A-Za-z0-9]+)_*([A-Za-z0-9]*)=(.*?)(\s+|#|$)/; #subprogram is optional, so use '*' instead of '+' in regex
	    next unless $program_enable;
	    $enabled_exclusive_count++;
	}
	elsif (/^\d+P[xX]_/)
	{
	    $mandatory_flag=1;
	    $exclusive_flag=1;
	    ($program,$subprogram,$program_enable)= /^\d+P[xX]_([A-Za-z0-9]+)_*([A-Za-z0-9]*)=(.*?)(\s+|#|$)/;
	    next unless $program_enable;
	    $enabled_mandatory_count++;
	    $enabled_exclusive_count++;
	}
	elsif (/^\d+p_/)
	{
	    ($program,$subprogram,$program_enable)= /^\d+p_([A-Za-z0-9]+)_*([A-Za-z0-9]*)=(.*?)(\s+|#|$)/;
	    next unless $program_enable;
	}
	elsif (/^\d+P_/)
	{
	    $mandatory_flag=1;
	    ($program,$subprogram,$program_enable)= /^\d+P_([A-Za-z0-9]+)_*([A-Za-z0-9]*)=(.*?)(\s+|#|$)/;
	    next unless $program_enable;
	    $enabled_mandatory_count++;
	}
	elsif (/^o_/i)
	{
	    next unless $program_enable;
	    die "ERROR: No program name. Possible reason: no program before options\n" unless $program;
	    my ($option_name,$option_value)= /[oO]_${program}_([a-zA-Z0-9]+)=(.*?)(\s*#|\s*$)/;
	    $option_value=~s/\t/ /g and warn "WARNING: Tabs will be converted to spaces for option <<$option_name>> at line $. of $file\n" if $option_value=~/\t/;

	    die "ERROR: Failed to capture option name. Legal option looks like 'o_program_option=1': $_\n" unless defined $option_name && $option_name ne "";
	    die "ERROR: $option_name is mandatory\n" if (/O_/ && $option_value eq "");
	    $options{$option_name}=$option_value;
	    ($option_name,$option_value)=();
	} else { die "Unknown prefix in advanced_config: $_\n"}
    }
    close IN;
    #last check
    {
	die "ERROR: Mandatory program disabled at LAST level\n" if ($mandatory_flag && $enabled_mandatory_count<1);
	die "ERROR: Multiple exclusive programs enabled at LAST level\n" if ($exclusive_flag && $enabled_exclusive_count>1);
	$exclusive_flag=0;
	$mandatory_flag=0;
	if ($program_enable)
	{
	    push @return,[$program,$subprogram,{%options}];
	    $program=undef;
	    $subprogram=undef;
	    %options=();
	    $program_enable=0;
	}
    }
    return @return;
}

sub getProgramExe
{
    my %exe=(
	fastqc          =>      "fastqc",
	bwamem          =>      "bwa",
	bwa             =>      "bwa",
	bowtie2         =>      "bowtie2",
	bowtie          =>      "bowtie",
	soap            =>      "soap",
	samtools        =>      "samtools",
	gatklite        =>      "GenomeAnalysisTKLite.jar",
	gatk            =>      "GenomeAnalysisTK.jar",
	varscan         =>      "varscan.jar",
	freebayes       =>      "freebayes",
	snver           =>      "SNVerIndividual.jar",
	soapsnp         =>      "soapsnp",
	vt		=>      "vt",
	snap		=>	"snap",
    );
    my $program=shift;

    if (defined $exe{lc $program})
    {
	return $exe{lc $program};
    } else
    {
	return $program;
    }
}

sub getProgramAlias
{
    my %alias=(
	fastqc          =>      "FastQC",
	bwamem          =>      "BWA-MEM",
	bwa             =>      "BWA-BACKTRACK",
	bowtie2         =>      "Bowtie2",
	bowtie          =>      "Bowtie",
	soap            =>      "SOAPAligner",
	samtools        =>      "SAMtools",
	picard          =>      "Picard",
	gatklite        =>      "GATKLite",
	gatk	    	=>      "GATK",
	varscan         =>      "VarScan",
	freebayes       =>      "FreeBayes",
	snver           =>      "SNVer",
	soapsnp         =>      "SOAPsnp",
	java	    =>      "java",
	tabix	    =>	    "tabix",
	bgzip	    =>	    "bgzip",
	snap		=>	"SNAP",
    );

    my $program=shift;

    if (defined $alias{lc $program})
    {
	return $alias{lc $program};
    } else
    {
	return "NA";
    }
}

sub getProgramVersion
{
    my $loc=shift;
    my $java=shift;
    my $version;

    if ($loc =~/GenomeAnalysisTKLite\.jar$|GenomeAnalysisTK\.jar$/i)
    {
	$version=`$java -Xmx100m -jar $loc --help 2>&1`; 
	if($version=~/Genome\s*Analysis\s*Toolkit\s*\(GATK\)\s*v([\w\.\-]+)/i)
	{
	    return $1;
	}
    } elsif ($loc =~/VarScan\.jar$/i)
    {
	$version=`$java -Xmx100m -jar $loc 2>&1`; 
	if($version=~/VarScan v([\w\.\-]+)/i)
	{
	    return $1;
	}
    } elsif ($loc =~/bwa$|bwamem$/i)
    {
	$version=`$loc 2>&1`;
	if ($version=~/Version:\s*([\w\.\-]+)/i)
	{
	    return $1;
	}
    } elsif ($loc =~/sortsam\.jar$/i)
    {
	$version=`$java -Xmx100m -jar $loc 2>&1`;
	if ($version=~/Version:\s*([\w\.\-]+)/i)
	{
	    return $1;
	}
    } elsif ($loc =~/fastqc$/i)
    {
	$version=`$loc --version 2>&1`;
	if ($version=~/FastQC\s*v([\w\-\.]+)/i)
	{
	    return $1;
	}
    } elsif ($loc=~/bowtie2$/i)
    {
	$version=`$loc --version 2>&1`;
	if ($version=~/version\s*([\w\-\.]+)/i)
	{
	    return $1;
	}
    } elsif ($loc=~/bowtie$/i)
    {
	$version=`$loc --version 2>&1`;
	if ($version=~/version\s*([\w\-\.]+)/i)
	{
	    return $1;
	}
    } elsif ($loc=~/soap$/i)
    {
	$version=`$loc 2>&1`;
	if ($version=~/Version:\s*([\w\-\.]+)/i)
	{
	    return $1;
	}
    } elsif ($loc=~/samtools$/i)
    {
	$version=`$loc 2>&1`;
	if ($version=~/Version:\s*([\w\-\.]+)/i)
	{
	    return $1;
	}
    } elsif ($loc=~/freebayes$/i)
    {
	$version=`$loc 2>&1`;
	if ($version=~/version:\s*v([\w\-\.]+)/i)
	{
	    return $1;
	}
    } elsif ($loc=~/SNVerIndividual\.jar$/i)
    {
	return "0.5.3";#no version number found inside program, use the current latest version
    } elsif ($loc=~/soapsnp$/i)
    {
	return "1.03";#no version number found, use the current latest version
    } elsif ($loc=~/snap$/i)
    {
	$version=`$loc 2>&1`;
	if ($version=~/version\s*([\w\-\.]+)\.?/i)
	{
	    my $version_num = $1;
	    $version_num =~ s/\.+$//;
	    return $version_num;
	}
    }

    return "NA";
}

sub get_gatk_nt
{
    my ($total,$gatk)=@_;
    if ($total>= $gatk)
    {
	return $gatk;
	warn "NOTICE: Set GATK genotype calling threads to $gatk for safety\n" if $total>1;
    } else
    {
	return $total;
    }
}

sub get_bam_size
{
    my $max_size=0;
    map { $max_size=-s $_ if -s $_>$max_size} @_;
    return $max_size;
}

sub callers2names
{
    my @return;
    my %nametable=(
	gatklite => 'GATKLite_UnifiedGenotyper',
	gatk_ug => 'GATK_UnifiedGenotyper',
	gatk_hc => 'GATK_HaploTypeCaller',
	samtools => 'SAMtools',
	snver => 'SNVer',
	freebayes => 'FreeBayes',
	varscan => 'VarScan',
	soapsnp => 'SOAPsnp',
	consensus => 'Consensus',
    );
    for (@_)
    {
	push @return,$nametable{$_};
    }

    return @return;
}

sub compareChr
{
    #compare contig name and length (if possible) in two files in particular format combinations
    #1 for match, 0 for mismatch, 2 for match after adding or removing 'chr'
    my %opt=%{shift @_};
    my $samtools=$opt{samtools};
    my $type1=$opt{type1};
    my $type2=$opt{type2};
    my $file1=$opt{file1};
    my $file2=$opt{file2};
    my $code=1;

    warn "NOTICE: checking contig(chromosome) name consistency in $file1 and $file2.\n";
    if ($type1 eq 'fasta' && $type2 eq 'bed' or $type1 eq 'bed' && $type2 eq 'fasta')
    {
	#return 1 if all contigs in BED show up in FASTA, return 2 if previous condition becomes true after removing 'chr' in contig name, otherwise return 0
	my %fa_contig;
	my %bed_contig;
	#hash will discard duplicate elements

	if ($type1 eq 'fasta')
	{
	    %fa_contig=map {($_ => '1')} &getFastaContig($file1);
	    %bed_contig= map { ($$_[0] => '1') }&readBED($file2);
	} else
	{
	    %fa_contig=map {($_ => '1')} &getFastaContig($file2);
	    %bed_contig= map { ($$_[0] => '1') }&readBED($file1);
	}

	&chrNamingConsistencyCheck(keys %bed_contig);
	for my $contig(keys %bed_contig)
	{
	    unless(exists $fa_contig{$contig})
	    {
		if ($contig=~/^chr/)
		{
		    $contig=~s/^chr//;
		}else
		{
		    $contig=~s/^/chr/;
		}

		if (exists $fa_contig{$contig})
		{
		    $code=2;
		} else
		{
		    $code=0;
		    last;
		}
	    }
	}
    } elsif ($type1 eq 'bam' && $type2 eq 'bed' or $type1 eq 'bed' && $type2 eq 'bam')
    {
	#return 1 if all contigs in BED show up in BAM, return 2 if previous condition becomes true after removing 'chr' in contig name, otherwise return 0
	croak "ERROR: no samtools for BAM contig comparison.\n" unless $samtools;

	my %bam_contig;
	my %bed_contig;
	#hash will discard duplicate elements

	if ($type1 eq 'bam')
	{
	    %bam_contig= map { ($$_[0] => $$_[1])} &getBAMHeader($samtools,$file1);
	    %bed_contig= map { ($$_[0] => '1') }&readBED($file2);
	} else
	{
	    %bam_contig= map { ($$_[0] => $$_[1])} &getBAMHeader($samtools,$file2);
	    %bed_contig= map { ($$_[0] => '1') }&readBED($file1);
	}

	#check if all contigs have consistent naming format: either preceded by 'chr' or not
	#uppercase in 'chr' not allowed
	&chrNamingConsistencyCheck(keys %bed_contig);
	for my $contig(keys %bed_contig)
	{
	    unless(exists $bam_contig{$contig})
	    {
		if ($contig=~/^chr/)
		{
		    $contig=~s/^chr//;
		} else
		{
		    $contig=~s/^/chr/;
		}

		if (exists $bam_contig{$contig})
		{
		    $code=2;
		} else
		{
		    $code=0;
		    last;
		}
	    }
	}
    } elsif ($type1 eq 'bam' && $type2 eq 'fasta' or $type1 eq 'fasta' && $type2 eq 'bam')
    {
	#return 1 if all contigs in BAM show up in FASTA, return 2 if previous condition becomes true after removing 'chr' in contig name, otherwise return 0
	croak "ERROR: no samtools for BAM contig comparison.\n" unless $samtools;

	my %fa_contig;
	my %bam_contig;
	#hash will discard duplicate elements

	if ($type1 eq 'bam')
	{
	    %bam_contig= map { ($$_[0] => $$_[1])} &getBAMHeader($samtools,$file1);
	    %fa_contig=map {($_ => '1')} &getFastaContig($file2);
	} else
	{
	    %bam_contig= map { ($$_[0] => $$_[1])} &getBAMHeader($samtools,$file2);
	    %fa_contig=map {($_ => '1')} &getFastaContig($file1);
	}

	&chrNamingConsistencyCheck(keys %bam_contig);

	for my $contig(keys %bam_contig)
	{
	    unless(exists $fa_contig{$contig})
	    {
		if ($contig=~/^chr/)
		{
		    $contig=~s/^chr//;
		} else
		{
		    $contig=~s/^/chr/;
		}
		if (exists $fa_contig{$contig})
		{
		    warn "inconsistent with chr: $contig and $fa_contig{$contig}\n";
		    $code=2;
		} else
		{
		    warn "inconsistent: $contig and $fa_contig{$contig}\n";
		    $code=0;
		    last;
		}
	    }
	}
    } elsif ($type1 eq 'bam' && $type2 eq 'bam')
    {
	#return 1 if all contigs match in both BAMs, return 2 if previous condition becomes true after removing 'chr' in one set of contig names, otherwise return 0
	croak "ERROR: no samtools for BAM contig comparison.\n" unless $samtools;

	my    %bam_contig1= map { ($$_[0] => $$_[1])} &getBAMHeader($samtools,$file1);
	my  %bam_contig2= map { ($$_[0] => $$_[1])} &getBAMHeader($samtools,$file2);
	#hash will discard duplicate elements

	&chrNamingConsistencyCheck(keys %bam_contig1);
	&chrNamingConsistencyCheck(keys %bam_contig2);

	for my $contig(keys %bam_contig1)
	{
	    unless(exists $bam_contig2{$contig})
	    {
		if ($contig=~/^chr/)
		{
		    $contig=~s/^chr//;
		} else
		{
		    $contig=~s/^/chr/;
		}
		if (exists $bam_contig2{$contig})
		{
		    $code=2;
		} else
		{
		    $code=0;
		    last;
		}
	    }
	}
	for my $contig(keys %bam_contig2)
	{
	    unless(exists $bam_contig1{$contig})
	    {
		if ($contig=~/^chr/)
		{
		    $contig=~s/^chr//;
		} else
		{
		    $contig=~s/^/chr/;
		}
		if (exists $bam_contig1{$contig})
		{
		    $code=2;
		} else
		{
		    $code=0;
		    last;
		}
	    }
	}
    } else
    {
	die "ERROR: Unrecognized type for contig comparison: $type1,$type2\n";
    }
    return $code;
}

sub addOrRmChrInBED
{
    #add or remove 'chr' in contig name of BED file
    my $bed=shift;
    my $out=shift;
    my @content;

    for (&readBED($bed))
    {
	my @f=@{$_};
	if ($f[0]=~/^chr/)
	{
	    $f[0]=~s/^chr//;
	    push @content,[$f[0],$f[1],$f[2]];
	} else
	{
	    push @content,["chr$f[0]",$f[1],$f[2]];
	}
    }
    return &genBED(\@content,$out);
}

sub addOrRmChrInBAM
{
    #add or remove 'chr' in contig name of BAM file
    croak "ERROR: expect samtools,bam and output file.\n" unless @_==3;
    my $samtools=shift;
    my $bam=shift;
    my $out=shift;
    my $tmpsam="/tmp/$$".rand($$).".tmp.sam";

    open SAM,'>',$tmpsam or die "ERROR: Failed to write to $tmpsam: $!\n";
    open HEADER,'-|',"$samtools view -H $bam" or die "ERROR: Failed to get $bam header: $!\n";
    while(<HEADER>)
    {
	if (/^\@SQ/)
	{
	    if (/SN:chr[^\t]+/)
	    {
		s/SN:chr([^\t]+)/SN:$1/;
	    } elsif (/SN:[^\t]+/)
	    {
		s/SN:([^\t]+)/SN:chr$1/;
	    }  else
	    {
		die "ERROR: malformed BAM header:$_ in $bam\n";
	    }
	}
	print SAM $_;
    }
    close SAM;
    !system("$samtools reheader $tmpsam $bam>$out") or die "ERROR: Failed to reheader $bam: $!\n";
}
sub checkOrCreateTmpdir
{
    my $tmpdir=shift;
    if($tmpdir)
    {
	mkdir $tmpdir or croak "Failed to create $tmpdir: $!\n" unless -d $tmpdir;
	return 1;
    } else
    {
	croak "ERROR: No tmpdir specified\n";
    }
}

sub chrNamingConsistencyCheck
{
    #check if all contigs have consistent naming format: either preceded by 'chr' or not
    #uppercase in 'chr' not allowed
    my $chr_toggle;
    for my $contig(@_)
    {
	if ($contig=~/^chr/)
	{
	    die "ERROR: some contig names have 'chr' while some do not. Inconsistency has to be resolved.\n" if defined $chr_toggle && $chr_toggle==0;
	    $chr_toggle=1 unless defined $chr_toggle;
	} elsif ($contig=~/^chr/i)
	{
	    die "ERROR: No uppercase allowed in 'chr' of a contig name: $contig\n";
	}else
	{
	    die "ERROR: some contig names have 'chr' while some do not. Inconsistency has to be resolved.\n" if defined $chr_toggle && $chr_toggle==1;
	    $chr_toggle=0 unless defined $chr_toggle;
	}
    }
}

sub getRG
{
    #return @RG tag and value in hash for each readgroup ID
    my $samtools=shift;
    my $bam=shift;
    my %return;

    #@RG	ID:READGROUP	SM:SAMPLE	PL:ILLUMINA
    my @rg=`$samtools view -H $bam | grep '^\@RG'`;
    for my $rgln(@rg)
    {
	$rgln=~s/[\r\n]+$//;
	$rgln=~s/^\@RG\t+//;
	die "ERROR: Readgroup ID missing or malformatted in $bam.\n" unless $rgln=~/ID:([^\t]+)/;
	my $id=$1;
	die "ERROR: Duplicate readgroup ID in $bam: $id.\n" if defined $return{$id};
	my @f=split /\t/,$rgln;
	for my $i(@f)
	{
	    next if $i=~/ID:/; #skip ID
	    die "ERROR: malformated tag $i in $bam\n" unless $i=~/:/;
	    my ($tag,$value)=split /:/,$i;
	    push @{$return{$id}{$tag}},$value;
	}
    }
    return %return;
}

sub checkDuplicateRGID
{
    my $samtools=shift @_;
    my @bam=@_;
    my %rgid;

    warn "NOTICE: checking BAM \@RG ID...\n";
#prepare @RG
    for my $bam(@bam)
    {
	#here BAM is an object
	my %onebam_rg=&getRG($samtools,$bam->file());
	for my $id(keys %onebam_rg)
	{
	    warn "WARNING: Duplicate readgroup ID found: $id.\n" and return 1 if defined $rgid{$id};
	    $rgid{$id}=1;
	}
    }
    return undef;
}
sub splitRegion
{

    #split regions in BAM header or BED file into n pieces
    my $MULTIPLIER=5; #n*multiplier is the total number of parts, each part is then assigned to n BED files by rotating, this way, the reads will be more uniformly distributed across regions defined by the new BED files.
    my $MINBIN=50_000; #minimum length for a part (total/n/multiplier), assume max read len=1000, 1% error rate
    #my $MAXBIN=5_000_000; #maximum length for a part, increase uniformity for large regions (eg genome)
    my $MAXBIN=1_000_000; #maximum length for a part, increase uniformity for large regions (eg genome)
    my %opt=%{shift @_};
    my $n=$opt{threads};
    my $bed=$opt{bed};
    my $bam=$opt{bam};
    my $prefix=$opt{prefix};
    my $samtools=$opt{samtools};
    my $rm=$opt{rm};
    my @small_bed=map { ($prefix?$prefix:"temp_split$$".rand($$)).".$_.tmp.bed" } (1..$n);
    my @intervals;

    unless (defined $bed)
    {
	#if user doesn't give BED, we convert BAM header into BED
	$bed=&BAMHeader2BED($samtools,$bam);
    }

    #if split region(total region/n/multiplier) is too small, refuse to split because reads will not be broken during splitting, splitting BAM into small regions will result in read duplicates
    my $total=&bed2total($bed);
    my $max_n=int $total/$MULTIPLIER/$MINBIN;
    if ($n>$max_n)
    {
	warn "ERROR: The region after splitting will become very small, and possibly result in biased read count.\n";
	if ($max_n>1)
	{
	    die "NOTICE: Please use at most $max_n threads, or do NOT use QUICK mode.\n";
	} else
	{
	    die "NOTICE: Please do NOT use QUICK mode.\n";
	}
    }

    my $i=0;
    my $onerun=$MAXBIN>$total/$MULTIPLIER/$n? (int $total/$MULTIPLIER/$n):$MAXBIN; #choose smaller bin
    my $remain=$onerun;

    for my $line(&readBED($bed))
    {
	#0-based start, 1-based end
	my ($chr,$start,$end)=@$line;
	my $last_pos=$start;
	my $pos=$last_pos+$remain;
	my $len=$end-$start;

	while ($len>=$remain)
	{
	    $intervals[$i].="$chr\t$last_pos\t$pos\n";
	    $last_pos=$pos;
	    $pos+=$remain;
	    $len-=$remain;
	    $i = ($i+1) % $n;
	    $remain=$onerun;
	}

	if ($len!=0 && $len<$remain)
	{
	    $remain-=$len;
	    $intervals[$i].="$chr\t$last_pos\t$end\n";
	}
    }

    for my $i(0..$#small_bed)
    {
	open OUT,'>',$small_bed[$i] or die "ERROR: Failed to write to $small_bed[$i]: $!\n";
	print OUT $intervals[$i];
	close OUT;
    }
    if($rm)
    {
	!system("rm -rf @small_bed") or croak "Failed to remove @small_bed: $!\n";
    } else
    {
	return @small_bed;
    }
}

sub fa2BED
{
    my $fa=shift;
    my $idx = "$fa.fai";
    my @content;
    #get contig length from .fai
    if( -f &abs_path_failsafe($idx)) {
	my %contig=&readFastaIdx($idx);
	for my $i(keys %contig) {
	    push @content,[$i,0,$contig{$i}->{length}];
	}
    }

    #get contig length from FASTA
    if(@content == 0) {
	open IN,'<',$fa or die "ERROR: Failed to read $fa: $!\n";
	my $len=0;
	while(<IN>) {
	    if (/^>(\S+)/) {
		if ($len!=0) {
		    #update previous contig length
		    push @{$content[$#content]},$len;
		    $len=0;
		}
		#set contig name and lower boundary
		push @content,[$1,0];
	    } else {
		chomp;
		#record length
		$len+=length;
	    }
	}
	push @{$content[$#content]},$len;
	close IN;
    }
    return &genBED(\@content);
}

sub SOAPIndex2Contig
{
    my $ann=shift;
    my @contig;
    croak "ERROR: .ann file expected: $ann\n" unless ($ann && $ann=~/\.ann$/);

    open IN,'<',$ann or die "ERROR: Failed to read $ann: $!\n";
    my $first=<IN>;
    my ($total_len,$num_chr,$seed)=split /\t/,$first;

    #show length of name, and chromosomal name
    for my $i(1..$num_chr)
    {
	my $line=<IN>;
	chomp $line;
	my ($nameLen,$chrName)=split /\t/,$line;
	$contig[$i-1]=[$chrName];
    }

    #number of blocks
    my $numOfBlock=<IN>;

    #show blockstart,end,ori for each chromosome (numbered 0 to ..)
    my %contig_block;
    while(<IN>)
    {
	my ($no,$start,$end,$ori)=split /\t/;
	$contig_block{$no}=$end;
    }
    close IN;

    #calculate contig length based on block start/end, 0-based
    for my $i(0..$#contig)
    {
	if ($i==0)
	{
	    push @{$contig[$i]},($contig_block{$i}+1);
	} else
	{
	    push @{$contig[$i]},($contig_block{$i}-$contig_block{$i-1});
	}
    }

    return @contig;
}
sub rmOverlapBED
{
    my $bed=shift;
    my $newbed=shift;

    my @region=&readBED($bed);
    @region= sort 
    { 
	#$$a[0] chr
	#$$a[1] start
	#$$a[2] end
	if ($$a[0] eq $$b[0])
	{
	    if ($$a[1] == $$b[1])
	    {
		return $$a[2] <=> $$b[2];
	    } else
	    {
		return $$a[1] <=> $$b[1];
	    }
	} else
	{
	    return $$a[0] cmp $$b[0];
	}
    } @region;

    my %region;
    for my $i(@region)
    {
	push @{$region{$$i[0]}},[$$i[1],$$i[2]];
    }

    for my $chr(keys %region)
    {
	my ($prev_start,$prev_end);
	my $prev;
	for my $i( @{$region{$chr}})
	{
	    my ($start,$end)=@$i;
	    if (defined $prev_start && defined $prev_end && $start<=$prev_end && $end>=$prev_start)
	    {
		#warn "NOTICE: There are overlapping regions in $bed: $chr\t$start\t$end\n";
		#clean previous line
		@$prev=();
		#update current line with largest continuous region
		$start=$start>$prev_start?$prev_start:$start;
		$end=$end>$prev_end?$end:$prev_end;
		@$i=($start,$end);
	    }
	    $prev=$i;
	    $prev_start=$start;
	    $prev_end=$end;
	}
    }
    #prepare output
    my @content;
    for my $chr(keys %region)
    {
	for my $i(@{$region{$chr}})
	{
	    next unless @$i; #skip empty line
	    my ($start,$end)=@$i;
	    push @content,[$chr,$start,$end];
	}
    }
    return &genBED(\@content,$newbed);
}
sub checkOverlapBED
{
    my $bed=shift;

    my @region=&readBED($bed);
    @region= sort 
    { 
	#$$a[0] chr
	#$$a[1] start
	#$$a[2] end
	if ($$a[0] eq $$b[0])
	{
	    if ($$a[1] == $$b[1])
	    {
		return $$a[2] <=> $$b[2];
	    } else
	    {
		return $$a[1] <=> $$b[1];
	    }
	} else
	{
	    return $$a[0] cmp $$b[0];
	}
    } @region;

    my %region;
    for my $i(@region)
    {
	push @{$region{$$i[0]}},[$$i[1],$$i[2]];
    }

    for my $chr(keys %region)
    {
	my ($prev_start,$prev_end);
	my $prev;
	for my $i( @{$region{$chr}})
	{
	    my ($start,$end)=@$i;
	    if (defined $prev_start && defined $prev_end && $start<=$prev_end && $end>=$prev_start)
	    {
		warn "NOTICE: There are overlapping regions in $bed: $chr\t$start\t$end\n";
		return 1;
		#clean previous line
		@$prev=();
		#update current line with largest continuous region
		$start=$start>$prev_start?$prev_start:$start;
		$end=$end>$prev_end?$end:$prev_end;
		@$i=($start,$end);
	    }
	    $prev=$i;
	    $prev_start=$start;
	    $prev_end=$end;
	}
    }
}
sub genBED
{
    my $content=shift;
    my $out=shift;
    $out=$out||"/tmp/$$".rand($$).".tmp.bed";

    open OUT,'>',$out or die "ERROR: Failed to write to $out: $!\n";
    for my $i(@$content)
    {
	print OUT join "\t",@$i;
	print OUT "\n";
    }
    close OUT;
    return $out;
}
sub getNonEmptyVCF
{
    my @vcf=@_;

    @vcf=grep { -f $_ && -s $_ >0 } @vcf;
    for my $i(@vcf)
    {
	my $lc=`grep -v "#" $i | wc -l`;
	$lc=~s/\s+//g;
	if ($lc==0)
	{
	    $i=undef;
	}
    }
    @vcf=grep{$_} @vcf;

    return @vcf;
}
sub parseMendelFix
{
    my $in = shift;
    my %result;
    open IN,'<',$in or croak "ERROR: failed to read $in ($!)\n";
    while(<IN>)
    {
	#example
#ID	NCALL1	CR1	FATHER	FOCALL	FOIBS0	FOIBS1	FOIBS2	FOERROR	MOTHER	MOCALL	MOIBS0	MOIBS1	MOIBS2	MOERROR	TRIOCALL	ADI	PADI	ADO	PADO	NERROR	PPCERROR	NFIX	NCALL2	CR2
#son	45285	0.999	father	45242	533	19804	24905	1.178109e-02	mother	44994	509	20122	24363	1.131262e-02	44559	215	4.825063e-03	853	1.914316e-02	1068	2.396822e-02	899	44759	0.988
	if($.==1)
	{#skip header
	    1;
	} else
	{
	    my @f = split;
	    $result{$f[0]} = {
		ID		=>	$f[0],
		NCALL1		=>	$f[1],
		CR1		=>	$f[2],
		FATHER		=>	$f[3],
		FOCALL		=>	$f[4],
		FOIBS0		=>	$f[5],
		FOIBS1		=>	$f[6],
		FOIBS2		=>	$f[7],
		FOERROR		=>	$f[8],
		MOTHER		=>	$f[9],
		MOCALL		=>	$f[10],
		MOIBS0		=>	$f[11],
		MOIBS1		=>	$f[12],
		MOIBS2		=>	$f[13],
		MOERROR		=>	$f[14],
		TRIOCALL	=>	$f[15],
		ADI		=>	$f[16],
		PADI		=>	$f[17],
		ADO		=>	$f[18],
		PADO		=>	$f[19],
		NERROR		=>	$f[20],
		PPCERROR	=>	$f[21],
		NFIX		=>	$f[22],
		NCALL2		=>	$f[23],
		CR2		=>	$f[24],
	    };
	}
    }
    close IN;
    return \%result;
}
sub cleanup
{ 
    warn "NOTICE: Cleaning up ...\n";
    !system("rm -rf @_") or warn "WARNING: failed to clean up temporary files\n";
};




1;

=head1 Utils

Utils: package with various utilities for downloading, untar, etc.

=head1 SYNOPSIS

use Utils;

Utils::getstore($url,$file_name,$user,$pass);
Utils::md5check($file,$md5hash);
Utils::extract_archive($file_name,$dir);
Utils::config_edit({
		programs        =>      ["P_test","p_postprocess"],
		level           =>      4,
		file            =>      "/home/yunfeiguo/tmp",
		del             =>      15,
	});
Utils::search_db({
			type => "dbsnp",
			target => $dbsnp,
			build => $buildver,
			version => $dbsnpver,
			install_dir => $install_dir,
		})
Utils::search($install_dir,"Rscript")
$phred_scheme=Utils::phred_score_check(readcount,@files);

=head1 AUTHOR

Yunfei Guo

=head1 COPYRIGHT

GPLv3

=cut
