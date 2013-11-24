#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Proc::Daemon; # libproc-daemon-perl
use IPC::Shareable; # libipc-shareable-perl
use JSON; # libjson-perl
use Config::JSON; # libconfig-json-perl
use HTTP::Tiny;
use feature qw(switch);

# EventStremr Modules
use EventStreamr::Devices;
our $devices = EventStreamr::Devices->new();
use EventStreamr::Utils;
our $utils = EventStreamr::Utils->new();

# Load Local Config
my $localconfig = Config::JSON->new("$Bin/../settings.json");
$localconfig = $localconfig->{config};

# Station Config
my $stationconfig = Config::JSON->new("$Bin/../station.json");

# Commands
my $commands = Config::JSON->new("$Bin/../commands.json");

# Create shared memory object
my $glue = 'station-data';
my %options = (
    create    => 'yes',
    exclusive => 0,
    mode      => 0644,
    destroy   => 1,
);

my $shared;
tie $shared, 'IPC::Shareable', $glue, { %options } or
    die "server: tie failed\n";

$shared->{config} = $stationconfig->{config};
$shared->{config}{macaddress} = getmac();
$shared->{devices} = $devices->all();
$shared->{commands} = $commands->{config};
$shared->{dvswitch}{check} = 1; # check until dvswitch is found

# Dev
use Data::Dumper;

# Start Daemon
our $daemon = Proc::Daemon->new(
  work_dir => "$Bin/../",
);

our $daemons;
#$daemons->{main} = $daemon->Init; # comment to run on cli
  
$daemons->{main}{run} = 1;
$SIG{INT} = $SIG{TERM} = sub { 
      $shared->{config}{run} = 0;
      $daemons->{main}{run} = 0; 
      IPC::Shareable->clean_up_all; 
};

print "Checking for controller\n";
my $response = HTTP::Tiny->new->get("http://$localconfig->{controller}:5001/station/$shared->{config}{macaddress}");
print Dumper($response);

if ($response->{success} && $response->{status} == 200 ) {
  my $content = from_json($response->{content});
  print Dumper($content);
  if ($content->{result} == 200 && defined $content->{config}) {
    $shared->{config}->{station} = $content->{config};
    $stationconfig->{config} = $shared->{config};
    $stationconfig->write;
  }
}

# Run all connected devices - need to get devices to return an array
if ($shared->{config}{devices} eq 'all') {
  $shared->{config}{devices} = $shared->{devices}{array};
}

while ($daemons->{main}{run}) {
  # If we're restarting, we should trigger check for dvswitch
  if ($shared->{config}{run} == 2) {
    print "Restart Triggered\n";
    $shared->{dvswitch}{check} = 1;
  }

  # Process the roles
  foreach my $role (@{$shared->{config}->{roles}}) {
    given ( $role->{role} ) {
      when ("mixer")    { mixer();  }
      when ("ingest")   { ingest(); }
      when ("stream")   { stream(); }
    }
  }

  # 2 is the restart all processes trigger
  # $daemon->Kill_Daemon does a Kill -9, so if we get here they procs should be dead. 
  if ($shared->{config}{run} == 2) {
    $shared->{config}{run} = 1;
  }

  # Until found check for dvswitch - continuously hitting dvswitch with an unknown client caused high cpu load
  unless ( $shared->{dvswitch}{running} && ! $shared->{dvswitch}{check} ) {
    if ( $utils->port($shared->{config}->{mixer}{host},$shared->{config}->{mixer}{port}) ) {
      print "DVswitch found Running\n";
      $shared->{dvswitch}{running} = 1;
      $shared->{dvswitch}{check} = 0; # We can set this to 1 and it will check dvswitch again.
    }
  }
   
  sleep 1;
}

## Ingest
sub ingest {
  foreach my $device (@{$shared->{config}{devices}}) {
    # Build command for execution and save it for future use
    unless ($daemons->{$device->{id}}{command}) {
      $daemons->{$device->{id}}{command} = commands($device->{id},$device->{type});
    }

    # If we're supposed to be running, run.
    if ($shared->{config}{run} == 1) {
      # Get the running state + pid if it exists
      my $state = $utils->get_pid_command($device->{id},$daemons->{$device->{id}}{command},$device->{type}); 

      unless ($state->{running}) {
        print "Connect $device->{id} to DVswitch\n";
        # Spawn the Ingest Command
        my $proc = $daemon->Init( {  
             exec_command => $daemons->{$device->{id}}{command},
        } );
        # Set the running state + pid
        $state = $utils->get_pid_command($device->{id},$daemons->{$device->{id}}{command},$device->{type}); 
      }
      
      # Need to find the child of the shell, as killing the shell does not stop the command
      $daemons->{$device->{id}} = $state;
      
    } elsif (defined $daemons->{$device->{id}}{pid}) {
      # Kill The Child
      if ($daemon->Kill_Daemon($daemons->{$device->{id}}{pid})) { 
        print "Stop $device->{id}\n";
        $daemons->{$device->{id}}{running} = 0;  
        $daemons->{$device->{id}}{pid} = undef; 
      }
    }
  } 
  return;
}

## Mixer
sub mixer {

  return;
}

## Stream
sub stream {

  return;
}

## Commands
sub commands {
  my ($id,$type) = @_;
  my $command = $shared->{commands}{$type};
  my %cmd_vars =  ( 
                    device  => $shared->{devices}{$type}{$id}{device},
                    host    => $shared->{config}->{mixer}{host},
                    port    => $shared->{config}->{mixer}{port},
                  );

  $command =~ s/\$(\w+)/$cmd_vars{$1}/g;

  return $command;
} 

# Get Mac Address
sub getmac {
  # This is better, but can break if no eth0. We are only using it as a UID - think of something better.
  my $macaddress = `ip -o link show dev eth0 | grep -Po 'ether \\K[^ ]+'`;
  chomp $macaddress;
  return $macaddress;
}

__END__

(dev) bofh-sider:~/git/eventstreamr/station $ ps waux|grep dv
leon     19898  2.5  0.1 850956 24560 pts/12   Sl+  11:35   1:21 dvswitch -h localhost -p 1234
leon     20723  0.0  0.0   4404   612 ?        S    12:27   0:00 sh -c ffmpeg -f video4linux2 -s vga -r 25 -i /dev/video0 -target pal-dv - | dvsource-file /dev/stdin -h localhost -p 1234
leon     20724  8.0  0.1 130680 24884 ?        S    12:27   0:01 ffmpeg -f video4linux2 -s vga -r 25 -i /dev/video0 -target pal-dv -
leon     20725  0.1  0.0  10796   860 ?        S    12:27   0:00 dvsource-file /dev/stdin -h localhost -p 1234
leon     20735  0.0  0.0   9396   920 pts/16   S+   12:28   0:00 grep --color=auto dv

$VAR1 = {
          'ingest' => {
                        'status' => 'DV Switch host not found'
                      },
          'config' => {
                        'roles' => [
                                     {
                                       'role' => 'ingest'
                                     }
                                   ],
                        'nickname' => '',
                        'macaddress' => '60-67-20-66-81-24',
                        'mixer' => {
                                     'port' => '1234',
                                     'host' => 'localhost'
                                   },
                        'room' => '',
                        'devices' => [
                                       {
                                         'id' => 'video0',
                                         'device' => 'v4l'
                                       }
                                     ]
                      },
          'devices' => {
                         'v4l' => {
                                    'video0' => {
                                                  'name' => 'Ricoh Company Ltd. Integrated Camera',
                                                  'path' => '/dev/video0',
                                                  'type' => 'v4l'
                                                }
                                  }
                       }
        };

