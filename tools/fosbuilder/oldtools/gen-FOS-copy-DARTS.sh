#!/bin/bash
rm installer.log
./FOS-alpine-builder.sh
cp -rvf ./release/* /var/lib/qemu-web-desktop/machines/
chmod 0777 /var/lib/qemu-web-desktop/machines/*
