#!/usr/bin/perl

use strict;
use v5.14;
use FindBin qw($Bin);
use lib "$Bin/lib";
use EventStreamr::Schedule;
use File::Basename;
use Image::Magick;
use Data::Dumper;

my $self->{file} = $ARGV[0];
$self->{output_file} = $ARGV[1];
$self->{title_path} = "/storage/titles";

if (!$self->{file} || !$self->{output_file}) {
  print "usage: ./fix_2014.pl /path/to/XXX.sh /path/to/output.sh\n";
  exit 0;
}

## Match video to ZooKeeper Data
my $schedule = EventStreamr::Schedule->new(schedule_url => "https://lca2014.linux.org.au/programme/schedule/json");
$self->{schedule} = $schedule->retrieve();
$self->{filename} = basename($self->{file});
$self->{filename} =~ m{^(?<id>\d+).*}x; # Extract schedule id
$self->{schedule_id} = $+{id};

# this is kinda horrible...
foreach my $key (keys %{$self->{schedule}}) {
  foreach my $schedule ( @{$self->{schedule}{$key}}) {
    if ($schedule->{schedule_id} ==  $self->{schedule_id}) {
      $self->{matched_schedule} = $schedule;
    }
  }
}

if (!$self->{matched_schedule}) {
  print "$self->{file} - Not found in schedule - may require manual attention\n";
  exit 0;
}

# Some presenters is empty
if ($self->{matched_schedule}{presenters}) {
  $self->{title_text} = "$self->{matched_schedule}{title}\n$self->{matched_schedule}{presenters}";
} else {
  $self->{title_text} = "$self->{matched_schedule}{title}";
}

print "Creating Title for Schedule: $self->{schedule_id}\n";
$self->{title_overlay} = "$self->{title_path}/$self->{schedule_id}-title.png";
create_title();

print "Generating $self->{output_file} from $self->{file}\n";

open my $INFILE, '<', "$self->{file}" or die $!;
open my $OUTFILE, ">", "$self->{output_file}" or die $!;
  
# Process encode file
my $name;
my $output_path;
while (my $line = <$INFILE>){
  
  $line =~ s/10.4.4.20/storage.local/g;
  
  if ($line =~ m/^ffmpeg.*/) {
    # Extract file information
    $line =~ m{
      ^ffmpeg.-i."
      (?<filename> .+)".+"
      (?<output>  .+)"
      $
    }ix;

    my $filename = $+{filename};
    my $output = $+{output};

    # Get dv filename
    my $basename = basename($filename);

    # Extract filename without extension
    $name = $basename;
    $name =~ s{\.[^.]+$}{};

    # Set pathes
    my $input_path  = dirname($filename);
    $output_path  = dirname($output);

    # Remove Previously Encoded
    print $OUTFILE "rm -f $output_path/$self->{schedule_id}-$name.ogv\n";
    print $OUTFILE "rm -f $output_path/$self->{schedule_id}-$name.webm\n";

    # Encode commands
    print $OUTFILE "ffmpeg2theora --videoquality 3 --audioquality 3 --audiobitrate 48 --speedlevel 2 --keyint 256 \"$input_path/$basename\" -o \"$output_path/$self->{schedule_id}-$name.ogv\"\n";

    print $OUTFILE "ffmpeg -y -i \"$input_path/$basename\" -threads 0 -f webm -vcodec libvpx -deinterlace -g 120 -level 216 -profile 0 -qmax 51 -qmin 11 -rc_lookahead 25 -rc_buf_aggressivity 0.95 -vb 400k -acodec libvorbis -aq 85 -ar 22050 -ac 1 \"$output_path/$self->{schedule_id}-$name.webm\"\n";
    print $OUTFILE "\n";

  } elsif ($line =~ m/^scp.+.mp4.av@/i) {
    $line =~ m{
      ^scp.+.mp4.av\@storage.local:
      (?<output> .+)
      $
    }ix;
    
    my $scp_path = $+{output};

    # Copy encoded files
    print $OUTFILE "scp $output_path/$self->{schedule_id}-$name.ogv av\@storage.local:$scp_path \n";
    print $OUTFILE "scp $output_path/$self->{schedule_id}-$name.webm av\@storage.local:$scp_path \n";
    print $OUTFILE "\n";
  } elsif ($line =~ m/^scp.+.png/i) {
    $line =~ m{
      ^scp.+.png.
      (?<output> .+)
      $
    }ix;
    
    my $scp_path = $+{output};
    print $OUTFILE "scp av\@storage.local:$self->{title_overlay} $scp_path\n";

  } else {
    print $OUTFILE "$line";
  }
}

close $INFILE;
close $OUTFILE;

sub create_title {
  my $im;
  $im = new Image::Magick;
  
  $im->Set( size => '768x200' );
  $im->ReadImage("$Bin/blank_title.png");
  
  my $label=Image::Magick->new(size=>"700x200");
  $label->Set(gravity => "Center", font => '/usr/share/fonts/truetype/ubuntu-font-family/Ubuntu-B.ttf', background => 'none', fill => 'white');
  $label->Read("label:$self->{title_text}");
  $im->Composite(image => $label, gravity => 'Center');
  $im->Write("$self->{title_overlay}");
}

