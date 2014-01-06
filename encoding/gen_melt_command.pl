#!/usr/bin/perl

use v5.14;
use JSON; # libjson-perl
use Getopt::Long;
use HTTP::Tiny; # libhttp-tiny-perl
use Data::Dumper;
use DateTime::Format::Strptime;

# +- Range in seconds 
my $range = 1500;

#my $getopts_rc = GetOptions(
#    "start-cut"        => \$start_cut,
#    "end_cut"       => \$end_cut,
#
#    "help|?"        => \&print_usage,
#);
#
#sub print_usage {
#  say "
#Usage: station-mgr.pl [OPTIONS]
#
#Options:
#  --start-cut   Seconds to cut from the start
#  --end-cut     Seconds to cut from the endi
#  --room        room id from schedule 
#
#  --help        this help text
#";
#  exit 0;
#}

# HTTP
our $http = HTTP::Tiny->new(timeout => 15);
our $self;

my $response =  $http->post("https://lca2014.linux.org.au/programme/schedule/json");
if ($response->{status} == 200 ) {
  #print Dumper($response);
  $self->{schedule} = from_json($response->{content});
} else {
  say "Schedule data not available";
  say "$response->{status}";
  say "$response->{content}";
}

my $test = '2014-01-06_13-40-26';
#my $test =~ s/\.dv//;

my @venues;
my $count = 0;
foreach my $key (keys %{$self->{schedule}}) {
  say "$count) $key";
  push(@venues, $key);
  $count++;
}

my $selection = &Prompt("Select a venue: 0 - $count");
say "";

my @venue = @{$self->{schedule}{@venues[$selection]}};

my $dvparse = DateTime::Format::Strptime->new(
  pattern => '%F_%H-%M-%S',
  on_error => 'croak',
);

my $zooparse = DateTime::Format::Strptime->new(
  pattern => '%F %H:%M:%S',
  on_error => 'croak',
);

my $starttime = $dvparse->parse_datetime($test);

$count = 0;
foreach my $presentation (@venue) {
  my $time = $zooparse->parse_datetime($presentation->{start});
  my $diff = $starttime->epoch - $time->epoch;
  if ($diff <= 1500 &&  $diff >= -1500) {
    say "$count) $presentation->{title}";
  }
  $count++;
}

$count--;

my $talk = &Prompt("Select the matching talk: 0 - $count");
say "";

my $title = @venue[$talk]->{title};
my $presenters = @venue[$talk]->{presenters};

$title = &Prompt("Alter title:", "$title");
$presenters = &Prompt("Alter Prestenters", "$presenters");

my $text;

if ($presenters eq 'n') {
  $text = "+$title.txt";
} else {
  $text = " -filter watermark:\"+$title~$presenters.txt\"";
}

say $text;

sub Prompt { # inspired from here: http://alvinalexander.com/perl/edu/articles/pl010005
  my ($question,$default) = @_;
  if ($default) {
    print $question, "[", $default, "]: ";
  } else {
    print $question, ": ";
  }

  $| = 1;               # flush
  $_ = <STDIN>;         # get input

  chomp;
  if ("$default") {
    return $_ ? $_ : $default;    # return $_ if it has a value
  } else {
    return $_;
  }
}

