#!/usr/bin/perl
use strict;
use warnings;
use FindBin qw($Bin);
use lib "$Bin/../lib";

# EventStremr Modules
use EventStreamr::Devices;
my $devices = EventStreamr::Devices->new();

# Dev
use Data::Dumper;

$devices->list();
print Dumper($devices);
