#!/bin/bash

date=$1
tickfile="/var/local/ib/ramfs/ticks-${date}.csv"
spanfile="/var/local/ib/ramfs/spans-${date}.csv"

# empty spanfile
> $spanfile

# get symbols 
symbols=`cat ${tickfile} | cut -d ',' -f 1 | sort | uniq`
for symbol in $symbols; do
  dim="${symbol:0:2}"
  configfile="/var/local/eztrader/symbols/$dim.yml"
  if [ ! -f $configfile ]; then
    echo $configfile not found. Please make sure that all configfile exist for $symbols.
    exit 1
  fi
  ticksize=`cat ${configfile} | grep ticksize | cut -d ':' -f 2`
  cat ${tickfile} | grep $symbol | sort | cut -d ',' -f 2,3 | ../bin/spanbars --span 4 --ticksize $ticksize | sed "s/^/$symbol,/" >> $spanfile
  echo "finished ${date} \ ${dim}"
done

tmpfile=`mktemp`
mv $spanfile $tmpfile 
cat $tmpfile  | sort -t, -k3 -n | uniq > $spanfile

