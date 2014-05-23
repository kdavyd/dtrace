#!/usr/bin/bash

for i in `echo "::walk thread | ::findstack -v" | mdb -k | grep dsl_dataset_destroy | cut -d "(" -f 2 | cut -d "," -f 1`; do while true; do date; echo "$i::print -t dsl_dataset_t ds_dir | ::print -t struct dsl_dir dd_phys | ::print -t -d dsl_dir_phys_t dd_used_bytes" | mdb -k; sleep 5; done; done
