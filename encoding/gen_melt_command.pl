#!/usr/bin/perl

use v5.14;
use JSON; # libjson-perl
use Getopt::Long;
use HTTP::Tiny; # libhttp-tiny-perl
use Data::Dumper;
use DateTime::Format::Strptime;
use Cache::FileCache;
use File::Basename 'basename';
use Image::Magick;
use File::Path qw(make_path);

# +- Range in seconds 
our $self;
$self->{range} = 1500;
$self->{default_expires} = 300;
$self->{cache_root} = '/tmp/schedule/';
$self->{output_root} = '/tmp';
$self->{output_tmp} = '/tmp';
$self->{remote_storage} = 'av@10.4.4.10:/storage';

if (! -d $self->{cache_root}) {
  make_path($self->{cache_root});
}

my @dvfiles;
my $start_cut;
my $end_cut;

#my $getopts_rc = GetOptions(
#    "start-cut"     => \$start_cut,
#    "files"         => \@dvfiles,
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

my $test = '/tmp/2014-01-06_13-40-26.dv';
$test = basename($test);
$test =~ s/\.dv$//;

$self->{firstdv} = $test;

retrieve_schedule();

# Get the list of venues
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
$self->{venue} = @venues[$selection];

my $dvparse = DateTime::Format::Strptime->new(
  pattern => '%F_%H-%M-%S',
  on_error => 'croak',
);

my $zooparse = DateTime::Format::Strptime->new(
  pattern => '%F %H:%M:%S',
  on_error => 'croak',
);

my $starttime = $dvparse->parse_datetime($self->{firstdv});

# Find Closest schedules
$count = 0;
foreach my $presentation (@venue) {
  my $time = $zooparse->parse_datetime($presentation->{start});
  my $diff = $starttime->epoch - $time->epoch;
  if ($diff <= $self->{range} &&  $diff >= -$self->{range}) {
    say "$count) $presentation->{title}";
  }
  $count++;
}

$count--;

# Ask for Title info
my $talk = &Prompt("Select the matching talk: 0 - $count");

my $title = @venue[$talk]->{title};
my $presenters = @venue[$talk]->{presenters};

$title = &Prompt("Alter title:", "$title");
$presenters = &Prompt("Alter Prestenters", "$presenters");

if ($presenters eq 'n') {
  $self->{title_text} = "+$title.txt";
} else {
  $self->{title_text} = "$title\n$presenters";
  $self->{title_file} = "\"$title - $presenters.dv\"";
  $self->{title_mp4} = "\"$title - $presenters.mp4\"";
}

# Create titles
room_translate();
#create_title();
$self->{output_file} = "$self->{output_tmp}/@venue[$talk]->{schedule_id}-title.png";

my @transferred;
print "mkdir -p $self->{output_root}/$self->{room}/\n";
print "mkdir -p $self->{output_tmp}/$self->{room}/\n";
foreach my $file (@dvfiles) {
  print "scp $self->{remote_storage}/$self->{room}/$file\n";
  push(@transferred, "$self->{output_tmp}/$file");
}

print "melt $self->{output_root}/lca2014-intro.dv -filter watermark:$self->{output_file} in=300 out=500 composite.progressive=1 producer.align=centre composite.valign=c composite.halign=c @transferred lca2014-exit.dv -consumer avformat:/tmp/$self->{title_file}\n";
print "ffmpeg -i $self->{title_file} -vf yadif=1 -threads 0 -acodec libfdk_aac -ab 96k -ac 1 -ar 48000 -vcodec libx264 -preset slower -crf 26 $self->{title_mp4}"

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

sub create_title {
  my $im;
  $im = new Image::Magick;
  
  my $text = 'Works like magick!\nthis is a new line fffff';
  $im->Set( size => '768x200' );
  $im->ReadImage('/tmp/blank_title.png');
  
  my $label=Image::Magick->new(size=>"700x200");
  $label->Set(gravity => "Center", font => '/usr/share/fonts/truetype/ubuntu-font-family/Ubuntu-B.ttf', background => 'none', fill => 'white');
  $label->Read("label:$self->{title_text}");
  $im->Composite(image => $label, gravity => 'Center');
  $im->Write("$self->{output_file}");
}

sub retrieve_schedule {
  my $cache = new Cache::FileCache( {namespace  => 'schedule_cache', default_expires_in => $self->{default_expires}, cache_root => $self->{cache_root} } );
  $self->{raw_json} = $cache->get( 'schedule' );
  $self->{cache} = 'Cached';
  if ( not defined $self->{raw_json} ) {
    my $response =  $http->get("https://lca2014.linux.org.au/programme/schedule/json");
    if ($response->{status} != 200 ) {
      say "Schedule data not available";
      say "$response->{status}";
      say "$response->{content}";
      exit 0;
    }
    $self->{raw_json} = $response->{content};
    $cache->set( 'schedule', $self->{raw_json} );
    $self->{cache} = 'Fresh';
  }
  $self->{schedule} = from_json($self->{raw_json});
  return;
}

# make this configurable
sub room_translate {
  given($self->{venue}) {
    when  (/GGGL:GENTILLI Gentilli Lecture Theatre/) { $self->{room} = 'gentilli';}
    when  (/Royal Perth Yacht Club - Australia II Drive, Crawley/) { $self->{room} = 'Royal Perth Yacht Club - Australia II Drive, Crawley';}
    when  (/ENG:LT2/) { $self->{room} = 'eng-lt1';}
    when  (/Hardware room - Physics Lab 1.28/) { $self->{room} = 'Hardware room - Physics Lab 1.28';}
    when  (/Foyer/) { $self->{room} = 'Foyer';}
    when  (/Octagon/) { $self->{room} = 'octagon';}
    when  (/Prescott Court, UWA/) { $self->{room} = 'Prescott Court, UWA';}
    when  (/GPB2:LT Robert Street Lecture Theatre/) { $self->{room} = 'roberts';}
    when  (/uncatered/) { $self->{room} = 'uncatered';}
    when  (/GGGL:WOOL Woolnough Lecture Theatre/) { $self->{room} = 'wool';}
    when  (/Matilda Bay foreshore/) { $self->{room} = 'Matilda Bay foreshore';}
    when  (/GGGL:WEBB Webb Lecture Theatre/) { $self->{room} = 'webb';}
    when  (/All Lecture Theatres/) { $self->{room} = 'All Lecture Theatres';}
    when  (/ENG:LT1/) { $self->{room} = 'eng-lt1';}
  }
}
