#!/bin/bash

apk info -e -s \* >/tmp/apksize
awk 'NR % 3 == 1' /tmp/apksize | cut -d ' ' -f 1 > /tmp/apkname
awk 'NR % 3 == 2' /tmp/apksize > /tmp/apksize2

while read -r n unit; do
  B=$n
  case "$unit" in
    KiB) B=$(( n * 1024 )) ;;
    MiB) B=$(( n * 1024 * 1024 )) ;;
    GiB) B=$(( n * 1024 * 1024 * 1024 )) ;;
  esac
  printf "%12u %4s %-3s\n" $B $n $unit
done < /tmp/apksize2 > /tmp/apksize

paste -d' ' /tmp/apksize /tmp/apkname | sort -n -u | cut -c14-
rm /tmp/apksize /tmp/apksize2 /tmp/apkname

