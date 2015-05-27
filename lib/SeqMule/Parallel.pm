package SeqMule::Parallel;
#take a list of commands, total number of cpus, convert them to a script that can be run in parallel
#also contains a subroutine to run the script

use strict;
use warnings;
use FindBin qw/$RealBin/;
use File::Spec;
use lib File::Spec->catdir($RealBin,"..","..","lib");
use Config::Tiny;
use File::Basename qw/basename/;

#add version number, different versions of config might be incompatible
my $VERSION = 1.2;
my %COMPATIBLE_VERSION = {"1.2"=>1};
my $debug=0;
my $splitter="-" x 10;
#keywords used for job status
my $WAIT = "waiting";
my $START = "started";
my $FINISH = "finished";
my $ERROR = "error";
#keywords used in script file
my $CONFIG_FILE_DESC = <<HEREDOC;
[SETTING_SECTION]
VERSION = $VERSION
CPUTOTAL = 1
LOGDIR = /home/user/analysis
[CMD_SECTION]
;STEP number as section name
[1]
command = blah
message = foo
nCPU_requested = 1 
status = waiting
JOBID = 0
PID = 123
[2]
...
HEREDOC
my %CONFIG_KEYWORD = (
    CPUTOTAL => "CPUTOTAL",
    LOGDIR => "LOGDIR",
    SETTING_SECTION => "SETTING_SECTION",
    CMD_SECTION => "CMD_SECTION",
    COMMAND => "command",
    MESSAGE => "message",
    STATUS => "status",
    NCPU_REQUEST => "nCPU_requested",
    JOBID => "JOBID",
    PID => "PID",
);

my $SENTINEL_FILE_DESC = <<HEREDOC;
#later we may convert this module to OO style to make it more rigorous

#for each task XXX, we create a folder XXX inside logdir
#then in each task folder, create the following files
PID.XXXX
JOBID.XXXX
STATUS.{started|error|finished}
MSG
#the above files are used to determine job status, PID, JOBID, message
#why create subfolders? When we want to look at a specific task,
#we don't have to list all files in logdir, therefore, reducing
#IO load


#some files used to communicate between processes
#SEQMULE{ID} tells ID of task in seqmule's script
#tell monitoring process JOBID and PID
#if JOBID is not available, use 'JOBNA' replace JOB{ID}.
SEQMULE{ID}.JOB{ID}.PID{ID}

#task is started
SEQMULE{ID}.JOB{ID}.PID{ID}.started

#task is finished
SEQMULE{ID}.JOB{ID}.PID{ID}.finished

#task is finished
SEQMULE{ID}.JOB{ID}.PID{ID}.error

#task message
SEQMULE{ID}.msg

HEREDOC

