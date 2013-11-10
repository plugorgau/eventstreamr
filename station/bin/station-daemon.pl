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

# Dev
use Data::Dumper;

# Load Local Config
my $localconfig = Config::JSON->new("$Bin/../settings.json");
$localconfig = $localconfig->{config};

# Station Config
my $stationconfig = Config::JSON->new("$Bin/../station.json");

# Create shared memory object
my $glue = 'station-data';
my %options = (
    create    => 'yes',
    exclusive => 0,
    mode      => 0644,
    destroy   => 'yes',
);

my $config;
tie $config, 'IPC::Shareable', $glue, { %options } or
    die "server: tie failed\n";

$config = $stationconfig->{config};
$config->{macaddress} = getmac();
$devices->all();


my $response = HTTP::Tiny->new->get("http://$localconfig->{controller}:5001/station/$config->{macaddress}");
#my $response = HTTP::Tiny->new->get("http://localhost:3000/settings/$config->{macaddress}");
print Dumper($response);

if ($response->{success} && $response->{status} == 200 ) {
  my $content = from_json($response->{content});
  print Dumper($content);
  if ($content->{result} == 200 && defined $content->{config}) {
    $config->{station} = $content->{config};
    $stationconfig->{config} = $config;
    $stationconfig->write;
  }
}


# Start Daemon
our $daemons->{main}{proc} = Proc::Daemon->new;
$daemons->{main}{pid} = $daemons->{main}{proc}->Init();
  
$daemons->{main}{run} = 1;
$SIG{TERM} = sub { $daemons->{main}{run} = 0; IPC::Shareable->clean_up_all; };

while ($daemons->{main}{run}) {
  foreach my $role (@{$config->{roles}}) {
    given ( $role->{role} ) {
      when ("ingest")   { ingest(); }
      when ("mixer")    { mixer();  }
      when ("stream")   { stream(); }
    }
  }

  print Dumper($config);
  sleep 10;
}

## Routines
sub updateconfig {

}

sub getconfig {

}

# Get Mac Address
sub getmac {
  # this is horrible, find a better way!
  my $macaddress = `/sbin/ifconfig|grep "wlan"|grep ..:..:..:..:..:..|awk '{print \$NF}'`;
  $macaddress =~ s/:/-/g;
  chomp $macaddress;
  return $macaddress;
}

## Ingest
sub ingest {
  if ( $utils->port($config->{mixer}{host},$config->{mixer}{port}) ) {
    $config->{status}{ingest} = "DV Switch host found";
  } else {
    $config->{status}{ingest} = "DV Switch host not found";
    return
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


__END__
