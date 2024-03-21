#!/bin/bash
./rootfs/destroy
cd rootfs
rm ../temp/fog_uefi.cpio.xz
find . 2>/dev/null | cpio -o -H newc -R root:root > ../temp/fog_uefi.cpio
xz -e -7 -T0 -C crc32 ../temp/fog_uefi.cpio
ls -alh ../temp/fog_uefi.cpio.xz
cd ..
cp -rvf ./temp/fog_uefi.cpio.xz /var/lib/qemu-web-desktop/machines/
chmod 0777 /var/lib/qemu-web-desktop/machines/*
