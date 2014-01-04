#!/usr/bin/perl

use v5.10;
use FindBin qw($Bin);

my $stream_server = "controller.local";
my $stream_pass   = "lca2014perth";
my $stream_room   = shift;

my $rooms = {
	"eng-lt1"  => "Engineering Lecture Theatre 1",
	"eng-lt2"  => "Engineering Lecture Theatre 2",
	"octagon"  => "Octagon Lecture Theatre (Keynotes)",
	"wool"     => "Woolnough Lecture Theatre",
	"webb"	   => "Webb Lecture Theatre",
	"gentilli" => "Gentilli Lecture Theatre",
#	"roberts"  => "Robert Street Lecture Theatre",
};


if ( !defined($stream_room) ) {
	foreach my $room ( keys %$rooms ) {
		system( "$Bin/manage-streams.pl $room &" );
	}
	exit 0;
}
else {
	my $name = $rooms->{$stream_room};
	while( 1 ) {
		say "control loop for: $stream_room";
		system( "dvsink-command -h $stream_room-1.local -p 1234 -- ffmpeg2theora - -f dv -F 25:2 -x 640 -y 512 --speedlevel 0 -v 4 --optimize -V 420 --soft-target -a 4 -c 1 -H 44100 -o - | oggfwd -n \"$name\" $stream_server 8000 $stream_pass /$stream_room.ogg" );
		sleep 10;
	}
	exit 0;
}

exit 0;
