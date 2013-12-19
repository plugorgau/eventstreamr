#!/usr/bin/perl
use Dancer; # libdancer-perl 
use v5.14;
use FindBin qw($Bin);
use lib "$Bin/../lib";
use feature 'switch';
use File::ReadBackwards;

set serializer => 'JSON';

# logging
set logger => 'file';
set log => 'info';

unless ( config->{environment} eq 'production' ) {
  set logger => 'console';
  set log => 'core';
}

# EventStreamr Modules
use EventStreamr::Devices;
our $devices = EventStreamr::Devices->new();

# API Data
our $self;

# routes
get '/settings/:mac' => sub {
  my $data->{mac} = params->{mac};
  # status 200 config exists
  # status 204 config not exists
  $data->{config} = $self->{config};
  $data->{result} = '200';
  return $data;
};

get '/settings' => sub {
  my $data->{config} = $self->{config};
  $data->{result} = '200';
  return $data;
};

get '/dump' => sub {
  my $data->{dump} = $self;
  $data->{result} = '200';
  return $data;
};

get '/devices' => sub {
  my $result;
  $result->{devices} = $devices->all();
  $result->{result} = 200;
  return $result;
};

post '/settings/:mac' => sub {
  my $data->{mac} = params->{mac};
  $data->{body} = request->body;
  if ($data->{mac} == $self->{config}{macaddress}) {
    debug($data);
    kill '10', $self->{config}{manager}{pid}; 
    return qq({"result":"200"});
  } else {
    return qq({"result":"400"});
  }
};

get '/command/:command' => sub {
  my $command = params->{command};

  given ($command) {
    when ("stop")     { $self->{config}{run} = 0; }
    when ("start")    { $self->{config}{run} = 1; }
    when ("restart")  { $self->{config}{run} = 2; }
    default { return qq({"result":"400", "status":"unkown command"}); }
  }

  kill '10', $self->{config}{manager}{pid}; 
  return qq({"result":"200"});
};

post '/command/:command' => sub {
  my $command = params->{command};
  my $data = from_json(request->body);
  
  given ($command) {
    when ("stop")     { $self->{config}{device_control}{$data->{id}}{run} = 0; }
    when ("start")    { $self->{config}{device_control}{$data->{id}}{run} = 1; }
    when ("restart")  { $self->{config}{device_control}{$data->{id}}{run} = 2; }
    default { return qq({"result":"400", "status":"unkown command"}); }
  }
  kill '10', $self->{config}{manager}{pid}; 
  return qq({"result":"200"});
};

get '/log/manager' => sub {
  my @log;
  my $count = 0;
  my $result;
  my $bw = File::ReadBackwards->new( $self->{settings}{'logpath'} );

  while( defined( my $log_line = $bw->readline ) && $count < 101) {
    $count++;
    chomp $log_line;
    push(@log, $log_line);
  }

  if ($log[0]) {
    $result->{result} = 200;
    @{$result->{log}} = @log;
  } else {
    $result->{result} = 400
  }

  return $result;
};

# Status Information
get '/status' => sub {
  my $result;
  if ($self->{status}) {
    status '200';
    return $self->{status};
  } else {
    status '204';
    return;
  }
};

post '/status/:mac' => sub {
  my $mac = params->{mac};
  my $data = from_json(request->body);
  $self->{status}{$mac} = $data;
  return;
};

# Internal Communication with Manager
post '/internal/settings' => sub {
  my $data = from_json(request->body);
  $self = $data;
  info("Config data posted");
  debug($self);
  return qq({"result":"200"});
};

get '/internal/settings' => sub {
  my $result->{config} = $self->{config};
  info("Config data requested");
  debug($result);
  return $result;
};

dance;

__END__
