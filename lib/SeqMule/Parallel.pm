package SeqMule::Parallel;
#take a list of commands, total number of cpus, convert them to a script that can be run in parallel
#also contains a subroutine to run the script

use strict;
use warnings;
use Fcntl qw/:flock/;
use File::Spec;

my $debug=0;
my $splitter="-" x 10;

sub writeParallelCMD
{
    my ($install_dir,$file,$cpu_total,@cmd)=@_;
    #@lines is array of arrays, 2nd array consists of [ncpu_request,command]
    my @out;
    my $mod_status=File::Spec->catfile($install_dir,"bin","secondary","mod_status");

    push @out,["#Don't add or remove any line or field",map {""} (1..6)];
    push @out,["#step","command","message","nCPU_requested","nCPU_total","status","pid"]; #pid means job id when qsub is used
    #		0	1	2		3		4	   5	   6

    for my $i(1..@cmd)
    {
	#each element of @cmd is array reference [ncpu_request,msg,command]
	@{$cmd[$i-1]} == 3 or die "3 fields in commands expected.\n";
	my @out_line;
	my $cmd_line=$cmd[$i-1][2]; $cmd_line=~s/\t/    /g;
	die "ERROR: No shell meta characters allowed: $cmd_line\n" if $cmd_line=~/[\?\>\<\|\;\&\$\#\`\(\)]/;
	my $msg=$cmd[$i-1][1];
	#comments are not allowed
	$out_line[0]=$i;
	$out_line[1]="$mod_status $file $i $cmd_line";

	$out_line[2]=$msg; #message about this command
	$out_line[3]=$cmd[$i-1][0]; #ncpu requested
	$out_line[4]=$cpu_total;
	$out_line[5]="waiting";
	$out_line[6]=0;
	push @out,[@out_line];
    }

    open OUT,'>',$file or die "Cannot write to $file: $!";
    for (@out)
    {
	print OUT join("\t",@$_),"\n";
    }
    close OUT;
    warn "NOTICE: Commands written to $file\n";
}

#sub qsub_writeParallelCMD
#{
#    warn "NOT IMPLEMENTED YET\n" and exit;
#
#    my ($install_dir,$file,$cpu_total,$cpu_per_node,@cmd)=@_;
#    #@lines is array of arrays, 2nd array consists of [ncpu_request,command]
#    my @out;
#    my $mod_status=File::Spec->catfile($install_dir,"bin","secondary","mod_status");
#
#    push @out,["#command","nCPU_requested","nCPU_total","status"];
#
#    for my $i(1..@cmd)
#    {
#	#comments are not allowed
#	$out[$i]=[];
#	my $line_no=$i+1;
#	my $cpu_request=$cmd[$i-1][0] or die;
#	my $mem_per_cpu=$cmd[$i-1][2] or die;
#	my $cmd=$cmd[$i-1][1] or die;$cmd=~s/'/'"'"'/; #use string concatenantion to output single quotes
#	die "ERROR: A node doesn't have enough CPUs you requested\n" unless $cpu_request <= $cpu_per_node;
#	die "ERROR: Under SGE mode, single quote not allowed for commands: $cmd" if $cmd =~/'/;
#
#	${$out[$i]}[0]=
#	"echo '".
#	"$mod_status $file $line_no s && ".
#	"if $cmd;".
#	"then $mod_status $file $line_no f;".
#	"else $mod_status $file $line_no e;".
#	"fi".
#	"' | qsub -V -cwd".
#	($cpu_request > 1? " -pe smp $cpu_request -l h_vmem=$mem_per_cpu" : " -l h_vmem=$mem_per_cpu"); #no semicolon here, otherwise this cannot be run in background
#
#	push @{$out[$i]},$cmd[$i-1][0];
#	push @{$out[$i]},$cpu_total;
#	push @{$out[$i]},"waiting";
#    }
#
#    open OUT,'>',$file or die "Cannot write to $file: $!";
#    for (@out)
#    {
#	print OUT join("\t",@$_),"\n";
#    }
#    close OUT;
#    warn "NOTICE: Commands written to $file\n";
#}

sub single_line_exec
{
    die "Usage: &single_line_exec(<script>,<step number>,<command and arguments>)\n" unless @_>=3;

    my ($script,$n,@cmd)=@_;
    my @out;
    my $cmd_string=join(" ",@cmd);
    my $start_time=time;
    my $msg=&getMsg($script,$n);


    #&wait2start($script,$n);
    my $success;
    {
	warn "DEBUG: about to fork for $msg\n" if $debug;
	my $pid=fork;
	if ($pid)
	{
	    #parent
	    &writePID($script,$n,$pid);
	    my $deceased_pid=wait;
	    if ($deceased_pid==$pid)
	    {
		#got the exit status of child
		if ($? == 0)
		{
		    $success=1;
		} else
		{
		    $success=0;
		}
	    } else
	    {
		warn "WARNING: Didn't get child exit status\n";
		$success=0;
	    }
	} elsif (defined $pid)
	{
	    #real execution code
	    exec @cmd or die "ERROR: Command not found: @cmd\n";
	} else
	{
	    $success=0;
	}
    }

    if ($success)
    {
	my $time=`date`;chomp $time;
	my $total_min=&getTotalMin($start_time);

	&start2finish($script,$n);
	warn "[ => SeqMule Execution Status: step $n is finished at $time, $msg, Time Spent at this step: $total_min min]\n\n";
    } else
    {
	my $time=`date`;chomp $time;
	my $total_min=&getTotalMin($start_time);

	&status2error($script,$n);
	die "\n\n${splitter}ERROR$splitter\n[ => SeqMule Execution Status: step $n FAILED at $time, $msg, $total_min min]\n";
    }
}
sub getTotalMin
{
    my $start=shift;
    my $end=time;
    my $total=($end-$start)/60; 
    $total=sprintf("%.1f",$total);
    return $total;
}
sub getMsg
{
    my $file=shift;
    my $n=shift;
    my @lines=&readScript($file);
    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[0] == $n)
	{
	    return $f[2];
	}
    }
    die "ERROR: Can't find message for step $n in $file\n";
}
sub wait2start
{
    my $file=shift;
    my $n=shift;
    my @lines=&readScript($file);

    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[0] == $n)
	{
	    if ($f[5] =~ /waiting/i)
	    {
		$f[5]=~s/waiting/started/i;
	    } else
	    {
		$f[5]="error";
	    }
	    $_=[@f];
	    last;
	}
    }
    &writeChange($file,@lines);
}
sub status2error
{
    my $file=shift;
    my $n=shift;
    my @lines=&readScript($file);

    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[0] == $n)
	{
	    $f[5]="error";
	    $_=[@f];
	    last;
	}
    }
    &writeChange($file,@lines);
}

