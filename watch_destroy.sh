#!/usr/bin/bash

# Author: Kirill.Davydychev@Nexenta.com
# Copyright 2014, Nexenta Systems, Inc. 

# 
# Watch in-progress synchronous ZFS destroys that were active at the time of starting the script.
#

echo "Ctrl-C to exit."
for i in `echo "::walk thread | ::findstack -v" | mdb -k | grep dsl_dataset_destroy | cut -d "(" -f 2 | cut -d "," -f 1`; do while true; do date; echo "$i::print -t dsl_dataset_t ds_dir | ::print -t struct dsl_dir dd_phys | ::print -t -d dsl_dir_phys_t dd_used_bytes" | mdb -k; sleep 5; done; done
