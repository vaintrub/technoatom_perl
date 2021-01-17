#!/usr/bin/env perl

use strict;
use warnings;
use POSIX qw(sys_wait_h);
use 5.016;
use Scalar::Util qw(looks_like_number);
use File::chdir;




my $pid;
my $input;
my $bg_flag;#when & in the end of input string
my %inf_jobs;#information about processes in jobs
my @pid_jobs; #contains  the pid of jobs
my $bg_last_pid; #the hash {'pid' => "XXXXXX", 'numJob' => "X" } it is a last process which we sent in background
my $fg_pid; #process in foregroung now

$SIG{INT} = sub {kill 'TERM', $fg_pid if ($fg_pid)};
$SIG{CHLD} = sub {
    while (my $pid = waitpid(-1, WNOHANG)){
        last if $pid == -1;
        my $status = $? >> 8;
        #warn "Something was wrong\n" if ($status != 0);
        if ($inf_jobs{$pid}){#when the process has finished its work and it was in a jobs list
            my $id_done_job;
            for (0..$#pid_jobs){ #find the number of job which finished and delete it
                if ($pid_jobs[$_] == $pid) {
                    $id_done_job = $_ + 1;
                }
            }
            for ($id_done_job-1..$#pid_jobs-1) {
                $pid_jobs[$_] = $pid_jobs[$_+1];
            }
            pop @pid_jobs;
            if (@pid_jobs != 0) { #we do the process that preceded the one that ended, the last one on the background
                $bg_last_pid->{pid} = $pid_jobs[-1];
                $bg_last_pid->{numJob} = $#pid_jobs;
            } 
            if (WIFEXITED($?)) {
                # The process was stopped on its own 
                print "\n[$id_done_job] $pid  done    $inf_jobs{$pid}->[1]\n";
            } else {
                # The process got signal INT
                print "\n[$id_done_job] $pid  terminated    $inf_jobs{$pid}->[1]\n";
            }
            delete $inf_jobs{$pid};
        }
    }
};

$SIG{TSTP} = sub {
    if ($fg_pid){# stopping the process which now in the foreground
        print "\n";
        kill 'STOP', $fg_pid; #STOP instead TSTP because TSTP is sended to all process in group
        unless ($inf_jobs{$fg_pid}) { #add the pid in jobs if it was not already there
            push @pid_jobs, $fg_pid;
            $inf_jobs{$fg_pid}->[1] = $input;
        }
        $inf_jobs{$fg_pid}->[0] = "suspended";

        $bg_last_pid->{pid} = $fg_pid;
        for (1..@pid_jobs) {
            if ($pid_jobs[$_-1] == $fg_pid) {
                $bg_last_pid->{numJob} = $_ - 1;
            }
        }

        print "[". ($bg_last_pid->{numJob} + 1) . "]" . "   $fg_pid $inf_jobs{$fg_pid}->[0]     $inf_jobs{$fg_pid}->[1]\n";
        $fg_pid = 0;
    }
};

