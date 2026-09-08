#!/bin/sh

# Extract syscalls from a strace log
# usage:
# strace -o trace.log -f program
# ./strace.sh < trace.log

grep -oE "^[0-9]* *[a-z]+\(" < /dev/stdin | cut -d' ' -f2 | sed 's/($//' | sort | uniq -c