sub start2finish
{
    my $file=shift;
    my $n=shift;
    my @lines=&readScript($file);

    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[0] == $n)
	{
	    if ($f[5] =~ /started/i)
	    {
		$f[5]=~s/started/finished/i;
	    } else
	    {
		$f[5]="error";
	    }
	    $_=[@f];
	    last;
	}
    }
    &writeChange($file,@lines);
}

sub writePID
{
    my $file=shift;
    my $n=shift;
    my $pid=shift;
    my @lines=&readScript($file);

    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[0] == $n)
	{
	    $f[6] = $pid;
	    $_=[@f];
	    last;
	}
    }
    &writeChange($file,@lines);
}
sub getRunningPID
{
    my $file=shift;
    my @pid;
    my @lines=&readScript($file);

    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[5] eq 'started')
	{
	    push @pid,$f[6];
	}
    }
    return @pid;
}
sub writeChange
{
    my $script=shift;
    my @out=@_;

    open OUT,'+<',$script or die "Cannot write to $script: $!";
    flock OUT,LOCK_EX or die "Failed to lock $script: $!";
    warn "DEBUG: began writing $script!\n" if $debug;
    warn "DEBUG: ".scalar @out." lines to write!\n" if $debug;
    seek OUT,0,0;
    truncate OUT,0;
    map { print OUT join("\t",@{$_}),"\n" } @out;
    flock OUT,LOCK_UN;
    close OUT;
}

