package EventStreamr::Utils;
use Moo;
use IO::Socket::INET;

sub test {
  my $self = shift;
  $self->{portstate} = port("localhost","1234");
  return;
}

sub port {
  my ($self,$host,$port) = @_;
  my $state;
  my $sock = new IO::Socket::INET ( PeerAddr => $host,
                                    PeerPort => $port,
                                    Proto    => 'tcp'
                                  );
  if ($sock) {
    $state = 1;
    $sock->close;
  } else {
    $state = 0;
  }
  return $state;
}

1
