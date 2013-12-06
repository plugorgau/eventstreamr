#!/usr/bin/perl
use Dancer; # libdancer-perl 
use v5.14;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use IPC::Shareable; # libipc-shareable-perl
use feature 'switch';
use Config::JSON; # libconfig-json-perl
set serializer => 'JSON';

# logging
set logger => 'file';
set log => 'info';

unless ( config->{environment} eq 'production' ) {
  set logger => 'console';
  set log => 'core';
}

# Create shared memory object
my $glue = 'station-data';
my %options = (
    create    => 'yes',
    exclusive => 0,
    mode      => 0644,
    destroy   => 'yes',
);

my $shared;
tie $shared, 'IPC::Shareable', $glue, { %options } or
    die "server: tie failed\n";

get '/settings/:mac' => sub {
  my $data->{mac} = params->{mac};
  # status 200 config exists
  # status 204 config not exists
  $data->{config} = $shared->{config};
  $data->{result} = '200';
  return $data;
};

get '/settings' => sub {

# status 200 config exists
# status 204 config not exists
  my $data->{config} = $shared->{config};
  $data->{result} = '200';
  return $data;
};

post '/settings/:mac' => sub {
  my $data->{mac} = params->{mac};
  $data->{body} = request->body;
  if ($data->{mac} == $shared->{config}{macaddress}) {
    debug($data);
    return qq({"result":"200"});
  } else {
    return qq({"result":"400"});
  }
};

get '/command/:command' => sub {
  my $command = params->{command};

  given ($command) {
    when ("stop")     { $shared->{config}{run} = 0; }
    when ("start")    { $shared->{config}{run} = 1; }
    when ("restart")  { $shared->{config}{run} = 2; }
    default { return qq({"result":"400", "status":"unkown command"}); }
  }

  return qq({"result":"200"});
};

post '/command/:command' => sub {
  my $command = params->{command};
  my $data = from_json(request->body);
  
  given ($command) {
    when ("stop")     { $shared->{config}{device_control}{$data->{id}}{run} = 0; }
    when ("start")    { $shared->{config}{device_control}{$data->{id}}{run} = 1; }
    when ("restart")  { $shared->{config}{device_control}{$data->{id}}{run} = 2; }
    default { return qq({"result":"400", "status":"unkown command"}); }
  }

  return qq({"result":"200"});
};

dance;

__END__