my $built_in_func = {
    cd => sub {
        shift @_;
        my $dir = $ENV{HOME} if @_ == 0;
        ($dir) = @_ if @_ != 0; 
        chdir $dir;
        $ENV{OLDPWD} = $ENV{PWD};
        $ENV{PWD} = $CWD;
    },
    pwd => sub {
        print "$ENV{PWD}\n";
    },
    kill =>sub {
        shift @_;
        my $kill;
        if (looks_like_number($_[0])){# if the first argument its pid so the default signal is kill
            $kill = sub {kill 'KILL', $_[0]};
        } else {
            my $sig = shift @_;
            $kill = sub {kill $sig, $_[0]};
        }
        for (@_) {
            looks_like_number ($_) ? $kill->($_) : warn "kill: illegal pid: $_\n";
        }
    }, 
    echo => sub {
        shift @_;
        print "@_" . "\n";
    },
    fg =>sub {
        shift @_;
        if (@pid_jobs) {
            if (@_ != 0) {
                $fg_pid = $pid_jobs[$_[0]-1];
            }else {
                $fg_pid = $bg_last_pid->{pid};
                $_[0] = $bg_last_pid->{numJob} + 1;
            }
            if ($inf_jobs{$fg_pid}->[0] eq "suspended") {
                kill 'CONT', $fg_pid;
                $inf_jobs{$fg_pid}->[0] = "running";
                print "[".$_[0]."]"." ".$fg_pid."  "."continued"."  ".$inf_jobs{$fg_pid}->[1]."\n";
            } else {
                print "[".$_[0]."]"." ".$fg_pid."  ".$inf_jobs{$fg_pid}->[0]."  ".$inf_jobs{$fg_pid}->[1]."\n";
            }
        }
        waitpid ($fg_pid, WUNTRACED);
    }, 
    bg => sub {
        shift @_;
        if (@pid_jobs) {
            if (@_ != 0) {
                $bg_last_pid->{pid} = $pid_jobs[$_[0]-1];
                $bg_last_pid->{numJob} = $_[0] - 1;
            }
            kill 'CONT', $bg_last_pid->{pid};
            if ($inf_jobs{$bg_last_pid->{pid}}->[0] eq "running") {
                print "$bg_last_pid->{pid} - already running\n";
            } else {
                $inf_jobs{$bg_last_pid->{pid}}->[0] = "running";
                print "[".($bg_last_pid->{numJob}+1)."]"." ".$bg_last_pid->{pid}." "."continued"." ".$inf_jobs{$bg_last_pid->{pid}}->[1]."\n";
            }
        }
    },
    jobs => sub {
        for (1..@pid_jobs) {
            print "[$_]"." ".$pid_jobs[$_ - 1]."   ".$inf_jobs{$pid_jobs[$_ - 1]}->[0]."  ".$inf_jobs{$pid_jobs[$_ - 1]}->[1]."\n";
        }
    },
};


sub is_interactive {
    return -t STDIN && -t STDOUT;
}

sub execute {
    my $cmd = shift;
    my $fh_in = 0;

    for (0..$#$cmd) {
        pipe(my $r, my $w) or die "pipe failed: $!";
        if (!$built_in_func->{$cmd->[$_]->[0]}) {
            if (!defined($pid = fork())) {
                die "Cannot fork: $!"; 
            } elsif ($pid == 0) {
                $SIG{TSTP} = 'IGNORE';#because the TSTP signal is sent to all processes in the group, so if i want to push ctrl-z
                                      #only parent process will handle it, also IGNORE not reset after exec.
                $SIG{INT} = 'IGNORE';
                open STDIN, "<&", $fh_in;
                if ($_ != $#$cmd){
                    open STDOUT, ">&", $w;
                } else {
                    close $w;    
                }
                close($r);
                exec @{$cmd->[$_]} ;
                exit;
            } else {
                if ($bg_flag) {
                   $inf_jobs{$pid} = ["running", $input];
                   push @pid_jobs, $pid;
                   $bg_last_pid = {'numJob' => $#pid_jobs, 'pid' => $pid};
                   print "[" . scalar(@pid_jobs) . "]" . "   $pid\n";
                }elsif ($_ == $#$cmd) {
                    $fg_pid = $pid;
                    waitpid($pid, WUNTRACED);
                }
                close $w;
                $fh_in = $r;
            }

        } else {
            open (my $oldout, ">&", STDOUT);
            if ($_ != $#$cmd) {
                open (STDOUT, ">&", $w);
                $fh_in = $r;
            }else {
                close $w;                
            }
            $built_in_func->{$cmd->[$_]->[0]}->(@{$cmd->[$_]});
            close($w);
            open(STDOUT, ">&",$oldout);
            close($oldout);
        } 
    }
}
sub parse_cmd {
    my $input = shift;
    my $arg = [split(/\|/, $input)]; 
    my $cmd = [];
    for (@$arg) {
        push @$cmd, [/(?|\'(.*?)\'|\"(.*?)\"|(\S+))/g];
    }
    return $cmd;
}

while (is_interactive()) {
    $fg_pid = 0;
    print ">> ";
    $input = <>;
    chomp $input;
    last if $input eq "bye" || $input eq "exit";

    if ($input =~ /&\s*$/) {
        $bg_flag = 1;
        $input =~ s/&\s*//;
    }

    next if ($input =~ /^\s*$/);
    
    my $cmd = parse_cmd($input);
   
    execute($cmd);

    $bg_flag = 0;
}
print "Goodbye$/";
