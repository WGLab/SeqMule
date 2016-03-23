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
use Carp qw/croak carp/;
use SeqMule::SeqUtils;
use Sort::Topological qw/toposort/;

#add version number, different versions of config might be incompatible
my $VERSION = 1.2;
my %COMPATIBLE_VERSION = ("1.2"=>1);
my $debug=0;
my $splitter="-" x 10;
my %TDG; #task dependency graph, for each task, specify child
my %TDG_REVERSE; #task dependency graph, for each task, specify parent
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
STEPTOTAL = 10
;STEP number as section name
[1]
command = blah
message = foo
nCPU_requested = 1 
status = waiting
JOBID = 0
PID = 123
dependency = 0
[2]
...
dependency = 1[,3,4]
HEREDOC
my %CONFIG_KEYWORD = (
    CPUTOTAL => "CPUTOTAL",
    LOGDIR => "LOGDIR",
    STEPTOTAL => "STEPTOTAL",
    SETTING_SECTION => "SETTING_SECTION",
    COMMAND => "command",
    MESSAGE => "message",
    STATUS => "status",
    NCPU_REQUEST => "nCPU_requested",
    JOBID => "JOBID",
    PID => "PID",
    VERSION => "VERSION",
    DEPENDENCY => "dependency",
);

my $SENTINEL_FILE_DESC = <<HEREDOC;
#later we may convert this module to OO style to make it more rigorous

#some files used to communicate between processes
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


HEREDOC