sub readScript
{
    my $script=shift;
    my @out;
    open IN,'<',$script or die "Cannot read $script: $!";
    #temporarily remove locking step
    #flock IN,LOCK_EX or die "Failed to lock $script: $!";

    while(<IN>)
    {
	chomp;
	my @f=split(/\t/,$_,-1);
	next unless @f==7;
	push @out,[@f];
    }
    #flock IN,LOCK_UN;
    close IN;
    return @out;
}
sub firstScan
{
#clean up unfinished processes
    my $in=shift;
    my $step=shift;
    my @lines=&readScript($in);
    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if (@f==7)
	{
	    if ($step)
	    {
		if ($f[0]>=$step)
		{
		    $f[5]="waiting";
		    $f[6]=0;
		} else
		{
		    $f[5]="finished";
		}
	    } else
	    {
		$f[5] =~ s/started|error/waiting/i; #ignore previous errors
		$f[6] = 0 if $f[5] !~ /finished/i; #erase previous pid
	    }
	}
	$_=[@f];
    }

    &writeChange($in,@lines);
}

sub run
{
    #Usage: &run($file,1)
    #1 means enable qsub, 0 means disable it
    my $file=shift; #format:step	cmd	ncpu_require	ncpu_total	status(started,finished,waiting,error)
    my $step=shift;
    my $qsub=shift;
    my $cpu_total=&getTotalCPU($file) or die "ERROR: ZERO total number of CPUs\n";
    my $step_total=&getTotalStep($file) or die "ERROR: Zero steps\n";
    my $cpu_available=$cpu_total;

    die "ERROR: Negative number of CPUs!\n" if $cpu_total<=0;
    #when you mod the status,  add file LOCK!!!
    #initiation of another command is done by this subroutine, 
    #each command of the file is only able to control its own line
    &firstScan($file,$step);

    warn "*************EXECUTION BEGINS at ",&getReadableTimestamp,"*****************\n";
    my $start_time=time;
    while (1)
    {
	sleep 1;
	if (my $cmd=&checkErr($file))
	{
	    my $cwd=`pwd`;
	    chomp $cwd;
	    die "ERROR: $cmd failed\n",
	        "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"x3,
	        "After fixing the problem, please execute 'cd $cwd' and 'seqmule run $file' to continue analysis.\n",
	        "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n"x3;
	} else
	{
	    my $elapse_time=time-$start_time;
	    $cpu_available = $cpu_total-&getUsedCPU($file);
	    if ( my ($step,$cmd,$msg,$cpu_request)=&getNextCMD($file))
	    {
		if($cpu_available>=$cpu_request)
		{
		    if ($qsub)
		    {
			#record job ID
			my $job=`$cmd`;
			my ($id)= $job=~/(\d+)/;
			&writePID($file,$step,$id);
		    } else
		    {
			#record pid by the execution script
			system("$cmd &");
			&wait2start($file,$step);
		    }
		    warn "\n${splitter}NOTICE$splitter\n[ => SeqMule Execution Status: Running $step of $step_total steps: $msg, ".
		    "at ",&getReadableTimestamp,", Time Elapsed: ",&convertTime($elapse_time),"]\n";
		}
	    } else
	    {
		if (&allDone($file))
		{
		    warn "[ => SeqMule Execution Status: All done at ",&getReadableTimestamp,"]\n";
		    warn "Total time: ",&convertTime($elapse_time),"\n";
		    last;
		}
	    }
	    #check if the 'started' proc is actually running. If not, mark error
	    #the following function needs improvement. For now, just ignore it.
	    #&checkRunningPID($file);
	}
    }
}

sub getReadableTimestamp
{
    my $time = `date`;
    chomp $time;
    return($time);
}

