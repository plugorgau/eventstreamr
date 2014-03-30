package EventStreamr::Utils;
use Moo;

sub Prompt { # inspired from here: http://alvinalexander.com/perl/edu/articles/pl010005
  my $self = shift;
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
