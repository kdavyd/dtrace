#!/usr/bin/perl

use Getopt::Std;
use POSIX;
use Data::Dumper;
use IO::Socket::INET;
use strict;
$| = 1;

my %opt;
my(undef, $hostname, undef) = uname();
my $interval;
my $base;
my $debug = 0;

#
# Only if output option is "carbon"
#
my $graphite_host = "192.168.0.102";
my $graphite_port = 2003;
my $sock = undef;

# Override PATH variable so we get run setuid
$ENV{'PATH'} = "/usr/bin:/sbin:/usr/sbin:/usr/local/bin:/usr/local/sbin:/usr/gnu/bin";


sub usage()
{
        print STDERR "usage: $0 [-hd] -o output \n";
        print STDERR "-h                : this (help) message\n";
        print STDERR "-d                : debug\n";
	print STDERR "-H		: Override Hostname\n";
        print STDERR "example: $0 -d -o stdout\n";
        exit;
}

#
# Creat socket. Use UDP so we don't need to handle dropped connections.
#
sub conCarbon {
        return $sock if (defined($sock));
        $sock = IO::Socket::INET->new(
                        Proto    => "udp",
                        PeerPort => $graphite_port,
                        PeerAddr => $graphite_host,
                ) || die "Unable to create socket: $!\n";
        print "connected to $graphite_host on $graphite_port\n";
        return $sock;
}

sub toOut {
	local $| = 1;
        my $msg = shift || return undef;
	# Send over the socket and ignore transport errors
	if (($opt{o} eq "carbon") && ($sock)) {
		print "carbon $msg" if ($debug == 1);
                $sock->send($msg);
        }
	elsif (($opt{o} eq "stdout") || ($opt{o} eq "collectd")) {
		print "$opt{o} $msg" if ($debug == 1);
		print "$msg";
	}
}

#
# Main
# 

my $opt_string = 'hdo:n:';
getopts( "$opt_string", \%opt ) or usage();
usage() if $opt{h};

$debug = 1 if $opt{d};
print "$0 $opt{o} \n" if ($debug == 1);

if ($opt{n}) {
	$hostname = $opt{n};
} 

if ($opt{o} eq "carbon") {
	$sock = conCarbon($sock);
        $base="nexenta.ns3.$hostname.comstar.io";
} elsif ($opt{o} eq "collectd") {
	# prefix is set in collectd.conf
        $base="PUTVAL $hostname.comstar/io";
} elsif ($opt{o} eq "stdout") {
        $base="$hostname.comstar io:";
}


open(STATS, "/usr/local/collectd/bin/stmf_iops.d |") || die "can't fork: $!";
while (<STATS>) {
        chomp;
        if ($_ !~ /^\d+$/) {
                # if we suspect epoch is missing...
                if ($_ =~ /(.*) \s+ ([\d\.]+) \s+ (\d+)$/xi) {
			toOut("$base.$1 $2 $3\n") if ($opt{o} eq "carbon");
			toOut("$base/gauge-$1 $3:$2\n") if ($opt{o} eq "collectd");
			#print "$base/gauge-$1 $3:$2\n" if ($opt{o} eq "collectd");
			toOut("$base $1 = $2 at $3\n") if ($opt{o} eq "stdout");
                } elsif ($_ =~ /(.*) \s+ ([\d\.]+)/) {
                        toOut("$base.$1 $2 ".time()."\n") if ($opt{o} eq "carbon");
                        toOut("$base/gauge-$1 ".time().":$2\n") if ($opt{o} eq "collectd");
                        toOut("$base $1 = $2 at ".time()."\n") if ($opt{o} eq "stdout");
                }
        }
}
close(STATS) || die "bad stat: $! $?";