sub convertTime
{
    my $time=shift;
    my $hr=int($time/3600);
    my $min=int( ($time % 3600)/60);
    my $sec=$time%60;
    my $readable_time="$hr hr $min min $sec s";
    return $readable_time;
}

sub getTotalStep
{
    my $file=shift;
    my @lines=&readScript($file);

    my @last_f=@{$lines[$#lines]};
    if ($last_f[0]=~/^(\d+)$/)
    {
	return $1;
    } else
    {
	return 0;
    }
}
sub checkErr
{
    my $file=shift;
    my @lines=&readScript($file);

    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[5]=~/error/i)
	{
	    return $f[1];
	}
    }
    return undef;
}
sub getTotalCPU
{
    my $file=shift;
    my @lines=&readScript($file);
    my $total=0;
    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[4]=~/^\d+$/)
	{
	    $total=$f[4];
	    last;
	}
    }
    return $total;
}
sub getNextCMD
{
    my $file=shift;
    my @lines=&readScript($file);
    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	if ($f[5]=~/waiting/i)
	{
	    return @f[0,1,2,3];
	}
    }
    return ();
}
sub allDone
{
    my $file=shift;
    my $done=1;
    my @lines=&readScript($file);

    die "ERROR: Empty script!\n" unless @lines;
    for (@lines)
    {
	my @f=@{$_};
	if ($f[5]=~/waiting|started|error/)
	{
	    $done=0;
	    last;
	}
    }
    return $done;
}
sub getUsedCPU
{
    my $file=shift;
    my @lines=&readScript($file);
    my $n=0;

    for (@lines)
    {
	my @f=@{$_};
	next if $f[0]=~/^#/;
	$n += $f[3] if $f[5]=~/started/i;
    }
    return $n;
}

sub genTempScript
{
    my @cmd=@_;
    my $tmp="/tmp/$$".time()."script";
    open OUT,'>',$tmp or die "Can't write to $tmp: $!\n";
    print OUT "#!/bin/bash\nset -e\n"; #let shell run the script, exit at first error
    print OUT "set -o pipefail\n"; #let shell run the script, exit at first error
    print OUT join ("\n",@cmd);
    close OUT;
    chmod 0755,$tmp or die "Failed to chmod 755 on $tmp\n";
    return $tmp;
}

sub checkRunningPID
{ #if started, but not running, change status to 'error'
    #NEEDS IMPROVEMENT OR TESTING
    my $file=shift;
    my $waiting_time=10;
    my $second_check=0;
    my $second_check_n;

    for my $i(&readScript($file))
    {
	my ($n,$status,$pid)=@{$i}[0,5,6];
	next unless $status eq 'started';
	unless (kill 0,$pid)
	{ #try to signal the proc, if not successful, wait a monment, try again, if failed, mark it as error
	    #this measure avoids false error when the status is not updated immediately upon exit
	    $second_check=1;
	    $second_check_n=$n;
	}
    }
    if ($second_check)
    {
	sleep $waiting_time;
	for my $i(&readScript($file))
	{
	    my ($n,$status,$pid)=@{$i}[0,5,6];
	    next unless $n eq $second_check_n;
	    unless (kill 0,$pid)
	    { 
		warn "ERROR: STEP $n was started, but actually not running.\n";
		&status2error($file,$n);
	    }
	}
    }
}

1;

=head



#qsub
echo './mod_status fast.script 2 s && if samtools view -b ../father_bwa.sort.rmdup.bam 1 > father-1.bam;then ./mod_status fast.script 2 f;else ./mod_status fast.script 2 e;fi' | qsub -V -cwd -l h_vmem=2g	1	18	finished
echo './mod_status fast.script 3 s && if samtools view -b ../father_bwa.sort.rmdup.bam 2 > father-2.bam;then ./mod_status fast.script 3 f;else ./mod_status fast.script 3 e;fi' | qsub -V -cwd -l h_vmem=2g	1	18	finished

=cut
