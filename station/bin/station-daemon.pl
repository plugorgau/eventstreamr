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

# Shared Interprocess storage
$shared->{config} = $stationconfig->{config};
$shared->{config}{macaddress} = getmac();

# Personal Storage - need to limit shared data
our $self;
$self->{devices} = $devices->all();
$self->{commands} = $commands->{config};
$self->{dvswitch}{check} = 1; # check until dvswitch is found
$self->{dvswitch}{running} = 0;

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
  $shared->{config}{devices} = $self->{devices}{array};
}

while ($daemons->{main}{run}) {
  # If we're restarting, we should trigger check for dvswitch
  if ($shared->{config}{run} == 2) {
    print "Restart Triggered\n";
    $self->{dvswitch}{check} = 1;
  }

  # Process the roles
  foreach my $role (@{$shared->{config}->{roles}}) {
    given ( $role->{role} ) {
      when ("mixer")    { mixer();  }
      when ("ingest")   { ingest(); }
      when ("stream")   { stream(); }
      when ("record")   { record(); }
    }
  }

  # 2 is the restart all processes trigger
  # $daemon->Kill_Daemon does a Kill -9, so if we get here they procs should be dead. 
  if ($shared->{config}{run} == 2) {
    $shared->{config}{run} = 1;
  }

  # Until found check for dvswitch - continuously hitting dvswitch with an unknown client caused high cpu load
  unless ( $self->{dvswitch}{running} && ! $self->{dvswitch}{check} ) {
    if ( $utils->port($shared->{config}->{mixer}{host},$shared->{config}->{mixer}{port}) ) {
      print "DVswitch found Running\n";
      $self->{dvswitch}{running} = 1;
      $self->{dvswitch}{check} = 0; # We can set this to 1 and it will check dvswitch again.
    }
  }
   
  sleep 1;
}

## Ingest
sub ingest {
  if ($self->{dvswitch}{running} == 1) {
    foreach my $device (@{$shared->{config}{devices}}) {
      $device->{role} = "ingest";
      run_stop($device);
    }
  }
  return;
}

## Mixer
sub mixer {
  my $device;
  $device->{role} = "mixer";
  $device->{id} = "dvswitch";
  $device->{type} = "mixer";
  run_stop($device);
  return;
}

## Stream
sub stream {
#  my $device;
#  $device->{role} = "stream";
#  $device->{id} = $shared->{config}{stream}{stream};
#  $device->{type} = "stream";
#  run_stop($device);
  return;
}

## Stream
sub record {
#  my $device;
#  $device->{role} = "record";
#  $device->{id} = "record";
#  $device->{type} = "record";
#  run_stop($device);
  return;
}

# run, stop or restart a process 
sub run_stop {
  my ($device) = @_;
  # Build command for execution and save it for future use
  unless ($self->{device_commands}{$device->{id}}{command}) {
    given ($device->{role}) {
      when ("ingest")   { $self->{device_commands}{$device->{id}}{command} = ingest_commands($device->{id},$device->{type}); }
      when ("mixer")   { $self->{device_commands}{$device->{id}}{command} = mixer_command(); }
    }
  }

  # If we're supposed to be running, run.
  if ($shared->{config}{run} == 1 && 
    (! defined $shared->{config}{device_control}{$device->{id}}{run} || $shared->{config}{device_control}{$device->{id}}{run} == 1)) {
    # Get the running state + pid if it exists
    my $state = $utils->get_pid_command($device->{id},$self->{device_commands}{$device->{id}}{command},$device->{type}); 

    unless ($state->{running}) {
      print "Connect $device->{id} to DVswitch\n";
      # Spawn the Ingest Command
      my $proc = $daemon->Init( {  
           exec_command => $self->{device_commands}{$device->{id}}{command},
      } );
      
      # give the process some time to settle
      sleep 1;
      # Set the running state + pid
      $state = $utils->get_pid_command($device->{id},$self->{device_commands}{$device->{id}}{command},$device->{type}); 
    }
    
    # Need to find the child of the shell, as killing the shell does not stop the command
    $self->{device_control}{$device->{id}} = $state;
    
  } elsif (defined $self->{device_control}{$device->{id}}{pid}) {
    # Kill The Child
    if ($daemon->Kill_Daemon($self->{device_control}{$device->{id}}{pid})) { 
      print "Stop $device->{id}\n";
      $self->{device_control}{$device->{id}}{running} = 0;  
      $self->{device_control}{$device->{id}}{pid} = undef; 
    }

    # Set device back to running if a restart was triggered
    if (! defined $shared->{config}{device_control}{$device->{id}}{run} || $shared->{config}{device_control}{$device->{id}}{run} == 2) {
      $shared->{config}{device_control}{$device->{id}}{run} = 1;
    }
  }
  return;
}