sub writeParallelCMD {
    #how this function is invoked
    #&SeqMule::Parallel::writeParallelCMD ({
    #        worker=>File::Spec->catfile($install_dir,"bin","secondary","worker"),
    #        file=>$script_file,
    #        cpu_total=>$threads,
    #        cmd=>\@commands,
    #    });
    #push @commands, {
    #    nCPU_requested		=>	$threads,
    #    message			=>	"Merge BAM without changing readgroup",
    #    command			=>	["$exe $samtools $threads ".$onebam_obj->file()." $TMPDIR ".join(" ",@other_bam_file)],
    #    in			=>	[@other_bam_obj],
    #    out			=>	[$onebam_obj],
    #};
    ##how to specify a DAG (directed acyclic graph)?
    #my %children = (
    #    'a' => [ 'b', 'c' ], #b,c is direct child of a
    #    'c' => [ 'x' ],
    #    'b' => [ 'x' ],
    #    'x' => [ 'y' ],
    #    'y' => [ 'z' ],
    #    'z' => [ ],
    #);
    #sub children { @{$children{$_[0]} || []}; } 
    #my @unsorted = ( 'z', 'a', 'x', 'c', 'b', 'y' );
    #my @sorted = toposort(\&children, \@unsorted);
    #empty in or out means the no dependency for SeqUtils obj (but rather other existing stuff)
    croak("Usage: &writeParallelCMD({worker=>path_to_worker,file=>,cpu_total=>,cmd=>[],message=>,})\n") unless @_ == 1;
    my $opt = shift;
    my $worker = $opt->{worker};
    my $file = $opt->{file};
    my $cpu_total = $opt->{cpu_total};
    my @cmd = @{$opt->{cmd}};
    #@cmd is array of arrays, 2nd array consists of [ncpu_request,command,...]
    my $config = Config::Tiny->new;
    my $date = `date +%m%d%Y`;chomp $date;
    my $logdir = File::Spec->catfile($ENV{PWD},"seqmule.".$date.".$$.logs");
    !system("mkdir $logdir") or croak("mkdir($logdir): $!\n") unless -d $logdir;
    warn "NOTICE: $logdir will be used for job monitoring.\n";

    $config->{$CONFIG_KEYWORD{SETTING_SECTION}} = {
	$CONFIG_KEYWORD{VERSION} => $VERSION,
	$CONFIG_KEYWORD{CPUTOTAL} => $cpu_total,
	$CONFIG_KEYWORD{LOGDIR} => $logdir,
	$CONFIG_KEYWORD{STEPTOTAL} => scalar @cmd,
    };

    %TDG = constructTDG(\@cmd);
    %TDG_REVERSE = constructTDGREVERSE(\@cmd);

#sort commands #write command
    my $step = 1;
    my %stepAndIdx;
    print scalar @cmd,"total steps\n" if $debug;
    for my $i(toposort(\&returnTDGChild,[0..$#cmd])) {
	print "i:$i,step:$step\n" if $debug;
	$stepAndIdx{$i} = $step;
	$step++;
    }
    for my $i(0..$#cmd) {
	my $step = $stepAndIdx{$i};
	for my $j(@{$cmd[$i]->{command}}) {
	    croak("ERROR: No shell meta characters allowed: $j\n") if $j=~/[\'\"\?\>\<\|\;\&\$\#\`\(\)]/;
	}
	my $cmd_line = "$worker $logdir $step \"".join(" && ",@{$cmd[$i]->{command}})."\"";
	my $msg = $cmd[$i]->{message};
	my $ncpu_request = $cmd[$i]->{nCPU_requested};
	#comments are not allowed
	$config->{$step} = {
	    $CONFIG_KEYWORD{COMMAND} => $cmd_line,
	    $CONFIG_KEYWORD{MESSAGE} => $msg,
	    $CONFIG_KEYWORD{NCPU_REQUEST} => $ncpu_request,
	    $CONFIG_KEYWORD{STATUS} => $WAIT,
	    $CONFIG_KEYWORD{JOBID} => 0,
	    $CONFIG_KEYWORD{PID} => 0,
	    $CONFIG_KEYWORD{DEPENDENCY} => (
		join(',',map{$stepAndIdx{$_}} &SeqMule::Utils::uniq(@{$TDG_REVERSE{$i}})) || ""
	    ),
	};
    }
    $config->write($file);
    warn "NOTICE: Commands written to $file\n";
}
sub run {
    croak("Usage: &run(\$file,step#,qsub_template)\n") unless @_ == 3;
    #qsub_template: replace XCPUX with the actual number of CPUs, then append the command
    #qsub -V -cwd -pe smp XCPUX -N jobname -S /bin/bash -m ea -M tom@gmail.com
    #then run it
    my $file=shift; #format:step	cmd	ncpu_require	ncpu_total	status(started,finished,waiting,error)
    my $step=shift;
    my $qsub=shift;
    &checkQsubTemplate($qsub) if defined $qsub;

    my $config = Config::Tiny->read($file) or croak("ERROR: failed to read or parse SeqMule script <<$file>>\n");
    my $allsetting = $config->{$CONFIG_KEYWORD{SETTING_SECTION}};
    &checkVersion($allsetting);

    my $logdir = $allsetting->{$CONFIG_KEYWORD{LOGDIR}} or croak("ERROR: no log folder: $file\n");
    my $cpu_total = $allsetting->{$CONFIG_KEYWORD{CPUTOTAL}} or croak ("ERROR: no total number of CPUs: $file\n");
    my $step_total = &getTotalStep($config);
    my $cpu_available = $cpu_total;

    croak("ERROR: Negative number of CPUs!\n") if $cpu_total<=0;
    warn "DEBUG(PID:$$): about to firstscan \n" if $debug;
    &firstScan({file=>$file,
	    config=>$config,
	    step=>$step,
	    logdir => $logdir,
	});
    #TODO:should also check whether another instance of seqmule or its children are running
    #if so warn user and exit


    warn "*************EXECUTION BEGINS at ",&getReadableTimestamp,"*****************\n";
    my $start_time=time;
    my @alreadyFinish; #keep track of finished steps
    while (1) {
	&selectSleep($step_total);
	&syncStatus({logdir=>$logdir,config=>$config,file=>$file,direction=>'log2config'});
	&checkError({logdir=>$logdir,config=>$config,file=>$file});
	warn "DEBUG(PID:$$): no error found, go on\n" if $debug;
	my $elapse_time=time-$start_time;
	$cpu_available = $cpu_total-&getUsedCPU($config);
	if ( my ($step,$cmd,$msg,$cpu_request)=&getNextCMD($config)) {
	    if($cpu_available>=$cpu_request) {
		my $jobid;
		warn "DEBUG(PID:$$): about to execute:\n$cmd\n" if $debug;
		#before task is submitted or executed
		#we change its status from waiting to started
		#for SGE tasks, they may be queued for a long time before they can
		#the status to started
		&wait2start({file=>$file,config=>$config,logdir=>$logdir,step=>$step});
		if ($qsub) {
		    my $submit_cmd = &getSubmitCmd({submitCmd=>$qsub,cpu=>$cpu_request,logdir=>$logdir,step=>$step});
		    my $script = &genTempScript($cmd);
		    #submit job and return job ID
		    $jobid = &submitJob($submit_cmd,$cmd);
		    #!!!it is possible that after submission, job will not be started immediately
		    #so if I only change config, config will be changed back after sync
		    #    and sync will happen before job started
		    #JOBID sentinel file will ONLY be handled by Parallel.pm
		    #so it is safe to do whatever to JOBID file. The child will
		    #not be influenced anyway.
		    #JOBID will be written by wait2start
		} else {
		    #record pid by the execution script
		    system("$cmd &");
		}
		#from the viewpoint of parent process, the children are started
		#regardlesss they are running in background or on SGE queue
		&writeJOBID({file=>$file,config=>$config,logdir=>$logdir,step=>$step,jobid=>$jobid});
		warn "\n${splitter}NOTICE$splitter\n[ => SeqMule Execution Status: Running $step of $step_total steps: $msg, ".
		"at ",&getReadableTimestamp,", Time Elapsed: ",&convertTime($elapse_time),"]\n";
	    }
	} else {
	    if (&allDone($config)) {
		warn "[ => SeqMule Execution Status: All done at ",&getReadableTimestamp,"]\n";
		warn "Total time: ",&convertTime($elapse_time),"\n";
		last;
	    }
	}
	#check if the 'started' proc is actually running. If not, mark error
	if (my @error_step = &checkRunningID($file,$qsub)) {
	    &status2error({errorStep=>\@error_step, file=>$file,config=>$config,logdir=>$logdir});
	}
	#report newly finished jobs
	@alreadyFinish = &reportFinish($config,@alreadyFinish);
    }
}
sub selectSleep {
    #sleep based on # of jobs
    my $scaling_factor = 100;
    my $step_total = shift;
    sleep int($step_total/$scaling_factor + 1);
}

#execute the actual command for each task
#create/rm sentinel files accordingly
sub single_line_exec {
    croak("Usage: &single_line_exec({logdir=><log folder>,step=><step number>,cmd=><command and arguments>})\n")unless @_==1;
    my $opt = shift;
    my $logdir = $opt->{logdir};
    my $step = $opt->{step};
    my $cmd = $opt->{cmd};
    my @out;
    my $start_time=time;
    my $msg=&getMsg($logdir,$step);

    my $success;
    warn "DEBUG(PID:$$): about to fork for $msg\n" if $debug;
    my $pid=fork;
    if ($pid) {
	#parent proc
	#we used to let child handle status, now with sge
	#it's possible that the child is queued but hasn't got executed
	#to change its own status to started. This will cause parent
	#to repeatedly submit same child.
	#&create_sentinel({logdir=>$logdir,step=>$step,pid=>$$,status=>$START});
	&create_sentinel({logdir=>$logdir,step=>$step,pid=>$$});
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
	exec $cmd or die "ERROR: Command not found: $cmd\n";
    } else {
	$success=0;
    }

    if ($success) {
	my $time=`date`;chomp $time;
	my $total_min=&getTotalMin($start_time);
	&create_sentinel({logdir=>$logdir,step=>$step,pid=>$$,status=>$FINISH});
	#we already print runtime info by parent
	#warn "[ => SeqMule Execution Status: step $step is finished at $time, $msg, Time Spent at this step: $total_min min]\n\n";
    } else {
	my $time=`date`;chomp $time;
	my $total_min=&getTotalMin($start_time);
	&create_sentinel({logdir=>$logdir,step=>$step,pid=>$$,status=>$ERROR});
	#we already print runtime info by parent
	#die "\n\n${splitter}ERROR$splitter\n[ => SeqMule Execution Status: step $step FAILED at $time, $msg, $total_min min]\n";
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
sub writeJOBID {
    #modify config for specific step
    #change status from wait to start
    #at this point, config is NOT in sync with logdir
    #this function is used to prevent this particular step being
    #run twice by paranet proc.
    my $opt = shift;
    my $file=$opt->{file};
    my $step = $opt->{step};
    my $config = $opt->{config};
    my $logdir = $opt->{logdir};
    my $jobid = $opt->{jobid};

    if(defined $jobid) {
	#this task is submitted by qsub
	#so we need to remove existing JOBID sentinel files
	#and create new one
	my $step_dir = File::Spec->catdir($logdir,$step);
	my $sentinel = File::Spec->catfile($step_dir,"JOBID.$jobid");
	my $old_jobid_file = File::Spec->catfile($step_dir,"JOBID.*");
	!system("rm -f $old_jobid_file") or croak("failed to unlink step $step JOBID.*: $!\n");
	&touch($sentinel);
    }
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
    my $logdir = $opt->{logdir};
    my $step_dir = File::Spec->catdir($logdir,$step);

    my $step_ref = $config->{$step};
    if ($step_ref->{$CONFIG_KEYWORD{STATUS}} eq $WAIT) {
	$step_ref->{$CONFIG_KEYWORD{STATUS}} = $START;
    } else {
	#task is not waiting, something goes wrong
	croak("ERROR: step $step is not waiting\n");
    }
    #create STATUS.started sentinel
    #because parent will sync with log dir soon
    #we need to let it know this task has started
    my $sentinel = File::Spec->catfile($step_dir,"STATUS.$START");
    !system("rm -f ".File::Spec->catfile($step_dir,"STATUS.*")) or croak("failed to rm step $step STATUS.*: $!\n");
    &touch($sentinel);
    #here we should not sync config with config file
    #if this proc is stopped somewhere, we end up with incorrect exec status
}
sub create_sentinel {
    #remove existing STATUS files
    #create STATUS and PID sentinel files
    my $opt = shift;
    my $logdir=$opt->{logdir};
    my $n=$opt->{step};
    my $pid=$opt->{pid};
    my $status=$opt->{status};
    my $step_dir = File::Spec->catdir($logdir,$n);
    if($opt->{status}) {
	    my $sentinel = File::Spec->catfile($step_dir,"STATUS.$status");
	    !system("rm -f ".File::Spec->catfile($step_dir,"STATUS.*")) or croak("failed to rm step $n STATUS.*: $!\n");
	    &touch($sentinel);
    }
    if($pid) {
	    my $pid_file = File::Spec->catfile($step_dir,"PID.$pid");
	    !system("rm -f ".File::Spec->catfile($step_dir,"PID.*")) or croak("failed to rm step $n STATUS.*: $!\n");
	    &touch($pid_file);
    }
}
sub firstScan {
    #remove existing sentinel files in logdir
    #change job status to finished for all jobs after specified step #
    my $opt = shift;
    my $file = $opt->{file};
    my $config = $opt->{config};
    my $step= $opt->{step};
    my $logdir = $opt->{logdir};
#clean up unfinished processes in config
    for my $i(1..&getTotalStep($config)) {
	if($step) {
	    if($i >= $step) {
		#change all status to waiting
		$config->{$i}->{$CONFIG_KEYWORD{STATUS}} = $WAIT;
	    } elsif ($i < $step) {
		#change all status to finished
		$config->{$i}->{$CONFIG_KEYWORD{STATUS}} = $FINISH;
	    } 
	} else {
	    #find last finished step when step is not defined
	    #change started/error to waiting after last finished step
	    if($config->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH) {
		next if defined $config->{$i+1}->{$CONFIG_KEYWORD{STATUS}} and 
		$config->{$i+1}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH;
		$step = $i;
	    }
	}
    }
    unless($step) {
	$step = 1;
	for my $i(1..&getTotalStep($config)) {
	    if($i >= $step) {
		#change all status to waiting
		$config->{$i}->{$CONFIG_KEYWORD{STATUS}} = $WAIT;
	    } elsif ($i < $step) {
		#change all status to finished
		$config->{$i}->{$CONFIG_KEYWORD{STATUS}} = $FINISH;
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

sub syncStatus {
    #synchronize config file and logdir based on rules described in $SENTINEL_FILE_DESC
    warn "DEBUG(PID:$$): about to syncstatus \n" if $debug;
    my $opt = shift;
    my $logdir = $opt->{logdir};
    my $config = $opt->{config};
    my $file = $opt->{file};
    my $direction = $opt->{direction}; #log2config, config2log

    if($direction eq 'log2config') {
	#sync sentinel to config
	opendir(my $dh,$logdir) or croak ("ERROR: can't read $logdir: $!\n");
	while(my $i = readdir($dh) ) {
	    #make sure $i is relative path
	    $i = basename $i;
	    next unless $i =~ /^\d+$/;
	    if(defined $config->{$i}->{$CONFIG_KEYWORD{STATUS}} and 
		$config->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH) {
		#the first few tasks are finished, skip them altogether
		next;
	    } else {
		#grab JOBID, PID, status
		opendir(my $dh_i,File::Spec->catfile($logdir,$i)) or croak ("ERROR: can't read $i in $logdir: $!\n");
		my ($jobid, $pid, $status);
		while(my $j = readdir($dh_i) ) {
		    $j = basename $j;
		    if($j =~ /JOBID\.(\d+)/) {
			$jobid = $1;
		    } elsif ($j =~ /PID\.(\d+)/) {
			$pid = $1;
		    } elsif ($j =~ /STATUS\.(\w+)/) {
			$status = $1;
		    }
		}
		closedir $dh_i;
		#consider when these files are temporarily unavailable
		$config->{$i}->{$CONFIG_KEYWORD{STATUS}} = $status if $status;
		$config->{$i}->{$CONFIG_KEYWORD{PID}} = $pid if $pid;
		$config->{$i}->{$CONFIG_KEYWORD{JOBID}} = $jobid if $jobid;
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
	for my $i(1..&getTotalStep($config)) {
	    if(defined $config->{$i}->{$CONFIG_KEYWORD{STATUS}} and 
		$config->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH) {
		#the first few tasks are finished, skip them altogether
		next;
	    } else {
		my $task_dir = File::Spec->catfile($logdir,$i);
		my $i_ref = $config->{$i};
		!system("rm -rf $task_dir") or croak("failed to rm $task_dir: $!\n");
		!system("mkdir $task_dir") or croak("mkdir failed $task_dir: $!\n"); 
		croak("Missing field for step $i\n") unless defined $i_ref->{$CONFIG_KEYWORD{JOBID}} and
							    defined $i_ref->{$CONFIG_KEYWORD{PID}} and
							    defined $i_ref->{$CONFIG_KEYWORD{STATUS}} and
							    defined $i_ref->{$CONFIG_KEYWORD{MESSAGE}};
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
sub getNextCMD {
    my $config=shift;
    for my $i(1..&getTotalStep($config)) {
	#return first waiting task
	if(defined $config->{$i}->{$CONFIG_KEYWORD{STATUS}} and 
	   $config->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $WAIT) {
	    #return only if all dependencies fullfilled
	    unless(grep {$config->{$_}->{$CONFIG_KEYWORD{STATUS}} ne $FINISH} 
		(split /,/,$config->{$i}->{$CONFIG_KEYWORD{DEPENDENCY}})) {
		warn "DEBUG(PID:$$): next is step $i\n" if $debug;
		return (
		    $i,
		    $config->{$i}->{$CONFIG_KEYWORD{COMMAND}},
		    $config->{$i}->{$CONFIG_KEYWORD{MESSAGE}},
		    $config->{$i}->{$CONFIG_KEYWORD{NCPU_REQUEST}},
		);
	    }
	}
    }
    return ();
}
sub allDone {
    #check if all tasks are done based on config
    my $config = shift;
    my $done=1;
    for my $i(map{$config->{$_}} 1..&getTotalStep($config)) {
	if ($i->{$CONFIG_KEYWORD{STATUS}} ne $FINISH) {
	    $done = 0;
	}
    }
    return $done;
}
sub getUsedCPU {
    my $config=shift;
    my $n=0;

    for my $i(1..&getTotalStep($config)) {
	if (defined $config->{$i}->{$CONFIG_KEYWORD{STATUS}} and
	    $config->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $START) {
	    $n += $config->{$i}->{$CONFIG_KEYWORD{NCPU_REQUEST}} if defined $config->{$i}->{$CONFIG_KEYWORD{NCPU_REQUEST}};
	}
    }
    return $n;
}
sub genTempScript {
    my @cmd=@_;
    my $tmp="/tmp/seqmule".rand($$).time()."script";
    open OUT,'>',$tmp or die "Can't write to $tmp: $!\n";
    print OUT "#!/bin/bash\nset -e\n"; #let shell run the script, exit at first error
    print OUT "set -o pipefail\n"; #let shell run the script, exit at first error
    print OUT join ("\n",@cmd);
    close OUT;
    chmod 0755,$tmp or die "Failed to chmod 755 on $tmp\n";
    return $tmp;
}
sub getRunningID {
    my $file=shift;
    my $config = Config::Tiny->read($file);
    my $logdir = $config->{$CONFIG_KEYWORD{SETTING_SECTION}}->{$CONFIG_KEYWORD{LOGDIR}};
    my @pid;
    my @jobid;
    my %steps;
    &syncStatus({logdir=>$logdir,config=>$config,file=>$file,direction=>'log2config'});
    for my $i(1..&getTotalStep($config)) {
	if ($config->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $START) {
	    my $pid = $config->{$i}->{$CONFIG_KEYWORD{PID}};
	    my $jobid = $config->{$i}->{$CONFIG_KEYWORD{JOBID}};
	    push @pid,$pid;
	    push @jobid,$jobid;
	    $steps{$i} = {pid=>$pid,jobid=>$jobid};
	}
    }
    #running PIDs may spawn child procs
    @pid = &getChildPID(@pid) if @pid and (grep {$_} @pid);
    warn "DEBUG(PID:$$): running PID: @pid\n" if $debug;
    warn "DEBUG(PID:$$): running JOBID: @jobid\n" if $debug;
    warn "DEBUG(PID:$$): running child PID:",`pgrep -P $pid[0]`,"\n" if $debug;
    return \@pid,\@jobid,\%steps;
}
sub checkVersion {
    my $allsetting = shift;
    my $v =$allsetting->{$CONFIG_KEYWORD{VERSION}};
    unless(defined $v && $COMPATIBLE_VERSION{$v}) {
	croak("ERROR: incompatible execution script version ".($v?$v:'')."\n".
	"Supported versions: ".join(" ",keys %COMPATIBLE_VERSION)."\n");
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
sub getTotalStep {
    my $config = shift;
    my $step_total = $config->{$CONFIG_KEYWORD{SETTING_SECTION}}->{$CONFIG_KEYWORD{STEPTOTAL}} or croak("ERROR: no steps found\n");
    return $step_total;
}
sub returnTDGChild {
    @{$TDG{$_[0]} || []};
}
sub checkUniqGen {
    #check if each obj is generated only once
    my @cmd = @{shift @_};
    my %objAndCMD;

    for my $i(0..$#cmd) {
	for my $j(@{$cmd[$i]->{out}}) {
	    if (defined $objAndCMD{$j->id}) {
		croak("ERROR: ".$j->id." generated twice: ".$objAndCMD{$j->id}." and ".$i."\n");
	    } else {
		$objAndCMD{$j->id} = $i;
	    }
	}
    }
}
sub constructTDG {
    my @cmd = @{shift @_};
    my %tdg_local;
    #figure out which command generates each obj
    my %objAndCMD; #keeps SeqUtils obj and commands where it is used
    if(&checkUniqGen(\@cmd)) {
	for my $i(0..$#cmd) {
	    for my $j(@{$cmd[$i]->{in}}) {
		if (defined $objAndCMD{$j->id}) {
		    push @{$objAndCMD{$j->id}},$i;
		} else {
		    $objAndCMD{$j->id} = [$i];
		}
	    }
	}
    }
    #figure out TDG
    #TDG key is index of each command, value is indeces of children
    for my $i(0..$#cmd) {
	$tdg_local{$i} = [];
	for my $j(@{$cmd[$i]->{out}}) {
	    push @{$tdg_local{$i}},@{$objAndCMD{$j->id} || []};
	}
    }
    return %tdg_local;
}
sub constructTDGREVERSE {
    my @cmd = @{shift @_};
    my %tdg_rev_local;
    #figure out TDG_REVERSE
    my %objAndCMD; #keeps SeqUtils obj and commands where it is used
    for my $i(0..$#cmd) {
	for my $j(@{$cmd[$i]->{out}}) {
	    if (defined $objAndCMD{$j->id}) {
		croak("ERROR: ".$j->id." generated twice: ".$objAndCMD{$j->id}." and ".$i."\n");
	    } else {
		$objAndCMD{$j->id} = [$i];
	    }
	}
    }
    #TDG_REVERSE key is index of each command, value is indeces of parent
    for my $i(0..$#cmd) {
	$tdg_rev_local{$i} = [];
	for my $j(@{$cmd[$i]->{in}}) {
	    push @{$tdg_rev_local{$i}},@{$objAndCMD{$j->id} || []};
	}
    }
    return %tdg_rev_local;
}
sub submitJob {
    my $submitCmd = shift;
    my @cmd = @_;
    my $script = &genTempScript(@cmd);
    warn "submitting: $submitCmd $script\n" if $debug;
    open SUBMIT,'-|',"$submitCmd $script" or croak("$submitCmd $script fails: $!\n");
    my $jobid = <SUBMIT>;
    #Your job 55302 ("STDIN") has been submitted
    chomp $jobid;
    if($jobid =~ /Your job (\d+) \(".*?"\) has been submitted/) {
	$jobid = $1;
    } else {
	croak("$jobid is expected to look like: Your job 55302 (\"STDIN\") has been submitted\n");
    }
    return $jobid;
}
sub stop {
    my $script = shift;
    my $sge = shift;
    my ($pid,$jobid)=&getRunningID($script);
    if(@$pid or @$jobid) {
	if ($sge) {
	    warn "qdel @$jobid\n" if $debug;
	    for (@$jobid) {
		system("qdel $_");
	    }
	} else {
	    warn "killing @$pid\n" if $debug;
	    for (@$pid) {
		system("kill -9 $_ 2>/dev/null");
		#!system("kill -9 $_") or warn "Failed to kill $_: $!\n";
	    }
	}
    } else {
	warn "\nWARNING: didn't find any child\n";
    }
    die "\nWARNING: (PID:$$) Ctrl-C signal received, dying...\n";
}
sub getChildPID {
    #return @pid and all their descendent PIDs
    my @pid = @_;
    warn "DEBUG(PID:$$):running PID: @pid\n" if $debug;
    warn "DEBUG(PID:$$):running child PID:",`pgrep -P $pid[0]`,"\n" if $debug;
    my @return;
    if (@pid) {
	for my $pid(@pid) {
	    #kill youngest children of pid first, then itself
	    my @all_pid;
	    my @next_round=`pgrep -P $pid`;
	    my @tmp_pid;

	    chomp @next_round;
	    unshift @all_pid,$pid,@next_round;

	    CHECK_PID: for my $current(@next_round) {
		my @child=`pgrep -P $current`;
		chomp @child;
		push @tmp_pid,@child;
		unshift @all_pid,@child;
	    }
	    @next_round=@tmp_pid;
	    @tmp_pid=() and next CHECK_PID if (@next_round);
	    push @return,@all_pid;
	}
    }
    return @return;
}
sub getSubmitCmd {
    my $opt = shift;
    my $submit_cmd = $opt->{submitCmd};
    my $cpu_request = $opt->{cpu};
    my $logdir = $opt->{logdir};
    my $step = $opt->{step};
    if($submit_cmd =~ /XCPUX/) {
	$submit_cmd =~ s/XCPUX/$cpu_request/;
    } else {
	croak("ERROR: $submit_cmd should have 'XCPUX' keyword\n");
    }
    #add -e,-o options
    if($submit_cmd !~ /-e|-o/) {
	my $taskDir = File::Spec->catdir($logdir,$step);
	my $stderr = File::Spec->catfile($taskDir,"stderr");
	my $stdout = File::Spec->catfile($taskDir,"stdout");
	$submit_cmd .= " -e $stderr -o $stdout ";
    }
    if($submit_cmd !~ /-S/) {
	$submit_cmd .= " -S /bin/bash ";
    }
    return $submit_cmd;
}
sub checkQsubTemplate {
    my $qsub = shift;
    #must have 
    #qsub, -V, -cwd, -pe, XCPUX
    croak("ERROR: qsub required in <<$qsub>>\n") unless $qsub =~ /qsub/;
    croak("ERROR: -V required in <<$qsub>>\n") unless $qsub =~ /-V/;
    croak("ERROR: -cwd required in <<$qsub>>\n") unless $qsub =~ /-cwd/;
    croak("ERROR: -pe required in <<$qsub>>\n") unless $qsub =~ /-pe/;
    croak("ERROR: XCPUX required after -pe in <<$qsub>>\n") unless $qsub =~ /-pe.*?XCPUX/;
    #must not have
    #-S, -e, -o
    croak("ERROR: -S must be removed in <<$qsub>>\n") if $qsub =~ /-S/;
    croak("ERROR: -e must be removed in <<$qsub>>\n") if $qsub =~ /-e/;
    croak("ERROR: -o must be removed in <<$qsub>>\n") if $qsub =~ /-o/;
}
sub signal_A_PID { 
    #tries to signal a PID
    #if no reponse, then it's dead
    #return 0 for dead PID, 1 otherwise
    my $pid = shift;
    my $waiting_time=10;
    my $second_check=0;

    unless (kill 0,$pid) { #try to signal the proc, if not successful, wait a monment, try again, if failed, mark it as error
	#this measure avoids false error when the status is not updated immediately upon exit
	$second_check=1;
    }
    if ($second_check) {
	sleep $waiting_time;
	unless (kill 0,$pid) { 
	    return 0;
	}
    }
    return 1;
}
sub checkRunningID {
    #check if job or proc is running
    #return step number for tasks that are marked started
    #but actually are not running
    my $script = shift;
    my $sge = shift;
    my @return;
    my ($pid,$jobid,$steps)=&getRunningID($script);

    #$steps{$step} = {pid=>PID,jobid=>JOBID}
    if($sge) {
	for my $i(keys %$steps) {
	    warn "DEBUG: checking JOBID ".$steps->{$i}->{jobid}." in step $i\n" if $debug;
	    !system("qstat -j ".$steps->{$i}->{jobid}." 1>/dev/null 2>/dev/null") or push @return,$i;
	}
    } else {
	    #there might be bugs here
	    #fix it later
	    #for my $i(keys %$steps) {
	    #    warn "DEBUG: checking PID ".$steps->{$i}->{pid}." in step $i\n" if $debug;
	    #    push @return,$i unless &signal_A_PID($steps->{$i}->{pid});
	    #}
    }
    return @return;
}
sub status2error {
    my $opt = shift;
    my $logdir = $opt->{logdir};
    my $errorStep = $opt->{errorStep};
    for my $i(@$errorStep) {
	warn "ERROR: STEP $i was started, but actually not running.\n";
	&create_sentinel({logdir=>$logdir,step=>$i,status=>$ERROR});
    }

}
sub checkError {
    my $opt = shift;
    my $logdir = $opt->{'logdir'};
    my $file = $opt->{'file'};
    my $config = $opt->{config};
    my $time= &getReadableTimestamp;
    my (@steps,@msg);
    my $cmd;
    for my $i(1..&getTotalStep($config)) {
	next unless $config->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $ERROR; 
	$cmd .= $config->{$i}->{$CONFIG_KEYWORD{COMMAND}}."\n";
	push @steps,$i;
	push @msg,$config->{$i}->{$CONFIG_KEYWORD{MESSAGE}};
    }
    if(@steps) {
	my $cwd=$ENV{PWD};
	for my $i(0..$#steps){
	    warn "\n\n${splitter}ERROR$splitter\n[ => SeqMule Execution Status: step ".$steps[$i]." FAILED at $time, ".$msg[$i]."]\n";
	}
	die "ERROR: command failed\n",
	$cmd,
	"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n",
	"After fixing the problem, please execute 'cd $cwd' and 'seqmule run $file' to resume analysis.\n",
	"!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
    }
}
sub countFinish {
    #count # of finished jobs
    my $config = shift;
    my @steps;
    for my $i(1..&getTotalStep($config)) {
	next unless $config->{$i}->{$CONFIG_KEYWORD{STATUS}} eq $FINISH; 
	push @steps,$i;
    }
    return @steps;
}
sub reportFinish {
    #return already finished steps
    #report any newly finished steps
    my $config = shift;
    my @alreadyFinish = @_;
    my @currentFinish = &countFinish($config);
    if (my $newlyDone = @currentFinish - @alreadyFinish) {
	for my $i(&SeqMule::Utils::getArrayDiff(\@currentFinish,\@alreadyFinish)) {
	    my $time = &getReadableTimestamp;
	    my $msg = $config->{$i}->{$CONFIG_KEYWORD{MESSAGE}};
	    warn "[ => SeqMule Execution Status: step $i is finished at $time, $msg]\n\n";
	}
    }
    @alreadyFinish = &countFinish($config);
    return @alreadyFinish;
}

1;

=head



#qsub
echo './worker fast.script 2 s && if samtools view -b ../father_bwa.sort.rmdup.bam 1 > father-1.bam;then ./worker fast.script 2 f;else ./worker fast.script 2 e;fi' | qsub -V -cwd -l h_vmem=2g	1	18	finished
echo './worker fast.script 3 s && if samtools view -b ../father_bwa.sort.rmdup.bam 2 > father-2.bam;then ./worker fast.script 3 f;else ./worker fast.script 3 e;fi' | qsub -V -cwd -l h_vmem=2g	1	18	finished

=cut
