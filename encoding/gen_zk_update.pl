#!/usr/bin/perl

#
# Leon Wright - 2014-02-16
# Quick script to generate a zookeeper database update of lca videos
# Should write something that's safe from Bobby Tables issues.
# Though the filenames should be relatively safe.
#

use strict;
use File::Find;
use File::Basename qw(basename);

if (! $ARGV[0] || ! -d $ARGV[0]) {
  my $script = basename($0);
  print "Usage: $script /path/to/videos\n";
  exit 0;
}

my $directory = $ARGV[0];

my @file_list;
find ( sub {
  return unless -f;           # Must be a file
  return unless /^\d+-/;      # Must have a schedule id
  return unless /\.mp4$/;     # Must end with `.mp4` suffix
  push @file_list, $File::Find::name;
}, $directory );

foreach my $video (@file_list) {
  $video =~ m{^.+/(?<year>\d\d\d\d)/(?<dow>\w+)/(?<id>\d+)-.*}x;
  my $basename = basename($video);
  print "UPDATE schedule\nSET video_link = 'http://mirror.linux.org.au/linux.conf.au/$+{year}/$+{dow}/$basename'\nWHERE id = $+{id};\n";
}