## Commands
sub ingest_commands {
  my ($id,$type) = @_;
  my $command = $self->{commands}{$type};
  my %cmd_vars =  ( 
                    device  => $self->{devices}{$type}{$id}{device},
                    host    => $shared->{config}->{mixer}{host},
                    port    => $shared->{config}->{mixer}{port},
                  );

  $command =~ s/\$(\w+)/$cmd_vars{$1}/g;

  return $command;
} 

sub mixer_command {
  my $command = $self->{commands}{dvswitch};
  my %cmd_vars =  ( 
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
          'commands' => {
                          'alsa' => 'dvsource-alsa -h $host -p $port hw:$device',
                          'dv' => 'dvsource-firewire -h $host -p $port -c $device',
                          'record' => 'dvsink-files $device',
                          'v4l' => 'ffmpeg -f video4linux2 -s vga -r 25 -i $device -target pal-dv - | dvsource-file /dev/stdin -h $host -p $port',
                          'stream' => 'dvsink-command -- ffmpeg2theora - -f dv -F 25:2 --speedlevel 0 -v 4  --optimize -V 420 --soft-target -a 4 -c 1 -H 44100 -o - | oggfwd $host $port 8000 $password /$stream',
                          'file' => 'dvsource-file -l $device',
                          'dvswitch' => 'dvswitch -h 0.0.0.0 -p $port'
                        },
          'config' => {
                        'roles' => [
                                     {
                                       'role' => 'ingest'
                                     },
                                     {
                                       'role' => 'mixer'
                                     },
                                     {
                                       'role' => 'stream'
                                     }
                                   ],
                        'nickname' => 'test',
                        'room' => 'room1',
                        'devices' => [
                                       {
                                         'name' => 'Chicony Electronics Co.  Ltd. ASUS USB2.0 Webcam',
                                         'id' => 'video0',
                                         'type' => 'v4l',
                                         'device' => '/dev/video0'
                                       },
                                       {
                                         'name' => 'C-Media Electronics, Inc. ',
                                         'usbid' => '0d8c:0008',
                                         'id' => '2',
                                         'type' => 'alsa',
                                         'device' => '2'
                                       }
                                     ],
                        'device_control' => {
                                              'video0' => {
                                                            'run' => '0'
                                                          }
                                            },
                        'run' => '0',
                        'macaddress' => '00:15:58:d8:85:c7',
                        'mixer' => {
                                     'port' => '1234',
                                     'host' => 'localhost'
                                   }
                      },
          'dvswitch' => {
                          'check' => 1
                        },
          'devices' => {
                         'array' => [
                                      {
                                        'name' => 'Chicony Electronics Co.  Ltd. ASUS USB2.0 Webcam',
                                        'id' => 'video0',
                                        'type' => 'v4l',
                                        'device' => '/dev/video0'
                                      },
                                      {
                                        'name' => 'C-Media Electronics, Inc. ',
                                        'usbid' => '0d8c:0008',
                                        'id' => '2',
                                        'type' => 'alsa',
                                        'device' => '2'
                                      }
                                    ],
                         'dv' => {
                                   'all' => []
                                 },
                         'alsa' => {
                                     '2' => {
                                              'name' => 'C-Media Electronics, Inc. ',
                                              'usbid' => '0d8c:0008',
                                              'id' => '2',
                                              'type' => 'alsa',
                                              'device' => '2'
                                            },
                                     'all' => [
                                                {
                                                  'name' => 'C-Media Electronics, Inc. ',
                                                  'usbid' => '0d8c:0008',
                                                  'id' => '2',
                                                  'type' => 'alsa',
                                                  'device' => '2'
                                                }
                                              ]
                                   },
                         'v4l' => {
                                    'video0' => {
                                                  'name' => 'Chicony Electronics Co.  Ltd. ASUS USB2.0 Webcam',
                                                  'id' => 'video0',
                                                  'type' => 'v4l',
                                                  'device' => '/dev/video0'
                                                },
                                    'all' => [
                                               {
                                                 'name' => 'Chicony Electronics Co.  Ltd. ASUS USB2.0 Webcam',
                                                 'id' => 'video0',
                                                 'type' => 'v4l',
                                                 'device' => '/dev/video0'
                                               }
                                             ]
                                  },
                         'all' => {
                                    'video0' => {
                                                  'name' => 'Chicony Electronics Co.  Ltd. ASUS USB2.0 Webcam',
                                                  'id' => 'video0',
                                                  'type' => 'v4l',
                                                  'device' => '/dev/video0'
                                                },
                                    'all' => [
                                               {
                                                 'name' => 'C-Media Electronics, Inc. ',
                                                 'usbid' => '0d8c:0008',
                                                 'id' => '2',
                                                 'type' => 'alsa',
                                                 'device' => '2'
                                               }
                                             ],
                                    '2' => {
                                             'name' => 'C-Media Electronics, Inc. ',
                                             'usbid' => '0d8c:0008',
                                             'id' => '2',
                                             'type' => 'alsa',
                                             'device' => '2'
                                           }
                                  }
                       }
        };
