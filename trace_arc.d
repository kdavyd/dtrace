#!/usr/sbin/dtrace -s
#pragma D option flowindent
 
fbt:zfs:arc_read:entry
/pid == $target/ 
{
	self->ts = timestamp;
	self->interested = 1;
}
 
zfs::
/self->interested/ 
{
}

buf_hash_find:entry
/self->interested/
{
	printf("Spa: %d, DVA %d.%d, birth: %d", args[0], args[1]->dva_word[0], args[1]->dva_word[1], args[2]);
}

buf_hash_insert:entry
/self->interested/
{
	/* ARC_IN_HASH_TABLE flag might be set here */
}

arc_buf_alloc:entry
/self->interested/
{
	printf("b_datacnt may be incremented here");
}

arc_buf_clone:entry
/self->interested/
{
	printf("b_datacnt may be incremented here");
}

buf_hash_insert:return
/self->interested/
{

}

arc_released:return
/self->interested/
{
	trace(args[1]);
}

dbuf_read_done:entry
/self->interested/
{
	trace(args[0]->io_error);
}

dbuf_read_impl:entry
/self->interested/
{
	/* ARC_L2CACHE flag might be set here */
}

dbuf_read_impl:return
/self->interested/
{

}

dmu_objset_open_impl:entry
/self->interested/
{
	/* ARC_L2CACHE flag might be set here */
}

dmu_objset_open_impl:return
/self->interested/
{

}

arc_read_nolock:entry
/self->interested/
{
	printf("IMPORTANT - next, figure out who gives us these arc_flags and why? \n");
	printf("arc_flags: %d - ", *args[7]);
	printf("%s", (*args[7] & (1 << 1)) ?  "ARC_WAIT " : "");
	printf("%s", (*args[7] & (1 << 2)) ?  "ARC_NOWAIT " : "");
	printf("%s", (*args[7] & (1 << 3)) ?  "ARC_PREFETCH " : "");
	printf("%s", (*args[7] & (1 << 4)) ?  "ARC_CACHED " : "");
	printf("%s", (*args[7] & (1 << 5)) ?  "ARC_L2CACHE " : "");
	/* ARC_L2CACHE flag might be set here in 3 different spots */ 

}

arc_read_nolock:return
/self->interested/
{

}

arc_write:entry
/self->interested/
{

}

arc_write:return
/self->interested/
{
	/* ARC_L2CACHE flag might be set here */
}


arc_get_data_buf:entry
/self->interested/
{
	printf("When called from within arc_read_nolock, b_datacnt is increased right before calling here. See arc.c line 2827 \n");
	printf("Buf state: %a, Buf size: %d, Buf type: %s", args[0]->b_hdr->b_state, args[0]->b_hdr->b_size, args[0]->b_hdr->b_type == 0 ? "ARC_BUFC_DATA" : "ARC_BUFC_METADATA");
}

arc_adapt:entry
/self->interested/
{
	printf("State: %a, Size: %d", args[1], args[0]);
}

arc_reclaim_needed:return
/self->interested/
{
	printf("%s", args[1] == 0 ? "false" : "true");
}

arc_change_state:entry
/self->interested/
{
	printf("New state: %a, Old state: %a, Refcnt: %d, Datacnt: %d, B_size: %d", args[0], args[1]->b_state, args[1]->b_refcnt.rc_count, args[1]->b_datacnt, args[1]->b_size);
}

zio_buf_alloc:entry
/self->interested/
{
	trace(args[0]);
}

arc_space_consume:entry
/self->interested/
{
	printf("Consuming %d bytes of arc_space_type %s", args[0], args[1] == 0 ? "DATA" : "HDRS, L2HDRS or OTHER");
}

dbuf_update_data:entry
/self->interested/
{
	trace(args[0]->db_level);
	trace(args[0]->db_user_data_ptr_ptr);
}

buf_hash_find:return
/self->interested/
{
	printf("Datacnt: %d, Hdr_flags: %d", args[1]->b_datacnt, args[1]->b_flags);
}

arc_access:entry
/self->interested/
{
	printf("Datacnt: %d,",args[0]->b_datacnt);
	printf(" Hdr_flags: %d = ", args[0]->b_flags);
	printf("%s", (args[0]->b_flags & (1 << 1)) ?  "ARC_WAIT " : "");
	printf("%s", (args[0]->b_flags & (1 << 2)) ?  "ARC_NOWAIT " : "");
	printf("%s", (args[0]->b_flags & (1 << 3)) ?  "ARC_PREFETCH " : "");
	printf("%s", (args[0]->b_flags & (1 << 4)) ?  "ARC_CACHED " : "");
	printf("%s", (args[0]->b_flags & (1 << 5)) ?  "ARC_L2CACHE " : "");
	printf("%s", (args[0]->b_flags & (1 << 6)) ?  "WTF_6 " : "");
	printf("%s", (args[0]->b_flags & (1 << 7)) ?  "WTF_7 " : "");
	printf("%s", (args[0]->b_flags & (1 << 8)) ?  "WTF_8 " : "");
	printf("%s", (args[0]->b_flags & (1 << 9)) ?  "ARC_IN_HASH_TABLE " : "");
	printf("%s", (args[0]->b_flags & (1 << 10)) ? "ARC_IO_IN_PROGRESS " : "");
	printf("%s", (args[0]->b_flags & (1 << 11)) ? "ARC_IO_ERROR " : "");
	printf("%s", (args[0]->b_flags & (1 << 12)) ? "ARC_FREED_IN_READ " : "");
	printf("%s", (args[0]->b_flags & (1 << 13)) ? "ARC_BUF_AVAILABLE " : "");
	printf("%s", (args[0]->b_flags & (1 << 14)) ? "ARC_INDIRECT " : "");
	printf("%s", (args[0]->b_flags & (1 << 15)) ? "ARC_FREE_IN_PROGRESS " : "");
	printf("%s", (args[0]->b_flags & (1 << 16)) ? "ARC_L2_EVICTING " : "");
	printf("%s", (args[0]->b_flags & (1 << 17)) ? "ARC_L2_EVICTED " : "");
	printf("%s", (args[0]->b_flags & (1 << 18)) ? "ARC_L2_WRITE_HEAD " : "");


}
add_reference:entry
/self->interested/
{
	trace(args[0]->b_datacnt);
	trace(args[0]->b_flags);
}

fbt:zfs:arc_read:return
/pid == $target/ 
{
	printf("Time spent in arc_read: %d ns", timestamp - self->ts);
        self->iinterested = 0;
	self->ts = NULL;
}

fbt::arc_evict:entry
/self->interested/
{
        printf("%Y %-10a %-10s %-10s %d bytes\n", walltimestamp, args[0],
              arg4 == 0 ? "data" : "metadata",
              arg3 == 0 ? "evict" : "recycle",  arg2);

	/* ARC_IN_HASH_TABLE flag might be set here */

}

fbt::arc_buf_evict:entry
/self->interested/
{

	/* ARC_IN_HASH_TABLE flag might be set here */

}

fbt:zfs:arc_evict_needed:return
/self->interested/
{
	printf("%s", args[1] == 0 ? "false" : "true");
}

fbt:zfs:buf_hash_remove:entry
/self->interested/
{
	printf("Removing buffer hash of %a", args[0]->b_state);
}

fbt:zfs:buf_hash_remove:return
/self->interested/
{
}
