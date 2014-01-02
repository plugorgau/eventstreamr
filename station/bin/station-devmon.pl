#!/usr/bin/perl
use strict;

use v5.14;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use File::Tail; # libfile-tail-perl
use HTTP::Tiny; # libhttp-tiny-perl
use JSON; # libjson-perl

# Eventstreamr libs
use EventStreamr::Devices;
our $devices = EventStreamr::Devices->new();

my $log = File::Tail->new(name => "/var/log/syslog", maxinterval=>1, );

while(defined(my $line=$log->read)) {
  # Perform action on device created logs
  if ($line =~ m/firewire_core.+: created device/i) {
    # Extract the GUID
    $line =~ /.+].firewire_core.+:.created.device.fw\d+:.GUID.(?<guid>.+),.*/ix;
    my $guid = $+{guid};

    # Load DV devices
    my $dv = $devices->dv();
    
    # Avoid trying to restart the fw card as a dv device
    if (defined $dv->{"0x$guid"}) {
      # Trigger restart
      my $device->{id} = "0x$guid";
      my $json = to_json($device);
      my %post_data = (
            content => $json,
            'content-type' => 'application/json',
            'content-length' => length($json),
      );

      my $http = HTTP::Tiny->new(timeout => 15);
      my $post = $http->post("http://localhost:3000/command/restart", \%post_data);
    }
  }
}

