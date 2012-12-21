#!/usr/sbin/dtrace -s 

#pragma D option quiet 

dtrace:::BEGIN 
{ 
	trace("Tracing CIFS operations... Interval 5 secs.\n"); 
} 

smb:::op-* 
{ 
	@ops[args[0]->ci_remote, probename] = count(); 
} 

profile:::tick-5sec, 
dtrace:::END 
{ 
	printf("\n   %-32s %-30s %8s\n", "Client", "Operation", "Count");
	printa("   %-32s %-30s %@8d\n", @ops); 
	trunc(@ops); 
} 
