#!/usr/sbin/dtrace -s 
#pragma D option quiet 
#pragma D option switchrate=10hz 
dtrace:::BEGIN 
{ 
        printf("%16s\t%20s\t%-18s\t%2s\t%-10s\t%6s\t%s\t%s\n", "TIME(us)", "TIME", 
            "CLIENT", "OP", "OFFSET(KB)", "BYTES", "4K-ALIGNED", "4K-SIZE");
} 
nfsv3:::op-read-start 
{ 
        printf("%-16d\t%Y\t%-18s\t%2s\t%-10d\t%6d\t%s\t%s\n", 
			timestamp / 1000, walltimestamp,
            args[0]->ci_remote, "R", args[2]->offset / 1024,
            args[2]->count, 
			(args[2]->offset % 4096) == 0 ? "1" : "0",
			(args[2]->count % 4096) == 0 ? "1" : "0");
} 
nfsv3:::op-write-start 
{ 
        printf("%-16d\t%Y\t%-18s\t%2s\t%-10d\t%6d\t%s\t%s\n", 
			timestamp / 1000, walltimestamp,
            args[0]->ci_remote, "W", args[2]->offset / 1024, 
            args[2]->data.data_len, 
			(args[2]->offset % 4096) == 0 ? "1" : "0",
			(args[2]->data.data_len % 4096) == 0 ? "1" : "0"); 
} 

