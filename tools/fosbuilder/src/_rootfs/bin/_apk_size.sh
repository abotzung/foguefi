#!/bin/bash
# _apk_size.sh - A little helper to get apk size
# Copyright (C) 2024 Alexandre BOTZUNG <alexandre@botzung.fr>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

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

