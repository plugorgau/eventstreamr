#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use Proc::Daemon; # libproc-daemon-perl
use IPC::Shareable; # libipc-shareable-perl
use Data::Dumper;
use JSON; # libjson-perl
use Config::JSON; # libconfig-json-perl
use HTTP::Tiny;

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
my $daemon = Proc::Daemon->new;
my $pid = $daemon->Init();
  
my $continue = 1;
$SIG{TERM} = sub { $continue = 0 };

while ($continue) {
  print Dumper($config);
  sleep 10;
}

sub updateconfig {

}

sub getconfig {

}

sub getmac {
  # this is horrible, find a better way!
  my $macaddress = `/sbin/ifconfig|grep "wlan"|grep ..:..:..:..:..:..|awk '{print \$NF}'`;
  $macaddress =~ s/:/-/g;
  chomp $macaddress;
  return $macaddress;
}
__END__
