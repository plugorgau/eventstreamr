package EventStreamr::Devices;
use Moo; # libmoo-perl
use Cwd 'realpath';

use Data::Dumper;

sub list {
  my $self = shift;
  @{$self->{v4l_devices}} = v4l_devices();
  return;
}

sub v4l_devices {
  my @v4ldevices = </dev/video*>;
  my $v4l_devices;
  foreach my $device (@v4ldevices) {
    $device =~ m/\/dev\/(?<index>.+)/;
    my $index = $+{index};
    $v4l_devices->{$index}{path} = $device;
    $v4l_devices->{$index}{name} = get_v4l_name($index);
  }
  return $v4l_devices;
}

sub get_v4l_name {
  my ($device) = @_;
  my $name;

  # Find USB
  my $index = $+{index};
  my @usbs = </dev/v4l/by-id/*>;
  foreach my $usb (@usbs) { # suffers from Big0 notation, but should only be a limited number of devices
    if ( realpath($usb) =~ /$index/ ) {
      $usb =~ m/\/dev\/v4l\/by-id\/usb-(?<name> .+)-video-index\d/ix;
      $name = $+{name};

      # Some older devices don't present a name in the path but an ID
      if ( $name =~ /^[^+s]{4}_[^+s]{4}$/ ) {
        $name = name_lsusb($name);
      } else {
        $name =~ s/_/\ /g;
      }
      last;
    }
  }
  # Find PCI
  unless ($name) {
    my @pcis = </dev/v4l/by-path/*>;
    foreach my $pci (@pcis) {
      if ( realpath($pci) =~ /$index/ ) {
        $pci =~ m/pci-[^+s]{4}:(?<pciid>..:..\..)-video-index\d/ix;
        $name = name_lspci($+{pciid});
        last;
      }
    }
  }

  return $name;
}

sub name_lsusb {
  my ($name) = @_;
  $name =~ m/^(?<vid> [^+s]{4})_(?<did> [^+s]{4})$/ix;
  $name = `lsusb | grep \"$+{vid}:$+{did}\"`;
  $name =~ m/^Bus.\d+.Device.\d+:.ID.[^+s]{4}:[^+s]{4}.(?<name>.+)/ix;
  $name = $+{name};
  return $name;
}

sub name_lspci {
  my ($name) = @_;
  $name = `lspci | grep \"$name\"`;
  $name =~ m/..:..\...(?<name>.+)/ix;
  $name = $+{name};
  return $name;
}

1;
