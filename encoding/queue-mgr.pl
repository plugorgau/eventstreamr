#!/usr/bin/perl
#
# daemon -Ryan Armanasco - 2012-10-12 - much hacked from that base...
# queue processing -Leon Wright - 2013-01-30
#
# Over-engineering a Perl threaded queue daemon.

# FIXME - Need to rewrite sanely from scratch, it only works in foreground, not as an actual daemon...

use strict;
use Data::Dumper;
use POSIX ":sys_wait_h";
use Sys::Hostname;
use File::Copy;
use File::Basename;
use Log::Log4perl;
use Proc::Daemon;

# CLI Options
use Getopt::Long;
my $options = {daemons => '2', logfile => '/tmp/queue-mgr.log', loglevel => 'INFO' };
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

# path details
my $hostname = hostname;
my $basepath = '/storage-server/queue';
my $todo = "$basepath/todo";
my $inprogress = "$basepath/wip";
my $done = "$basepath/done";
my $sleeprandom = 10;
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

# number of children to spawn (parent + children)
my $daemons = $options->{daemons};
my $children = $daemons - 1;
$logger->info("Starting Parent and $children Child(ren)");

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

my %kids;
tie %kids, 'IPC::Shareable', $glue, { %options } or
    die "server: tie failed\n";

$|=1; # do not buffer output

#ignore child processes to prevent zombies
$SIG{CHLD} = 'IGNORE';

# gracefully handle kill requests
$SIG{"INT"} = $SIG{"TERM"} = \&cleanup_and_exit;
sub cleanup_and_exit {
  my $sig = @_;
  #print "SIGTERM (kill 15) received - cleaning up\n";
  
  # wait for kids ?
  foreach my $pid (keys %kids) {
    waitpid $pid, 0; # this will wait for all childen to die before killing the parent - if children will naturally exit as a course of their jobs
    $logger->info("Closing child $pid");
    
    #forcefully clean up
    unless ( $pid =~ /test/ ) { kill(15, $pid); } # hacky, not sure why the test values get set... FIXME
  }
  
  IPC::Shareable->clean_up; # remove shared memory structure - can make it persist without this though - may be faulty too!
  %kids = (); # so we'll clear it this way too!
  
  # it's a good idea to exit when we are told to
  $logger->info ("Daemon terminated");
  exit(0);
}

if ($options->{loglevel} ne 'DEBUG') {
  Proc::Daemon->init;
}



# spawn a child - this might be a loop to spawn a child for each temp probe etc.
my $counter;
my $child;
while (1==1) {
  sleep (int(rand($sleeprandom)) + 5);
  if ( $counter < $daemons) {
    die "Can't fork: $!" unless defined ($child = fork());
    $counter++;
    if ($child == 0) {   #i'm the child!
        my $kid = childsub();
        
        #if the child returns, then just exit;
        delete $kids{$kid};
        $counter--;
        exit 0;
      } else {   #i'm the parent!
        $kids{$child} = 1;
    }
  }
} # main holding loop

#############
# CHILD SUB
#############
sub childsub {
  # IPC Stats
  use IPC::Shareable;
  my $glue = 'queue-manager';
  my %options = (
      create    => 0,
      exclusive => 0,
      mode      => 0644,
      destroy   => 0,
      );
  my %kids;
  tie %kids, 'IPC::Shareable', $glue, { %options } or
      die "tie failed - abort";
  
  my $count; 
  my @scripts = glob("$todo/*.sh");
  foreach my $script (@scripts) {
    if ( -e $script && $count < 1 ) {
      # Quick and Dirty way to hopefully avoid multiple nodes locking the same render job.
      $script = fileparse($script);
      $logger->info("Processing $script");
      move("$todo/$script", $inprogress);
      my $capture = `bash $inprogress/$script`; # Backticks are bad... IPC::System::Simple was failing though... FIXME
      print "$capture \n";
      move("$inprogress/$script", $done);
      
      # I will write some post sanity checking on the rendered file.
      #
      $logger->info("$script finished");
      $count++;
    }
  }
  return $$;
} # childsub

