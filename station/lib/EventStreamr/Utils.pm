package EventStreamr::Utils;
use Moo;
use IO::Socket::INET; # System Class
use Proc::ProcessTable; # libproc-processtable-perl
use feature 'switch';
use Data::Dumper;

sub test {
  my $self = shift;
  $self->{portstate} = port("localhost","1234");
  $self->{get_pid_command} = get_pid_command("video0","ffmpeg -f video4linux2 -s vga -r 25 -i /dev/video0 -target pal-dv - | dvsource-file /dev/stdin -h localhost -p 1234","v4l");
  return;
}

sub port {
  my $self = shift;
  my ($host,$port) = @_;
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

sub get_pid_command {
  my $self = shift;
  my ($id,$command,$type) = @_;
  my $regex;
  my $return;
  
  given ($type) {
    when ("v4l")      { $regex = "ffmpeg.+\\/dev\\/$id.*"; }
    when ("dv")       { $regex = "dvgrab.+$id.*"; }
    when ("stream")   { $regex = "ffmpeg2theora.*"; } # This needs fixing, but will do for testing
    default           { $regex = $command }
  }

  my $pt = Proc::ProcessTable->new;
  my @procs = grep { $_->cmndline =~ /^$regex/ } @{ $pt->table };
  if (@procs) {
    $return->{pid} = $procs[0]->pid;
    $return->{running} = 1;
  } else {
    $return->{running} = 0;
  }
  
  return $return;
}
1
