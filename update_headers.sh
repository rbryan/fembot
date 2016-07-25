#!/bin/bash

for i in `ls tdata/tnet*`; do
	lines=$(($(wc -l $i | cut -d' ' -f1) - 1 ))
	cat $i | tail -n $lines > $i
	echo $(( $lines / 2 )) 16 8 > new_file
	cat $i >> new_file
	mv new_file $i
done

for i in `ls tdata/cnet*`; do
	lines=$(($(wc -l $i | cut -d' ' -f1 ) - 1 ))
	cat $i | tail -n $lines > $i
	echo $(( $lines / 2 )) 8 8 > new_file
	cat $i >> new_file
	mv new_file $i
done
