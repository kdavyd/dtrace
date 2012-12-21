#!/usr/sbin/dtrace -s
#pragma D option quiet
/* 
* zfsarcblocksize.d - Script used for high-level observation
* of the ARC size distribution for data and metadata accesses
* quantize function is used to display a distribution plot
* of bytes and of type of data being accessed, i.e. real data
* or Metadata. It may be useful to observe the sizes of blocks
* being retrieved and the sizes of metadata reads vs. data reads
* in the ARC.
*/

dtrace:::BEGIN
{
    cnt = 0;
}

sdt:zfs::arc-hit,sdt:zfs::arc-miss 
/ this->b_size = ((arc_buf_hdr_t *)arg0)->b_size /
{
    @b["bytes"] = quantize(this->b_size);
    ts = walltimestamp;
    cnt++;
} 

sdt:zfs::arc-hit,sdt:zfs::arc-miss
/ this->b_size /
{   /* Determine if this is data or Metadata, if argument is 0,
    it is data, else 1 is Metadata */
    /* @t[this->b_type = ((arc_buf_hdr_t *)arg0)->b_type == 0 ? 
    "Data" : "Metadata"] = quantize(((arc_buf_hdr_t *)arg0)->b_type); =>
    Attempted to quantize this, but it makes little sense, since there are
    only two options, with regard to b_type (0,1) */
    @t[this->b_type = ((arc_buf_hdr_t *)arg0)->b_type == 0 ? 
    "Data" : "Metadata"] = count();
} 

tick-1sec 
/ this->b_size && cnt > 0 /
{
    printf("\n\n%Y\n", ts);
    printa("\tBytes: %@d\n", @b); 
    printa("\tType (%s): %@d  ", @t);
    /* printa("\n   Type(0->data, 1->metadata): %@d\n", @t); */
    clear(@b); clear(@t);
    cnt = 0; /* Reset counter for next round */
}
