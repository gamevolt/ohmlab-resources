#!/bin/bash

# https://github.com/stamparm/ipsum

BL="blacklist"
BL1="blacklist-1"
DIR="/tmp"
OPT="/opt/ipset/blacklist"


echo "create ${BL1} hash:net family inet hashsize 8192 maxelem 65536" > $DIR/$BL1


for ip in $(curl https://raw.githubusercontent.com/stamparm/ipsum/master/ipsum.txt 2>/dev/null | grep -v "#" | grep -Ev '[[:space:]]([12])$' | cut -f 1); do echo "add ${BL1} ${ip}" >> $DIR/$BL1; done

ipset restore -f $DIR/$BL1 -exist

ipset swap $BL1 $BL

ipset destroy $BL1

ipset save $BL -f "${OPT}/${BL}.ipset"