#!/bin/bash

var='./buildtool'

mount -v -t proc none "${var}/proc"
mount -v --rbind /sys "${var}/sys"
mount --make-rprivate "${var}/sys"
mount -v --rbind /dev "${var}/dev"
mount --make-rprivate "${var}/dev"

 
# Some systems (Ubuntu?) symlinks /dev/shm to /run/shm.
if [ -L /dev/shm ] && [ -d /run/shm ]; then
  mkdir -p "${var}/run/shm"
  mount -v --bind /run/shm "${var}/run/shm"
  mount --make-private "${var}/run/shm"
fi

mkdir -p "${var}/sources"
mount -v --bind "./sources" "${var}/sources"
mount --make-private "${var}/sources"
