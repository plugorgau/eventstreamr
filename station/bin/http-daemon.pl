#!/usr/bin/perl
use Dancer; # libdancer-perl 
use IPC::Shareable; # libipc-shareable-perl
set serializer => 'JSON';
set logger => 'console';
set log => 'core';

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

get '/settings/:mac' => sub {
  my $data->{mac} = params->{mac};
  # status 200 config exists
  # status 204 config not exists
  $data->{config} = $config;
  $data->{result} = '200';
  return $data;
};

get '/settings' => sub {

# status 200 config exists
# status 204 config not exists
  my $data->{config} = $config;
  $data->{result} = '200';
  return $data;
};

post '/settings/:mac' => sub {
  my $data->{mac} = params->{mac};
  $data->{body} = request->body;
  if ($data->{mac} == $config->{macaddress}) {
    debug($data);
    return qq({"result":"200"});
  } else {
    return qq({"result":"400"});
  }
};


dance;

__END__
