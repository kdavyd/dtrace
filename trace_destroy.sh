#!/usr/bin/bash

# Copyright 2016, Nexenta Systems, Inc. 

# 
# Watch in-progress synchronous ZFS destroys that were active at the time of starting the script.
#

# Determine which function to trace depending on whether we are on 3.x or 4.x

{
if [[ $(echo old_synchronous_dataset_destroy::whatis|mdb -k) == *"old_synchronous_dataset_destroy"* ]]
then 
	func="old_synchronous_dataset_destroy"
fi

if [[ $(echo dsl_dataset_destroy::whatis|mdb -k) == *"dsl_dataset_destroy"* ]]
then 
	func="dsl_dataset_destroy"
fi
} &> /dev/null

echo Tracing $func"()... Ctrl-C to exit."

update_threads () { threads=$(echo "::walk thread|::findstack -v"|mdb -k|grep $func| cut -d "(" -f 2 | cut -d "," -f 1); }

update_threads
while true
do
for thread in $threads
	do 
	for i in {1..12}
		do
			date 
			echo "$thread::print -t dsl_dataset_t ds_dir | ::print -t struct dsl_dir dd_phys | ::print -t -d dsl_dir_phys_t dd_used_bytes" | mdb -k
			sleep 5
		done
	update_threads
	done
sleep 5
done

