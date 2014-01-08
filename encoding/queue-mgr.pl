#!/usr/bin/perl
#
# daemon -Ryan Armanasco - 2012-10-12
# queue processing -Leon Wright - 2013-01-30
#
# Over-engineering a Perl threaded queue daemon.

use strict;
use Data::Dumper;
use POSIX ":sys_wait_h";
#use IPC::System::Simple qw(capture $EXITVAL EXIT_ANY);
use Sys::Hostname;
use File::Copy;
use File::Basename;
use Log::Log4perl;

# CLI Options
use Getopt::Long;
my $options = {daemons => '3', logfile => '/tmp/queue-mgr.log', loglevel => 'INFO' };
GetOptions($options, "daemons=i", "logfile=s", "loglevel=s", "help");

if ( defined $options->{help} ) {
  print "    The following cli options are available \n";
  print "         --daemons=        : number of daemons to spawn including parent \n";
  print "         --loglevel=debug  : sets debug mode, all logging to STDOUT and does not spawn as daemon \n";
  print "         --logpath=        : where to output log file. defaults to /tmp/renderslave.log \n";
  exit;
}

# PID File
open (MYFILE, '>/tmp/renderslave.pid');
print MYFILE "$$";
close (MYFILE); 
print "Parent PID: $$\n";

# path details
my $hostname = hostname;
my $basepath = '/storage-server/queue';
my $todo = "$basepath/todo";
my $inprogress = "$basepath/wip";
my $done = "$basepath/done";
my $sleeprandom = 30;
$options->{loglevel} = uc $options->{loglevel};

my $log_conf = qq(
  log4perl.rootLogger              = $options->{loglevel}, LOG1
  log4perl.appender.LOG1           = Log::Log4perl::Appender::File
  log4perl.appender.LOG1.filename  = $options->{logfile}
  log4perl.appender.LOG1.mode      = append
  log4perl.appender.LOG1.layout    = Log::Log4perl::Layout::PatternLayout
  log4perl.appender.LOG1.layout.ConversionPattern = %d %p %m %n
);

Log::Log4perl::init(\$log_conf);
my $logger = Log::Log4perl->get_logger();

if (! -d '/tmp/veyepar' ) {
  $logger->info("Making /tmp/veyepar");
  mkdir '/tmp/veyepar';
}

# number of children to spawn (parent + children)
my $daemons = $options->{daemons};
my $children = $daemons - 1;
$logger->info("Starting Parent and $children Child(ren)");
print "Starting Parent and $children Child(ren) \n";

# session counters - setup IPC shareable memory space

# Create shared memory object
my $glue = 'queue-manager';
my %options = (
    create    => 'yes',
    exclusive => 0,
    mode      => 0644,
    destroy   => 'no', # 'yes' doesn't seem to work - we handle on exit differently
                        #setting to yes causes $counters{start} to persist and other concurrency issues
);

my %counters;
tie %counters, 'IPC::Shareable', $glue, { %options } or
    die "server: tie failed\n";

# forcefully clear
$counters{runs} = $counters{kids} = 0;

$|=1; # do not buffer output

#ignore child processes to prevent zombies
$SIG{CHLD} = 'IGNORE';

my %kids;
tie %kids, 'IPC::Shareable', "render_kids", { %options } or
    die "server: tie failed\n";

# gracefully handle kill requests
$SIG{"INT"} = $SIG{"TERM"} = \&cleanup_and_exit;
sub cleanup_and_exit {
  my $sig = @_;
  #print "SIGTERM (kill 15) received - cleaning up\n";
  
  # wait for kids ?
  foreach my $pid (keys %kids) {
    waitpid $pid, 0; # this will wait for all childen to die before killing the parent - if children will naturally exit as a course of their jobs
    $logger->info("Closing child $pid");
    print "Closing child $pid \n";
    
    #forcefully clean up
    unless ( $pid =~ /test/ ) { kill(15, $pid); } # hacky, not sure why the test values get set... FIXME
  }
  
  IPC::Shareable->clean_up; # remove shared memory structure - can make it persist without this though - may be faulty too!
  %counters = (); # so we'll clear it this way too!
  %kids = (); # so we'll clear it this way too!
  
  # it's a good idea to exit when we are told to
  $logger->info ("Daemon terminated");
  print "Daemon terminated \n";
  exit(0);
}


use POSIX 'setsid';
sub daemonize {
  # detach from console
  $logger->info("Running as daemon");
  chdir '/'               or die "Can't chdir to /: $!";
  open STDIN, '/dev/null' or die "Can't read /dev/null: $!";
  open STDOUT, '>/dev/null'
                          or die "Can't write to /dev/null: $!";
  defined(my $pid = fork) or die "Can't fork: $!";
  exit if $pid;
  die "Can't start a new session: $!" if setsid == -1;
  open STDERR, '>&STDOUT' or die "Can't dup stdout: $!";
}

# comment below out to not daemonise and see what is going on
##
unless ($options->{loglevel} = 'DEBUG' ) {
  &daemonize;  open STDOUT, '>/dev/null' or $logger->logdie("Can't write to /dev/null: $!");
}

# DAEMON HOLDING LOOP
# use this to hold the progam open and spawn children from here

my $child = 0; my $runs = 1;

# spawn a child - this might be a loop to spawn a child for each temp probe etc.

while (1==1) {
  print "Sleeping... \n";
  sleep (int(rand($sleeprandom)) + 11);
  my @scripts = glob("$todo/*.sh");
  print "looping...\n";
  if ( $counters{runs} < $daemons) {
    print "Counters: $counters{runs} - Runs: $daemons\n";
    die "Can't fork: $!" unless defined ($child = fork());
    if ($child == 0) {   #i'm the child!
        print "child control hand-over point\n";
        $counters{runs}++;
        my $kid = childsub(@scripts);
        
        #if the child returns, then just exit;
        delete $kids{$kid};
        $counters{runs}--;
        exit 0;
      } else {   #i'm the parent!
        print "parent continuation point after fork of child $child\n";
        $kids{$child} = 1;
    }
  }
} # main holding loop

#############
# CHILD SUB
#############
sub childsub {
  my @scripts = shift;
  
  # IPC Stats
   use IPC::Shareable;
   my $glue = 'queue-manager';
   my %options = (
       create    => 0,
       exclusive => 0,
       mode      => 0644,
       destroy   => 0,
       );
   my %counters;
   tie %counters, 'IPC::Shareable', $glue, { %options } or
       die "tie failed - abort";
  
  print "child spawned, I am talking from the child\n";

  print "Child Daemon ID: $runs\n";
  my $count; 
  foreach my $script (@scripts) {
    if ( -e $script && $count < 1 ) {
      # Quick and Dirty way to hopefully avoid multiple nodes locking the same render job.
      $script = fileparse($script);
      $logger->info("Processing $script");
      move("$todo/$script", $inprogress);
      print "Child Daemon $runs Processing... \n";
      my $capture = `bash $inprogress/$script`; # Backticks are bad... IPC::System::Simple was failing though... FIXME
      print "$capture \n";
      move("$inprogress/$script", $done);
      print "Done...! \n";

      #
      # I will write some post sanity checking on the rendered file.
      #
      $logger->info("$script finished");
      $count++;
    }
  }
  return $$;
} # childsub

