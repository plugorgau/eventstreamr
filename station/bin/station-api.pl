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
our $status;

# routes
get '/dump' => sub {
  my $data = $self;
  return $data;
};

# ----- Settings/Details -------------------------------------------------------
# MAC confirm, returns settings if correct
get '/settings/:mac' => sub {
  my $data->{mac} = params->{mac};
  if ($data->{mac} == $self->{config}{macaddress}) {
    $data->{config} = $self->{config};
  } else {
    status '400';
    return qq({"status":"invalid_mac"});
  }
  header 'Access-Control-Allow-Origin' => '*';
  return $data;
};

# Returns settings
get '/settings' => sub {
  my $data->{config} = $self->{config};
  header 'Access-Control-Allow-Origin' => '*';
  return $data;
};

# Updates config if mac matches
post '/settings/:mac' => sub {
  my $data->{mac} = params->{mac};
  $data->{body} = request->body;
  if ($data->{mac} == $self->{config}{macaddress}) {
    debug($data);
    kill '10', $self->{config}{manager}{pid}; 
    return;
  } else {
    status '400';
    return qq({"status":"invalid_mac"});
  }
};

# Returns attached devices
get '/devices' => sub {
  my $result;
  $result->{devices} = $devices->all();
  header 'Access-Control-Allow-Origin' => '*';
  return $result;
};

# ----- Station Control Commands -----------------------------------------------
# Stop/Start/Restart All
get '/command/:command' => sub {
  my $command = params->{command};

  given ($command) {
    when ("stop")     { $self->{config}{run} = 0; }
    when ("start")    { $self->{config}{run} = 1; }
    when ("restart")  { $self->{config}{run} = 2; }
    default { status '400'; return qq("status":"unkown command"}); }
  }

  kill '10', $self->{config}{manager}{pid}; 
  header 'Access-Control-Allow-Origin' => '*';
  return;
};

# Post JSON content to restart an individual device eg: {"id":"dvswitch"}
post '/command/:command' => sub {
  my $command = params->{command};
  my $data = from_json(request->body);
  
  given ($command) {
    when ("stop")     { $self->{config}{device_control}{$data->{id}}{run} = 0; }
    when ("start")    { $self->{config}{device_control}{$data->{id}}{run} = 1; }
    when ("restart")  { $self->{config}{device_control}{$data->{id}}{run} = 2; }
    default { status '400'; return qq("status":"unkown command"}); }
  }
  kill '10', $self->{config}{manager}{pid}; 
  return;
};

# ----- Station System Commands + Info -----------------------------------------
# Trigger Station Manager to update itself
get '/manager/update' => sub {
  info("triggering update");
  kill 'HUP', $self->{config}{manager}{pid};
  return;
};

get '/manager/logs' => sub {
  my @log;
  my $count = 0;
  my $result;
  my $bw = File::ReadBackwards->new("$Bin/../logs/station-mgr.log" );

  while( defined( my $log_line = $bw->readline ) && $count < 101) {
    $count++;
    chomp $log_line;
    push(@log, $log_line);
  }

  if ($log[0]) {
    @{$result->{log}} = @log;
    header 'Access-Control-Allow-Origin' => '*';
  } else {
    status '400';
    return;
  }

  return $result;
};

# ----- Station Information ----------------------------------------------------
# Status Information
get '/status' => sub {
  my $result;
  if ($status->{status}) {
    header 'Access-Control-Allow-Origin' => '*';
    status '200';
    return $status->{status};
  } else {
    status '204';
    return;
  }
};

post '/status/:mac' => sub {
  my $mac = params->{mac};
  my $data = from_json(request->body);
  $status->{status}{$mac} = $data;
  $status->{status}{$mac}{ip} = request->env->{REMOTE_ADDR};
  return;
};

# ----- Manager/Api Internal Comms ---------------------------------------------
# Internal Communication with Manager
post '/internal/settings' => sub {
  my $data = from_json(request->body);
  $self = $data;
  info("Config data posted");
  debug($self);
  return;
};

get '/internal/settings' => sub {
  my $result->{config} = $self->{config};
  info("Config data requested");
  debug($result);
  return $result;
};

dance;

__END__
