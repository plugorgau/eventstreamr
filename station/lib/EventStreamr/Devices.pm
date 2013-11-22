package EventStreamr::Devices;
use Moo; # libmoo-perl
use Cwd 'realpath';
use File::Slurp 'read_file'; #libfile-slurp-perl
use Hash::Merge::Simple; # libhash-merge-simple-perl
use Data::Dumper;

sub all {
  my $self = shift;
  my $v4l = v4l();
  my $dv = dv();
  my $alsa = alsa();
  @{$self->{devices}{v4l}{all}} = ();
  @{$self->{devices}{dv}{all}} = ();
  @{$self->{devices}{alsa}{all}} = ();

  if ($v4l) { $self->{devices}{v4l} = $v4l;       }
  if ($dv)  { $self->{devices}{dv} = $dv;         }
  if ($alsa)  { $self->{devices}{alsa} = $alsa;   }
  if ($v4l || $dv || $alsa) {
    $self->{devices}{all} = Hash::Merge::Simple->merge($v4l,$dv,$alsa);
    @{$self->{devices}{array}} = (@{$self->{devices}{v4l}{all}}, @{$self->{devices}{dv}{all}},@{$self->{devices}{alsa}{all}});
  }

  return $self->{devices};
}

sub v4l {
  my @v4ldevices = </dev/video*>;
  my $v4l_devices;
  foreach my $device (@v4ldevices) {
    $device =~ m/\/dev\/(?<index>.+)/;
    my $index = $+{index};
    $v4l_devices->{$index}{device} = $device;
    $v4l_devices->{$index}{name} = get_v4l_name($index);
    $v4l_devices->{$index}{type} = "v4l";
    push (@{$v4l_devices->{all}}, $v4l_devices->{$index});
  }
  return $v4l_devices;
}

sub dv {
  my @dvs = </sys/bus/firewire/devices/*>;
  my $dv_devices;

  foreach my $dv (@dvs) { # suffers from Big0 notation, but should only be a limited number of devices
    if (-e "$dv/vendor_name") {
      my $vendor_name = read_file("$dv/vendor_name");
      chomp $vendor_name;
      
      unless ($vendor_name eq "Linux Firewire") {
        my $guid = read_file("$dv/guid");
        my $model = read_file("$dv/model_name");
        chomp $guid;
        chomp $model;
        $dv_devices->{$guid}{device} = $guid;
        $dv_devices->{$guid}{model} = $model;
        $dv_devices->{$guid}{vendor} = $vendor_name;
        $dv_devices->{$guid}{type} = "dv";
        push (@{$dv_devices->{all}}, $dv_devices->{$guid}); ;
      }
    }
  }
  return $dv_devices;
}

sub alsa { # Only Does USB devices currently
  my $alsa_devices;
  my @devices = read_file("/proc/asound/cards");
  @devices = grep { /].+USB Audio (CODEC|Device)/ } @devices;
  chomp @devices;

  foreach my $device (@devices) {
    $device =~ m/^.+(?<card> \d+).*/x;
    my $card = $+{card};
    my $usbid = read_file("/proc/asound/card$card/usbid");
    my $name = name_lsusb($usbid);
    chomp $usbid;

    $alsa_devices->{$card}{usbid} = $usbid;
    $alsa_devices->{$card}{name} = $name;
    $alsa_devices->{$card}{device} = $card;
    $alsa_devices->{$card}{type} = "alsa";
    push (@{$alsa_devices->{all}}, $alsa_devices->{$card});
  }
  return $alsa_devices;
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

      # Some lesser known devices don't present a name in the path but an ID
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
  $name =~ m/^(?<vid> [^+s]{4}).(?<did> [^+s]{4})$/ix;
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
