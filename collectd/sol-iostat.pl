#!/usr/bin/perl -w
#
use POSIX;
use IO::Socket::INET;
use Data::Dumper;
use strict;
# where iostat lives
$ENV{'PATH'} = "/usr/bin";
$|=0;

my(undef, $uname, undef) = uname();
# later perhaps sort per jbod ? :)
#my $graphite_host = "10.200.10.23";
my $graphite_host = "192.168.0.102";
my $graphite_port = 2003;
my $output = shift || "carbon";
my $hostname = shift || $uname;
my $interval = shift || 10;
$interval = $ENV{COLLECTD_INTERVAL} if defined($ENV{COLLECTD_INTERVAL});
my $sock = undef;
my $base;

sub conCarbon {
        return $sock if (defined($sock));
        $sock = IO::Socket::INET->new(
                        Proto    => "tcp",
                        PeerPort => $graphite_port,
                        PeerAddr => $graphite_host,
                ) || die "Unable to create socket: $!\n";
        print "connected to $graphite_host on $graphite_port\n";
        return $sock;
}

sub toOut {
        my $sock = shift;
        my $msg = shift || return undef;
        if ($sock) {
		$msg =~ s/\//\./g;
		print $msg;
                my $r = $sock->send($msg);
  		if( ! defined $r ) {
      			die "can't sent: " . $sock->error;
  		}
  		print "sent $r bytes\n";

        } elsif ($msg =~ /(.*)\.(.*) \s+ ([\d\.]+) \s+ (\d+)/xi) {
		my $p = $1;
		my $t = $2;
		my $v = $3;
		my $time = $4;
		print "$p/gauge-$t $time:$v\n";
	}

}

if ($output eq "carbon") {
	$base="nexenta.$hostname.disks";
} elsif ($output eq "collectd") {
	$base="PUTVAL $hostname.disks";
}

my @header;
die if ($interval !~ /\d+/);
open(FH, "iostat -exn 10 | ") || die "unable to iostat: $!";
while(<FH>) {
	chomp;
	$sock = conCarbon($sock) if ($output eq "carbon");
	if ($_ =~ /r\/s/) {
		$_ =~ s/\//_/g;
		$_ =~ s/\%(\w+)/pct_$1/g;
		@header = reverse(split(/\s+/, $_));
		shift @header;
		# print Dumper @header
	} elsif ($_ !~ /extended/) {
		my $time = time();
		my @m = reverse(split(/\s+/, $_));
		my $device = shift @m;
		for(0..$#m) {
			next if (!$header[$_]);
			toOut($sock, $base."/$device.".$header[$_]." ".$m[$_]." $time\n");
				# if ($m[$_] != 0.0 || $m[$_] != 0);
		}
	} 
}
close(FH);
