package EventStreamr::Schedule;
use Moo;
use Cache::FileCache;
use HTTP::Tiny;
use File::Path 'make_path';
use JSON;

has expiry => ( is => 'ro',
                default => '600',
              );

has cache_root => ( is => 'ro',
                    default => '/tmp/schedule',
                  );

has schedule_url => ( is  => 'ro',
                      required => 1,
                    );

sub retrieve {
  my $self = shift;
  if (! -d $self->{cache_root}) {
    make_path($self->{cache_root});
  }

  my $cache = new Cache::FileCache( {namespace  => 'schedule_cache', default_expires_in => $self->{expiry}, cache_root => $self->{cache_root} } );
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
  return $self->{schedule};
}

1
