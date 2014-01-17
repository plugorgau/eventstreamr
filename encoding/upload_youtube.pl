#!/usr/bin/perl

#
# Simple Upload Script
# Hacked together post LCA 2014
# 2013-01-15 - Leon Wright - techman83@gmail.com
#
# A developer account is needed with the relevent scopes associated - https://cloud.google.com/console/
#

use strict;
use Config::YAML;
use Data::Dumper;
use HTTP::Tiny;
use File::Basename;
use JSON;
use File::MimeInfo::Magic;
use LWP::UserAgent;
use LWP::Authen::OAuth2;
use HTTP::Request::StreamingUpload;
use Cache::FileCache;
use File::Path 'make_path';
use Encode 'encode_utf8';

# Cache defaults
my $self;
$self->{default_expires} = 300;
$self->{cache_root} = '/tmp/schedule/';

# CSV results
$self->{upload_csv} = "$ENV{HOME}/youtube_upload.csv";
$self->{failed_csv} = "$ENV{HOME}/youtube_failed.csv";

## Match video to ZooKeeper Data
$self->{file} = $ARGV[0];

if (!$self->{file}) {
  print "usage: ./upload_youtube.pl /path/to/file.mp4\n";
  exit 0;
}

$self->{filename} = basename($self->{file});
$self->{mimetype} = mimetype($self->{file});
$self->{filename} =~ m{^(?<id>\d+)-.*}x; # Extract schedule id
$self->{schedule_id} = $+{id};

retrieve_schedule();

# this is kinda horrible...
foreach my $key (keys %{$self->{schedule}}) {
  foreach my $schedule ( @{$self->{schedule}{$key}}) {
    if ($schedule->{schedule_id} ==  $self->{schedule_id}) {
      $self->{matched_schedule} = $schedule;
    }
  }
}

if (!$self->{matched_schedule}) {
  print "$self->{file} - Not found in schedule - may require manual upload\n";
  exit 0;
}

## Build video meta data - truncate to 100 characters as that is the title limit
if (length($self->{matched_schedule}{title}) > 100) {
  $self->{metadata}{snippet}{title} = substr($self->{matched_schedule}{title}, 0, 100);
  $self->{metadata}{snippet}{description} .= "Full Title: $self->{matched_schedule}{title}\n";
} else {
  $self->{metadata}{snippet}{title} = $self->{matched_schedule}{title};
}


# Some presenters is empty
if ($self->{matched_schedule}{presenters}) {
  $self->{metadata}{snippet}{description} .= "Presenter(s): $self->{matched_schedule}{presenters}\n";
}

# Talk urls
if ($self->{matched_schedule}{url}) {
  $self->{metadata}{snippet}{description} .= "URL: $self->{matched_schedule}{url}\n\n";
}

# I believe I've seen empty abstracts
if ($self->{matched_schedule}{abstract}) {
  $self->{metadata}{snippet}{description} .= "$self->{matched_schedule}{abstract}\n\n";
}

# Creative Commons License
$self->{metadata}{snippet}{description} .= "http://lca2014.linux.org.au - http://www.linux.org.au\nCC BY-SA - http://creativecommons.org/licenses/by-sa/4.0/legalcode.txt";
$self->{metadata}{snippet}{tags} = ["LCA2014","Linux","Open Source" ];
$self->{metadata}{status}{license} = "creativeCommon";

# Visibility
$self->{metadata}{status}{privacyStatus} = "private";

### Get oauth2 authorisation
my $googleapi = Config::YAML->new( config => "$ENV{HOME}/.googleapi.yml" );
my $oauth2;

if (! $googleapi->{token_string}) {
  $oauth2 = LWP::Authen::OAuth2->new(
                client_id => $googleapi->{client_id},
                client_secret => $googleapi->{client_secret},
                service_provider => "Google",
                redirect_uri => "urn:ietf:wg:oauth:2.0:oob",
                scope => 'https://www.googleapis.com/auth/youtube.upload',
            );
  my $url = $oauth2->authorization_url();
  print "Log into the youtube account and, set your channel and browse the following url\n";
  print "$url\n";
  my $code = &Prompt("Paste code result here");
  $oauth2->request_tokens(code => $code);
  $googleapi->{token_string} = $oauth2->token_string;
  $googleapi->write;
} else {
  $oauth2 = LWP::Authen::OAuth2->new(
                client_id => $googleapi->{client_id},
                client_secret => $googleapi->{client_secret},
                service_provider => "Google",
                redirect_uri => "urn:ietf:wg:oauth:2.0:oob",
  
                # This is for when you have tokens from last time.
                token_string => $googleapi->{token_string},
            );
}

## Create Youtube v3 api Upload request
# Inspiration here: http://lithostech.com/2013/10/upload-google-youtube-api-v3-cors/
my $json = to_json($self->{metadata});

###### Blargle: Here be dragons! 
## Either I misunderstand something or there is a bug in the oauth2 module (likely the former..)
## https://rt.cpan.org/Public/Bug/Display.html?id=92194
 
my $ua = LWP::UserAgent->new;
$ua->show_progress('1');
$oauth2->set_user_agent($ua);

