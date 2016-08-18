zio_vdev_io_start:entry
{ 
        printf("vdev_bytes_statistics: NULL: %d\tREAD: %d\tWRITE: %d\tFREE: %d\tCLAIM: %d\tIOCTL: %d\n",
                        args[0]->io_vd->vdev_stat.vs_bytes[0],          /* NULL */
                        args[0]->io_vd->vdev_stat.vs_bytes[1],          /* READ */
                        args[0]->io_vd->vdev_stat.vs_bytes[2],          /* WRITE */
                        args[0]->io_vd->vdev_stat.vs_bytes[3],          /* FREE */
                        args[0]->io_vd->vdev_stat.vs_bytes[4],          /* CLAIM */
                        args[0]->io_vd->vdev_stat.vs_bytes[5]);         /* IOCTL */
}
