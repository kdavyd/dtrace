syscall:::entry
{

        self->syscallname = probefunc;
}

syscall:::return
{

        self->syscallname = "";
}

nfsclient:::
/self->syscallname != 0 && self->syscallname != ""/
{

        trace(probemod);
        trace(arg0);
        trace(execname);
        trace(self->syscallname);
}

nfsclient:::
/self->syscallname == 0 || self->syscallname == ""/
{

        trace(probemod);
        trace(arg0);
        trace(execname);
        trace("-");
}