# Even if you state utf-8, LWP downgrades it to latin1 unless you specifically encode it as such
# http://blogs.perl.org/users/domm/2010/11/posting-utf8-data-using-lwpuseragent.html
my $response = $oauth2->post(
       'https://www.googleapis.com/upload/youtube/v3/videos?uploadType=resumable&part=snippet,status',
       Content_Type => 'application/json;charset=utf-8',
       client_id => $googleapi->{client_id},
       client_secret => $googleapi->{client_secret},
       Authorization => "Bearer $googleapi->{auth_token}",
       Host => 'www.googleapis.com',
       setAccessType => 'offline',
       setApprovalPrompt => 'force',
       'X-Upload-Content-Length' => -s $self->{file},
       'X-Upload-Content-Type' => $self->{mimetype},
       Content      => encode_utf8($json), 
       );

$self->{upload_location} = $response->header("Location");

if (! $self->{upload_location}) {
  print "Failed: $self->{filename} -> $response->{_msg}\n";
  exit 0;
}

# HTTP::Request::Common dynamic file uploads only work for post, resumeable uploads require put :-(
my $req = HTTP::Request::StreamingUpload->new(
      PUT     => $self->{upload_location},
      path    => $self->{file},
      headers => HTTP::Headers->new(
        'Content-Type'   => $self->{mimetype},
        'Content-Length' => -s $self->{file},
        client_id => $googleapi->{client_id},
        client_secret => $googleapi->{client_secret},
        Authorization => "Bearer $googleapi->{auth_token}",
        Host => 'www.googleapis.com',
        setAccessType => 'offline',
        setApprovalPrompt => 'force',
      ),
  );

$response = $oauth2->request($req);

$self->{youtube} = from_json($response->decoded_content);

if ($self->{youtube}{status}{uploadStatus} eq 'uploaded') {
  open my $fh, ">>", "$self->{upload_csv}";
  print $fh "$self->{matched_schedule}{schedule_id},$self->{youtube}{id}\n";
  close $fh;
  print "Success: $self->{filename} -> http://youtu.be/$self->{youtube}{id}\n";
} else {
  open my $fh, ">>", "$self->{failed_csv}";
  print $fh "$self->{matched_schedule}{schedule_id},$self->{youtube}{id}\n";
  close $fh;
  print "Failed: $self->{filename} -> $self->{youtube}{error}{errors}[0]{reason}\n";
}

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

sub retrieve_schedule {
  if (! -d $self->{cache_root}) {
    make_path($self->{cache_root});
  }

  my $cache = new Cache::FileCache( {namespace  => 'schedule_cache', default_expires_in => $self->{default_expires}, cache_root => $self->{cache_root} } );
  $self->{raw_json} = $cache->get( 'schedule' );
  $self->{cache} = 'Cached';
  my $http = HTTP::Tiny->new(timeout => 15);
  if ( not defined $self->{raw_json} ) {
    my $response =  $http->get("https://lca2014.linux.org.au/programme/schedule/json");
    if ($response->{status} != 200 ) {
      print "Schedule data not available\n";
      print "$response->{status}\n";
      print "$response->{content}\n";
      exit 0;
    }
    $self->{raw_json} = $response->{content};
    $cache->set( 'schedule', $self->{raw_json} );
    $self->{cache} = 'Fresh';
  }
  $self->{schedule} = from_json($self->{raw_json});
  return;
}


__END__
$VAR1 = {
          'event_id' => 219,
          'presenters' => 'Andrew Tridgell',
          'duration' => '0:45:00',
          'end' => '2014-01-10 12:20:00',
          'url' => 'https://lca2014.linux.org.au/schedule/30272/view_talk',
          'title' => 'APM on Linux: Porting ArduPilot to Linux',
          'abstract' => 'ArduPilot was originally an \'arduino\' sketch for 8 bit AVR micros.
This talk discusses the in-progress Linux port, dealing with the
multitude of sensors, latency and timing issues.',
          'start' => '2014-01-10 11:35:00',
          'schedule_id' => 110
        };


# YouTube response
$VAR1 = '{
 "kind": "youtube#video",
 "etag": "\\"qQvmwbutd8GSt4eS4lhnzoWBZs0/jTaNVv4eWE1oNQWvjvHEGVy4E08\\"",
 "id": "YScSSdcIRzg",
 "snippet": {
  "publishedAt": "2014-01-15T04:19:29.000Z",
  "channelId": "UCzZQQRwZRQhS4q93LSWn_og",
  "title": "Test video",
  "description": "",
  "thumbnails": {
   "default": {
    "url": "https://i1.ytimg.com/s_vi/YScSSdcIRzg/default.jpg?sqp=CMSW2JYF&rs=AOn4CLDVVldcva1eNcFUSwQt1SU_-i5axw"
   },
   "medium": {
    "url": "https://i1.ytimg.com/s_vi/YScSSdcIRzg/mqdefault.jpg?sqp=CMSW2JYF&rs=AOn4CLB92YNxv_tf7o9k3TmCXe7JnRuDgQ"
   },
   "high": {
    "url": "https://i1.ytimg.com/s_vi/YScSSdcIRzg/hqdefault.jpg?sqp=CMSW2JYF&rs=AOn4CLD09kGvvLWeGJ59NLI4dn8irQXPNA"
   }
  },
  "channelTitle": "Leon Wright",
  "categoryId": "22",
  "liveBroadcastContent": "none"
 },
 "status": {
  "uploadStatus": "uploaded",
  "privacyStatus": "private",
  "license": "youtube",
  "embeddable": true,
  "publicStatsViewable": true
 }
}
';