sub writeParallelCMD {
    croak("Usage: &writeParallelCMD({worker=>path_to_worker,file=>,cpu_total=>,cmd=>,})\n") unless @_ == 1;
    my $opt = shift;
    my $worker = $opt->{worker};
    my $file = $opt->{file};
    my $cpu_total = $opt->{cpu_total};
    my @cmd = @{$opt->{cmd}};
    #@cmd is array of arrays, 2nd array consists of [ncpu_request,command]
    my @out;
    my $config = Config::Tiny->new;
    my $date = `date +%m%d%Y`;chomp $date;
    my $logdir = File::Spec->catfile($ENV{PWD},"seqmule.".$date.".$$.logs");
    !system("mkdir $logdir") or croak("mkdir($logdir): $!\n") unless -d $logdir;

    $config->{$CONFIG_KEYWORD{SETTING_SECTION}} = {
	$CONFIG_KEYWORD{VERSION} => $VERSION,
	$CONFIG_KEYWORD{CPUTOTAL} => $cpu_total,
	$CONFIG_KEYWORD{LOGDIR} => $logdir,
    };
    $config->{$CONFIG_KEYWORD{CMD_SECTION}} = {};
    for my $i(1..@cmd) {
	#each element of @cmd is array reference [ncpu_request,msg,command]
	@{$cmd[$i-1]} == 3 or croak("3 fields in commands expected (step $i).\n");
	my $ncpu_request = $cmd[$i-1][0]; #ncpu requested
	my $msg=$cmd[$i-1][1];
	my $cmd_line=$cmd[$i-1][2]; 
	$cmd_line = "$worker $logdir $i $cmd_line";
	croak("ERROR: No shell meta characters allowed: $cmd_line\n") if $cmd_line=~/[\?\>\<\|\;\&\$\#\`\(\)]/;
	#comments are not allowed
	$config->{$CONFIG_KEYWORD{CMD_SECTION}}->{$i} = {
	    $CONFIG_KEYWORD{command} => $cmd_line,
	    $CONFIG_KEYWORD{message} => $msg,
	    $CONFIG_KEYWORD{nCPU_requested} => $ncpu_request,
	    $CONFIG_KEYWORD{status} => $WAIT,
	    $CONFIG_KEYWORD{JOBID} => 0,
	    $CONFIG_KEYWORD{PID} => 0,
	};
    }
    $config->write($file);
    warn "NOTICE: Commands written to $file\n";
}
sub run {
    croak("Usage: &run(\$file,step#,yesno_qsub)\n") unless @_ == 3;
    #for yesno_qsub, 1 means enable qsub, 0 means disable it
    my $file=shift; #format:step	cmd	ncpu_require	ncpu_total	status(started,finished,waiting,error)
    my $step=shift;
    my $qsub=shift;

    my $config = Config::Tiny->read($file);
    my $allcmd = $config->{$CONFIG_KEYWORD{CMD_SECTION}};
    my $allsetting = $config->{$CONFIG_KEYWORD{SETTING_SECTION}};

    my $logdir = $allsetting->{$CONFIG_KEYWORD{LOGDIR}} or croak("ERROR: no log folder: $file\n");
    my $cpu_total = $allsetting->{$CONFIG_KEYWORD{CPUTOTAL}} or croak ("ERROR: no total number of CPUs: $file\n");
    my $step_total = scalar (keys %{$allcmd}) or croak("ERROR: no steps: $file\n");
    my $cpu_available = $cpu_total;

    croak("ERROR: Negative number of CPUs!\n") if $cpu_total<=0;
    &firstScan({file=>$file,
	    config=>$config,
	    step=>$step,
	    logdir => $logdir,
	});

    warn "*************EXECUTION BEGINS at ",&getReadableTimestamp,"*****************\n";
    my $start_time=time;
    while (1) {
	&selectSleep($step_total);
	&syncStatus({logdir=>$logdir,config=>$config,file=>$file,direction=>'log2config'});
	if(my $cmd = join("\n",
		map{$allcmd->{$_}->{$CONFIG_KEYWORD{COMMAND}}} 
		(grep {$allcmd->{$_}->{$CONFIG_KEYWORD{STATUS}} eq $ERROR} (keys %$all_cmd))
	    ) ) {
	    #grep failed tasks
	    my $cwd=`pwd`; chomp $cwd;
	    die "ERROR: command failed\n",
	    $cmd,
	    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n",
	    "After fixing the problem, please execute 'cd $cwd' and 'seqmule run $file' to continue analysis.\n",
	    "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
	} else {
	    my $elapse_time=time-$start_time;
	    $cpu_available = $cpu_total-&getUsedCPU($allcmd);
	    if ( my ($step,$cmd,$msg,$cpu_request)=&getNextCMD($allcmd)) {
		if($cpu_available>=$cpu_request) {
		    #if ($qsub) {
		    #    #record job ID
		    #    my $job=`$cmd`;
		    #    my ($id)= $job=~/(\d+)/;
		    #    &writePID($file,$step,$id);
		    #} else {
		    #record pid by the execution script
		    system("$cmd &");
		    &wait2start({file=>$file,config=>$config,step=>$step});
		    #}
		    warn "\n${splitter}NOTICE$splitter\n[ => SeqMule Execution Status: Running $step of $step_total steps: $msg, ".
		    "at ",&getReadableTimestamp,", Time Elapsed: ",&convertTime($elapse_time),"]\n";
		}
	    } else {
		if (&allDone($allcmd)) {
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
    sub selectSleep {
	#sleep based on # of jobs
	my $scaling_factor = 100;
	my $step_total = shift;
	sleep int($step_total/$scaling_factor + 1);
    }

#sub qsub_writeParallelCMD
#{
#    warn "NOT IMPLEMENTED YET\n" and exit;
    #
#    my ($install_dir,$file,$cpu_total,$cpu_per_node,@cmd)=@_;
#    #@lines is array of arrays, 2nd array consists of [ncpu_request,command]
#    my @out;
#    my $worker=File::Spec->catfile($install_dir,"bin","secondary","worker");
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
#	"$worker $file $line_no s && ".
#	"if $cmd;".
#	"then $worker $file $line_no f;".
#	"else $worker $file $line_no e;".
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

    #execute the actual command for each task
    #create/rm sentinel files accordingly
    sub single_line_exec {
	die "Usage: &single_line_exec({logdir=><log folder>,step=><step number>,jobid=><JOBID>,cmd=><command and arguments>})\n" unless @_>=4;

	my $opt = shift;
	my $logdir = $opt->{logdir};
	my $jobid = $opt->{jobid};
	my $step = $opt->{step};
	my $cmd = $opt->{cmd};
	my @out;
	my $start_time=time;
	my $msg=&getMsg($logdir,$step);

	#&wait2start($script,$n);
	my $success;
	warn "DEBUG: about to fork for $msg\n" if $debug;
	my $pid=fork;
	if ($pid) {
	    #parent proc
	    &create_sentinel({logdir=>$logdir,step=>$step,pid=>$pid,status=>$START});
	    my $deceased_pid=wait;
	    if ($deceased_pid==$pid) {
		#got the exit status of child
		if ($? == 0) {
		    $success=1;
		} else {
		    $success=0;
		}
	    } else {
		warn "WARNING: Didn't get child exit status\n";
		$success=0;
	    }
	} elsif (defined $pid) {
	    #real execution code
	    exec @cmd or die "ERROR: Command not found: @cmd\n";
	} else {
	    $success=0;
	}

	if ($success) {
	    my $time=`date`;chomp $time;
	    my $total_min=&getTotalMin($start_time);
	    &create_sentinel({logdir=>$logdir,step=>$step,pid=>$pid,status=>$FINISH});
	    warn "[ => SeqMule Execution Status: step $n is finished at $time, $msg, Time Spent at this step: $total_min min]\n\n";
	} else {
	    my $time=`date`;chomp $time;
	    my $total_min=&getTotalMin($start_time);
	    &create_sentinel({logdir=>$logdir,step=>$step,pid=>$pid,status=>$ERROR});
	    die "\n\n${splitter}ERROR$splitter\n[ => SeqMule Execution Status: step $n FAILED at $time, $msg, $total_min min]\n";
	}
    }
    sub getMsg {
	my $logdir=shift;
	my $n=shift;
	my $msg_file = File::Spec->catfile($logdir,$n,"MSG");
	my $msg;
	open IN,'<',$msg_file or croak("ERROR: Can't find message for step $n in $logdir($msg_file): $!\n");
	while(<IN>) {
	    chomp;
	    $msg .= $_;
	}
	close IN;
	return $msg;
    }
    sub wait2start {
	#modify config for specific step
	#change status from wait to start
	#at this point, config is NOT in sync with logdir
	#this function is used to prevent this particular step being
	#run twice by paranet proc.
	my $opt = shift;
	my $file=$opt->{file};
	my $step = $opt->{step};
	my $config = $opt->{config};

	my $step_ref = $config->{$CONFIG_KEYWORD{CMD_SECTION}}->{$step};
	if ($step_ref->{$CONFIG_KEYWORD{STATUS}} eq $WAIT) {
	    $step_ref->{$CONFIG_KEYWORD{STATUS}} = $START;
	} else {
	    #task is not waiting, something goes wrong
	    croak("ERROR: step $step is not waiting\n");
	}
	$config->write($file);
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

    sub create_sentinel {
	#remove existing STATUS files
	#create STATUS and PID sentinel files
		my $opt = shift;
	my $logdir=$opt->{logdir};
	my $n=$opt->{step};
	my $pid=$opt->{pid};
	my $status=$opt->{status};
	my $sentinel = File::Spec->catfile($logdir,$n,"STATUS.$status");
	my $pid_file = File::Spec->catfile($logdir,$n,"PID.$pid");
	!system("rm -f STATUS.*") or croak("failed to rm STATUS.*: $!\n");
	&touch($sentinel);
	&touch($pid_file);
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
	warn "DEBUG: began writing $script!\n" if $debug;
	warn "DEBUG: ".scalar @out." lines to write!\n" if $debug;
	seek OUT,0,0;
	truncate OUT,0;
	map { print OUT join("\t",@{$_}),"\n" } @out;
	close OUT;
    }

    sub readScript {
	my $script=shift;
	my @out;
	open IN,'<',$script or die "Cannot read $script: $!";

	while(<IN>) {
	    chomp;
	    if(eval $CPUTOTAL) { 
		= "m/CPUTOTAL=(\\d+)/";
		my $LOGDIR = "m/LOGDIR=(.*)\$/";
		my @f=split(/\t/,$_,-1);
		if(@f==7) {
		    push @out,[@f];
		}
		close IN;
		return @out;
	    }
	    sub firstScan {
		#remove existing sentinel files in logdir
		#change job status to finished for all jobs after specified step #
		my $opt = shift;
		my $file = $opt->{file};
		my $config = $opt->{config};
		my $step= $opt->{step};
		my $logdir = $opt->{logdir};
		my $allcmd = $config->{$CONFIG_KEYWORD{CMD_SECTION}};
#clean up unfinished processes in config
		for my $i(sort keys %{$allcmd}) {
		    if($step) {
			if($i > $step) {
			    #change all status to waiting
			    $allcmd->{$i}->{$CONFIG_KEYWORD{STATUS}} = $WAIT;
			} elsif ($i <= $step) {
			    #change all status to finished
			    $allcmd->{$i}->{$CONFIG_KEYWORD{STATUS}} = $FINISH;
			} 
		    } else {
			#find last finished step when step is not defined
			#change started/error to waiting after last finished step
			if($allcmd->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH) {
			    next if defined $allcmd->{$i+1}->{$CONFIG_KEYWORD{STATUS}} and 
			    $allcmd->{$i+1}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH;
			    $step = $i;
			}
		    }
		}
		$config->write($file);

		#clean up sentinel files
		&syncStatus({logdir=>$logdir,config=>$config,direction=>'config2log'});
	    }

	    #########time related subroutines############
	    sub getReadableTimestamp {
		my $time = `date`;
		chomp $time;
		return($time);
	    }

    sub getTotalMin {
	my $start=shift;
	my $end=time;
	my $total=($end-$start)/60; 
	$total=sprintf("%.1f",$total);
	return $total;
    }
	    sub convertTime {
		my $time=shift;
		my $hr=int($time/3600);
		my $min=int( ($time % 3600)/60);
		my $sec=$time%60;
		my $readable_time="$hr hr $min min $sec s";
		return $readable_time;
	    }
	    ##########################################

	    sub getTotalStep {
		my $file=shift;
		my @lines=&readScript($file);

		my @last_f=@{$lines[$#lines]};
		if ($last_f[0]=~/^(\d+)$/) {
		    return $1;
		} else {
		    return 0;
		}
	    }
	    sub syncStatus {
		#synchronize config file and logdir based on rules described in $SENTINEL_FILE_DESC
		my $logdir = $opt->{logdir};
		my $config = $opt->{config};
		my $file = $opt->{file};
		my $direction = $opt->{direction}; #log2config, config2log
		my $allcmd = $config->{$CONFIG_KEYWORD{CMD_SECTION}};

		if($direction eq 'log2config') {
		    #sync sentinel to config
		    opendir(my $dh,$logdir) or croak ("ERROR: can't read $logdir: $!\n");
		    while(my $i = readdir($dh) ) {
			#make sure $i is relative path
			$i = basename $i;
			if($allcmd->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH) {
			    #the first few tasks are finished, skip them altogether
			    next;
			} else {
			    #grab JOBID, PID, status
			    opendir(my $dh_i,File::Spec->catfile($logdir,$i)) or croak ("ERROR: can't read $i in $logdir: $!\n");
			    my ($jobid, $pid, $status);
			    while(my $j = readdir($dh_i) ) {
				$j = basename $j;
				if(/JOBID\.(\d+)/) {
				    $jobid = $1;
				} elsif (/PID\.(\d+)/) {
				    $pid = $1;
				} elsif (/STATUS\.(\w+)/) {
				    $status = $1;
				}
			    }
			    closedir $dh_i;
			    #consider when these files are temporarily unavailable
			    $allcmd->{$i}->{$CONFIG_KEYWORD{STATUS}} = $status if $status;
			    $allcmd->{$i}->{$CONFIG_KEYWORD{PID}} = $pid if $pid;
			    $allcmd->{$i}->{$CONFIG_KEYWORD{JOBID}} = $jobid if $jobid;
			}
		    }
		    closedir $dh;
		    $config->write($file);
		} elsif($direction eq 'config2log') {
		    #sync config to sentinel
		    #!!!!!
		    #this can only be done when NO tasks are running
		    #otherwise may mess things up
		    #!!!!!
		    for my $i(sort keys %$allcmd) {
			if($allcmd->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH) {
			    #the first few tasks are finished, skip them altogether
			    next;
			} else {
			    my $task_dir = File::Spec->catfile($logdir,$i);
			    my $i_ref = $allcmd->{$i};
			    !system("rm -rf $task_dir") or croak("failed to rm $task_dir: $!\n");
			    !system("mkdir $task_dir") or croak("mkdir failed $taskdir: $!\n"); 
			    &touch(File::Spec->catfile($task_dir,"JOBID.".$i_ref->{$CONFIG_KEYWORD{JOBID}}));
			    &touch(File::Spec->catfile($task_dir,"PID.".$i_ref->{$CONFIG_KEYWORD{PID}}));
			    &touch(File::Spec->catfile($task_dir,"STATUS.".$i_ref->{$CONFIG_KEYWORD{STATUS}}));
			    &writeMsg(File::Spec->catfile($task_dir,"MSG"),$i_ref->{$CONFIG_KEYWORD{MESSAGE}});
			}
		    }
		} else {
		    croak("ERROR: unknown direction $direction\n");
		}
	    }
	    sub getScriptConfig {
		my $file = shift;
		my @lines=&readScript($file);
		my $config = {
		    #every one of the following must be defined at the end
		    logdir => undef,
		    cpuTotal => undef,
		    stepTotal => undef,
		    steps => undef,
		};
		my $total=0;

		my $logdir = &getTo
		my $cpu_total=&getTotalCPU($file) or die "ERROR: ZERO total number of CPUs\n";
		my $step_total=&getTotalStep($file) or die "ERROR: Zero steps\n";

		sub getTotalStep {
		    my $file=shift;
		    my @lines=&readScript($file);

		    my @last_f=@{$lines[$#lines]};
		    if ($last_f[0]=~/^(\d+)$/) {
			return $1;
		    } else {
			return 0;
		    }

		    for (@lines) {
			$CPUTOTAL
			$LOGDIR
			my @f=@{$_};
			next if $f[0]=~/^#/;
			if ($f[4]=~/^\d+$/)
			{
			    $total=$f[4];
			    last;
			}
		    }
		    for my $i(keys %{$config}) {
			croak("ERROR: $i is undefined in $file\n") unless defined $config->{$i};
		    }
		    return $config;
		}
		sub getTotalCPU {
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
		sub getNextCMD {
		    my $allcmd=shift;
		    for my $i(sort keys %$allcmd) {
			if($allcmd->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $WAIT) {
			    return (
				$i,
				$allcmd->{$i}->{$CONFIG_KEYWORD{COMMAND}},
				$allcmd->{$i}->{$CONFIG_KEYWORD{MESSAGE}},
				$allcmd->{$i}->{$CONFIG_KEYWORD{NCPU_REQUEST}},
			    );
			}
		    }
		    return ();
		}
		sub allDone {
		    #check if all tasks are done based on config
		    my $allcmd = shift;
		    my $done=1;
		    for my $i(values %$allcmd) {
			if ($i->{$CONFIG_KEYWORD{STATUS}} ne $FINISH) {
			    $done = 0;
			}
		    }
		    return $done;
		}
		sub getUsedCPU {
		    my $allcmd=shift;
		    my $n=0;

		    for my $i(keys %{$allcmd}) {
			if ($allcmd->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $START) {
			    $n += $allcmd->{$i}->{$CONFIG_KEYWORD{NCPU_REQUEST}};
			}
		    }
		    return $n;
		}
		sub genTempScript {
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
		sub touch {
		    for my $i(@_) {
			unless(-e $i) {
			    !system("touch $i") or croak("ERROR: failed to touch $i: $!\n");
			}
		    }
		}
			    sub writeMsg {
				my $file = shift;
				my $msg = shift;
				open OUT,'>',$file or croak("open($file): $!\n");
				print OUT $msg;
				close OUT;
			    }

		1;

=head



#qsub
echo './worker fast.script 2 s && if samtools view -b ../father_bwa.sort.rmdup.bam 1 > father-1.bam;then ./worker fast.script 2 f;else ./worker fast.script 2 e;fi' | qsub -V -cwd -l h_vmem=2g	1	18	finished
echo './worker fast.script 3 s && if samtools view -b ../father_bwa.sort.rmdup.bam 2 > father-2.bam;then ./worker fast.script 3 f;else ./worker fast.script 3 e;fi' | qsub -V -cwd -l h_vmem=2g	1	18	finished

=cut
