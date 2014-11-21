#!/usr/perl5/bin/perl -w
#
use Sun::Solaris::Kstat;
use POSIX;
use IO::Socket::INET;
use Data::Dumper;
use strict;
# where pagesize lives
$ENV{'PATH'} = "/usr/bin";
$|=0;

my(undef, $hostname, undef) = uname();
#my $graphite_host = "10.200.10.23";
my $graphite_host = "192.168.0.102";
my $graphite_port = 2003;
my $output = shift || "carbon";
my $interval = shift || 10;
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
		print $msg;
                $sock->send($msg);
        } elsif ($msg =~ /(.*)\.(.*) \s+ ([\d\.]+) \s+ (\d+)/xi) {
		my $p = $1;
		my $k = $2;
		my $v = $3;
		my $t = $4;
		print "$p/gauge-$k $t:$v\n";
	}
}

if ($output eq "carbon") {
	$base="nexenta.$hostname.kstat";
} elsif ($output eq "collectd") {
	$base="PUTVAL $hostname.kstat"
}

my $kstat = Sun::Solaris::Kstat->new();
my $phys_pages = ${kstat}->{unix}->{0}->{system_pages}->{physmem};
my $pagesize = `pagesize`;
my $phys_memory = ($phys_pages * $pagesize);

while (1) {
  $sock = conCarbon($sock) if ($output eq "carbon");
  my $time=time();
  $kstat->update();
  # memory
  # print Dumper $kstat;
  my $free_pages = ${kstat}->{unix}->{0}->{system_pages}->{freemem};
  my $lotsfree_pages = ${kstat}->{unix}->{0}->{system_pages}->{lotsfree};
  my $free_memory = ($free_pages * $pagesize);
  my $lotsfree_memory = ($lotsfree_pages * $pagesize);
  
  toOut($sock, sprintf("$base/memory.total %d $time\n", $phys_memory / 1024 / 1024));
  toOut($sock, sprintf("$base/memory.free %d $time\n", $free_memory / 1024 / 1024));
  toOut($sock, sprintf("$base/memory.lotsfree %d $time\n", $lotsfree_memory / 1024 / 1024));

  # gather more stats
  my $mru_size = ${kstat}->{zfs}->{0}->{arcstats}->{p};
  my $target_size = ${kstat}->{zfs}->{0}->{arcstats}->{c};
  my $arc_min_size = ${kstat}->{zfs}->{0}->{arcstats}->{c_min};
  my $arc_max_size = ${kstat}->{zfs}->{0}->{arcstats}->{c_max};

  my $arc_size = ${kstat}->{zfs}->{0}->{arcstats}->{size};
  my $mfu_size = ${target_size} - $mru_size;
  my $mru_perc = 100*($mru_size / $target_size);
  my $mfu_perc = 100*($mfu_size / $target_size);
  my $l2_arc_size = ${kstat}->{zfs}->{0}->{arcstats}->{l2_size};

  # output arc
  toOut($sock, sprintf("$base/arc.size %d $time\n", $arc_size / 1024 / 1024));
  toOut($sock, sprintf("$base/arc.target_c %d $time\n", $target_size / 1024 / 1024));
  toOut($sock, sprintf("$base/arc.min_size %d $time\n", $arc_min_size / 1024 / 1024));
  toOut($sock, sprintf("$base/arc.max_size %d $time\n", $arc_max_size / 1024 / 1024));

  # breakdown arc
  toOut($sock, sprintf("$base/arc.mru_pct %2d $time\n", $mru_perc));
  toOut($sock, sprintf("$base/arc.mru_p %d $time\n", $mru_size / 1024 / 1024));
  toOut($sock, sprintf("$base/arc.mfu_pct %2d $time\n", $mfu_perc));
  toOut($sock, sprintf("$base/arc.mfu_c-p %d $time\n", $mfu_size / 1024 / 1024));

  # L2ARC
  toOut($sock, sprintf("$base/l2arc.size %d $time\n", $l2_arc_size / 1024 / 1024));

  # efficiency statistics...
  my $arc_hits = ${kstat}->{zfs}->{0}->{arcstats}->{hits};
  my $arc_misses = ${kstat}->{zfs}->{0}->{arcstats}->{misses};
  my $arc_accesses_total = ($arc_hits + $arc_misses);
  my $l2_arc_hits = ${kstat}->{zfs}->{0}->{arcstats}->{l2_hits};
  my $l2_arc_misses = ${kstat}->{zfs}->{0}->{arcstats}->{l2_misses};
  my $l2_arc_accesses_total = ($l2_arc_hits + $l2_arc_misses);

  my $arc_hit_perc = 100*($arc_hits / $arc_accesses_total);
  my $arc_miss_perc = 100*($arc_misses / $arc_accesses_total);
  my $l2_arc_hit_perc = 100*($l2_arc_hits / $l2_arc_accesses_total);
  my $l2_arc_miss_perc = 100*($l2_arc_misses / $l2_arc_accesses_total);

  my $mfu_hits = ${kstat}->{zfs}->{0}->{arcstats}->{mfu_hits};
  my $mru_hits = ${kstat}->{zfs}->{0}->{arcstats}->{mru_hits};
  my $mfu_ghost_hits = ${kstat}->{zfs}->{0}->{arcstats}->{mfu_ghost_hits};
  my $mru_ghost_hits = ${kstat}->{zfs}->{0}->{arcstats}->{mru_ghost_hits};
  my $anon_hits = $arc_hits - ($mfu_hits + $mru_hits + $mfu_ghost_hits + $mru_ghost_hits);

  my $real_hits = ($mfu_hits + $mru_hits);
  my $real_hits_perc = 100*($real_hits / $arc_accesses_total);

  # should be based on TOTAL HITS ($arc_hits)
  my $anon_hits_perc = 100*($anon_hits / $arc_hits);
  my $mfu_hits_perc = 100*($mfu_hits / $arc_hits);
  my $mru_hits_perc = 100*($mru_hits / $arc_hits);
  my $mfu_ghost_hits_perc = 100*($mfu_ghost_hits / $arc_hits);
  my $mru_ghost_hits_perc = 100*($mru_ghost_hits / $arc_hits);
  
  my $demand_data_hits = ${kstat}->{zfs}->{0}->{arcstats}->{demand_data_hits};
  my $demand_metadata_hits = ${kstat}->{zfs}->{0}->{arcstats}->{demand_metadata_hits};
  my $prefetch_data_hits = ${kstat}->{zfs}->{0}->{arcstats}->{prefetch_data_hits};
  my $prefetch_metadata_hits = ${kstat}->{zfs}->{0}->{arcstats}->{prefetch_metadata_hits};
 
  my $demand_data_misses = ${kstat}->{zfs}->{0}->{arcstats}->{demand_data_misses};
  my $demand_metadata_misses = ${kstat}->{zfs}->{0}->{arcstats}->{demand_metadata_misses};
  my $prefetch_data_misses = ${kstat}->{zfs}->{0}->{arcstats}->{prefetch_data_misses};
  my $prefetch_metadata_misses = ${kstat}->{zfs}->{0}->{arcstats}->{prefetch_metadata_misses};
 
  my $demand_data_hits_perc = 100*($demand_data_hits / $arc_hits);
  my $demand_metadata_hits_perc = 100*($demand_metadata_hits / $arc_hits);
  my $prefetch_data_hits_perc = 100*($prefetch_data_hits / $arc_hits);
  my $prefetch_metadata_hits_perc = 100*($prefetch_metadata_hits / $arc_hits);
  
  my $demand_data_misses_perc = 100*($demand_data_misses / $arc_misses);
  my $demand_metadata_misses_perc = 100*($demand_metadata_misses / $arc_misses);
  my $prefetch_data_misses_perc = 100*($prefetch_data_misses / $arc_misses);
  my $prefetch_metadata_misses_perc = 100*($prefetch_metadata_misses / $arc_misses);
  
  my $prefetch_data_total = ($prefetch_data_hits + $prefetch_data_misses);
  my $prefetch_data_perc = "00";
  if ($prefetch_data_total > 0 ) {
          $prefetch_data_perc = 100*($prefetch_data_hits / $prefetch_data_total);
  }

  my $demand_data_total = ($demand_data_hits + $demand_data_misses);
  my $demand_data_perc = 100*($demand_data_hits / $demand_data_total);

  # arc effciency
  toOut($sock, sprintf("$base/arc.cache.access_total %s $time\n", $arc_accesses_total));
  toOut($sock, sprintf("$base/arc.cache.hit_pct %2d $time\n", $arc_hit_perc));
  toOut($sock, sprintf("$base/arc.cache.hits %s $time\n", $arc_hits));
  toOut($sock, sprintf("$base/arc.cache.mis_pct %2d $time\n", $arc_miss_perc));
  toOut($sock, sprintf("$base/arc.cache.misses %s $time\n", $arc_misses));
  toOut($sock, sprintf("$base/arc.cache.real_pct %2d $time\n", $real_hits_perc));
  toOut($sock, sprintf("$base/arc.cache.real_hits %s $time\n", $real_hits));

  # prefetch / demand
  toOut($sock, sprintf("$base/demand.efficiency %2d $time\n", $demand_data_perc));
  toOut($sock, sprintf("$base/demand.data_hits %s $time\n", $demand_data_hits));
  toOut($sock, sprintf("$base/demand.metadata_hits %s $time\n", $demand_metadata_hits));
  toOut($sock, sprintf("$base/demand.data_misses %s $time\n",  $demand_data_misses));
  toOut($sock, sprintf("$base/demand.metadata_misses %s $time\n", $demand_metadata_misses));
  toOut($sock, sprintf("$base/demand.data_hits_pct %2d $time\n", $demand_data_hits_perc));
  toOut($sock, sprintf("$base/demand.metadata_hits_pct %2d $time\n", $demand_metadata_hits_perc));
  toOut($sock, sprintf("$base/demand.data_misses_pct %2d $time\n", $demand_data_misses_perc));
  toOut($sock, sprintf("$base/demand.metadata_misses_pct %2d $time\n", $demand_metadata_misses_perc));
  toOut($sock, sprintf("$base/prefetch.efficiency %2d $time\n", $prefetch_data_perc));
  toOut($sock, sprintf("$base/prefetch.data_hits %s $time\n", $prefetch_data_hits));
  toOut($sock, sprintf("$base/prefetch.metadata_hits %s $time\n", $prefetch_metadata_hits));
  toOut($sock, sprintf("$base/prefetch.data_misses %s $time\n", $prefetch_data_misses));
  toOut($sock, sprintf("$base/prefetch.metadata_misses %s $time\n", $prefetch_metadata_misses));
  toOut($sock, sprintf("$base/prefetch.data_hits_pct %2d $time\n", $prefetch_data_hits_perc));
  toOut($sock, sprintf("$base/prefetch.metadata_hits_pct %2d $time\n", $prefetch_metadata_hits_perc));
  toOut($sock, sprintf("$base/prefetch.data_misses_pct %2d $time\n", $prefetch_data_misses_perc));
  toOut($sock, sprintf("$base/prefetch.metadata.misses_pct %2d $time\n", $prefetch_metadata_misses_perc));

  # MRU/MFU
  toOut($sock, sprintf("$base/cache.mru_pct %2d $time\n", $mru_hits_perc));
  toOut($sock, sprintf("$base/cache.mru_hits %s $time\n", $mru_hits));
  toOut($sock, sprintf("$base/cache.mfu_pct %2d $time\n", $mfu_hits_perc));
  toOut($sock, sprintf("$base/cache.mfu_hits %s $time\n", $mfu_hits));
  toOut($sock, sprintf("$base/cache.mru_ghost_pct %2d $time\n", $mru_ghost_hits_perc));
  toOut($sock, sprintf("$base/cache.mru_ghost %s $time\n", $mru_ghost_hits));
  toOut($sock, sprintf("$base/cache.mfu_ghost_pct %2d $time\n", $mfu_ghost_hits_perc));
  toOut($sock, sprintf("$base/cache.mfu_ghost %s $time\n", $mfu_ghost_hits));

  # L2ARC 
  toOut($sock, sprintf("$base/l2arc.access %d $time\n", $l2_arc_accesses_total));
  toOut($sock, sprintf("$base/l2arc.arc_hit_pct %2d $time\n", $l2_arc_hit_perc));
  toOut($sock, sprintf("$base/l2arc.arc_hits %s $time\n", $l2_arc_hits));  
  toOut($sock, sprintf("$base/l2arc.arc_misses_pct %2d $time\n", $l2_arc_miss_perc));
  toOut($sock, sprintf("$base/l2arc.arc_misses %s $time\n", $l2_arc_misses));

  # toOut($sock, sprintf("$base.
  # toOut($sock, sprintf("$base.
  select(undef,undef,undef,$interval);
}
