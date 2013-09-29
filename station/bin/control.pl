#!/usr/bin/perl
use strict;
use warnings;
use IPC::Shareable; # libipc-shareable-perl
use Data::Dumper;

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

# GetOpt long eventually
start();

sub start {
  print "Starting Station\n";
}

sub stop {

IPC::Shareable->clean_up_all;
}

sub status {

}
