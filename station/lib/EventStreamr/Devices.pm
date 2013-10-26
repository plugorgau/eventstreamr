package EventStreamr::Devices;
use Moo; # libmoo-perl
use Device::USB; # libdevice-usb-perl
use Data::Dumper;

sub list {
  my $self = shift;
  @{$self->{usb_devices}} = usb_devices();
  return;
}

sub usb_devices {
  my $usb = Device::USB->new();
  my $devices;
  my @devices = $usb->list_devices();
  foreach my $device (@devices) {
    my $dev = $usb->find_device( $device->{descriptor}{idVendor}, $device->{descriptor}{idProduct} );
    #$dev->open();
    print "Manufactured by ", $dev->manufacturer(), "\n",
      " Product: ", $dev->product(), "\n";
    #print Dumper($dev);
  }
  return $devices;
}

1;
