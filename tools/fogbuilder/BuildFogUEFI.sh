#!/bin/bash
#============================================================================
#              F O G    P R O J E C T    v 1 . 5 . 10 . x
#                    Unofficial Secure Boot Patch
#             FOGUefi (https://github.com/abotzung/foguefi)
#
# Auteur       : Alexandre BOTZUNG [alexandre.botzung@grandest.fr]
# Auteur       : The FOG Project team (https://github.com/FOGProject/fogproject)
# Version      : 20230724
# Licence      : http://opensource.org/licenses/gpl-3.0
#============================================================================ 
#
# Génère le nouveau FOG Operating system "FOG Stub" à partir de Clonezilla et du dernier init.xz en date
#
# NOTE : dialog, dtach efiboot*, framebuffer-vncserver && socat sont des fichiers binaires récupérés depuis les sources d'Ubuntu (lunar)
#        framebuffer-vncserver a été compilé depuis le dossier tools/
#
#
source "./funct.sh"

if [ ! -f "/opt/fog/.fogsettings" ]; then
	# FOG Installation not found ? ; abort NOW!
	throw_error 1 "FOG installation not found on this host." "(main) - (${LINENO})"
fi

source "/opt/fog/.fogsettings"

# ---- [URL] : Where to download FOS Filesystem ----------------
foginit_xz_url="https://github.com/FOGProject/fos/releases/latest/download/init.xz"

# ---- [APT] : Parameters of the repositories used for download DEB packages
urlRepo="http://cz.archive.ubuntu.com/ubuntu"
distroName="lunar"
depotName="main universe"

cpio_release_filename='fog_uefi.cpio.xz'


foginit_xz="$(get_basedir_sources)/foginit_latest.xz"

[ -z "$foginit_xz" ] && eval 'echo "foginit_xz ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$foginit_xz_url" ] && eval 'echo "foginit_xz_url ne semble pas correctement configurée, j'\''arrête là !";exit 1'

# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~ TODO ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
# Bon ben l'installateur est à refaire. Ce qui va prendre du temps.
# 1. Récupérer les ressources (FOGInit + Kernel Linux + Modules + Shim + Grub) -> Manipuler les paquets
# 2. Faire la sauce comme d'habitude.
#
#

echo ""
echo "=-=-=-=-=-=-=-=-=-=-=- FOG STUB reBUILDER - Alexandre BOTZUNG -=-=-=-=-=-=-=-=-=-=-=-=-="
echo ""

do_log "=-=-=-=-=-=-=-=-=-=-=- FOG STUB reBUILDER - Alexandre BOTZUNG -=-=-=-=-=-=-=-=-=-=-=-=-="
do_log "Starting at $(date)"

# On est jamais trop sur ! 
dots "Cleaning the temp folder"
umount -v "$(get_basedir_temp)"/* >> "$do_logfile" 2>&1
rm -rfv "$(get_basedir_temp)"/* >> "$do_logfile" 2>&1
msg_finished "Done"

dots "Cleaning the release folder"
rm -rfv "$(get_basedir_release)"/* >> "$do_logfile" 2>&1
msg_finished "Done"

dots "Cleaning the rootfs folder"
rm -rfv "$(get_basedir_rootfs)"/* >> "$do_logfile" 2>&1
msg_finished "Done"

dots "Create a marker with the creation date"
mkdir -v "$(get_basedir_project)"/build/FOG_BUILDER >> "$do_logfile" 2>&1
date > "$(get_basedir_project)"/build/FOG_BUILDER/buildtime 
msg_finished "Done"

dots "Downloading FOS latest"
wget -v -O "$foginit_xz" "$foginit_xz_url" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 1 "Unable to download FOS latest (${foginit_xz_url})." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Downloaded"

dots "Init apt Ubuntu repositories"
init_apt_repo "${urlRepo}" "${distroName}" "${depotName}"
msg_finished "Done"

dots "Downloading (+converting) linux-image-generic"
download_a_package "linux-image-generic" >> "$do_logfile" # linux-image-generic as a dependancy to linux-modules-* (+extra)
msg_finished "Downloaded"

dots "Downloading (+converting) shim-signed"
download_a_package "shim-signed" >> "$do_logfile"
msg_finished "Downloaded"

dots "Downloading (+converting) grub-efi-amd64-signed"
download_a_package "grub-efi-amd64-signed" >> "$do_logfile"
msg_finished "Downloaded"

# -------- Add HERE packages to be downloaded from Ubuntu repositories
pkgdl_keeppkg=""


dots "Downloading (+converting) dialog"
download_a_package "dialog" >> "$do_logfile"
msg_finished "Downloaded"

dots "Downloading (+converting) memtester"
download_a_package "memtester" >> "$do_logfile"
msg_finished "Downloaded"

dots "Downloading (+converting) dtach"
download_a_package "dtach" >> "$do_logfile"
msg_finished "Downloaded"

dots "Downloading (+converting) socat"
download_a_package "socat" >> "$do_logfile"
msg_finished "Downloaded"

dots "Downloading (+converting) wimtools"
download_a_package "wimtools" >> "$do_logfile"
msg_finished "Downloaded"

dots "Unpacking dialog (DEB)"
unpack_debs "dialog" >> "$do_logfile"
msg_finished "Done"

dots "Unpacking memtester (DEB)"
unpack_debs "memtester" >> "$do_logfile"
msg_finished "Done"

dots "Unpacking dtach (DEB)"
unpack_debs "dtach" >> "$do_logfile"
msg_finished "Done"

dots "Unpacking socat (DEB)"
unpack_debs "socat" >> "$do_logfile"
msg_finished "Done"

dots "Unpacking wimtools (DEB)"
unpack_debs "wimtools" >> "$do_logfile"
msg_finished "Done"
#-------------------------------------




dots "Unpacking linux-image-generic (DEB)"
unpack_debs "linux-image-generic" >> "$do_logfile"
msg_finished "Done"

dots "Unpacking shim-signed (DEB)"
unpack_debs "shim-signed" >> "$do_logfile"
msg_finished "Done"

dots "Unpacking grub-efi-amd64-signed (DEB)"
unpack_debs "grub-efi-amd64-signed" >> "$do_logfile"
msg_finished "Done"

dots "Searching linux-image-generic Kernel"
search_for_linux-image-generic "linux-image-generic"
if [ $? -ne 0 ]
then
	throw_error 2 "Unable to find Linux kernel into deb output package." "${FUNCNAME} - (${LINENO})"
fi
if [ ! -f "$PATH_LinuxKernel" ] # This is a FILE
then
	throw_error 3 "Unable to find Linux kernel file into deb output package." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Found"

dots "Searching linux-modules"
search_for_linux-modules "linux-image-generic"
if [ $? -ne 0 ]
then
	# Maybe download here linux-modules (+extra) ? 
	throw_error 4 "Unable to find Linux modules into deb output package." "${FUNCNAME} - (${LINENO})"
fi
if [ ! -d "$PATH_LinuxModules" ] # This is a FOLDER
then
	throw_error 5 "Unable to find Linux modules directory into deb output package." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Found"

dots "Searching shim-signed shimx64.efi.signed"
search_for_shimx64 "shim-signed"
if [ $? -ne 0 ]
then
	throw_error 6 "Unable to find shimX64.efi.* into deb output package." "${FUNCNAME} - (${LINENO})"
fi
if [ ! -f "$PATH_ShimX64" ] # This is a FILE
then
	throw_error 7 "Unable to find shimX64.efi.* into deb output package." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Found"

dots "Searching grub-efi-amd64-signed grubnetx64.efi"
search_for_grubnetx64 "grub-efi-amd64-signed"
if [ $? -ne 0 ]
then
	throw_error 8 "Unable to find grubnetx64.efi.* into deb output package." "${FUNCNAME} - (${LINENO})"
fi
if [ ! -f "$PATH_GrubNETX64" ] # This is a FILE
then
	throw_error 9 "Unable to find grubnetx64.efi.* into deb output package." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Found"

dots "Copying signed Linux kernel"
cp -v "$PATH_LinuxKernel" "$(get_basedir_release)/linux_kernel" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 10 "Unable to copy $PATH_LinuxKernel into release folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done (./release/linux_kernel)"

dots "Copying shimX64.efi.signed"
cp -v "$PATH_ShimX64" "$(get_basedir_release)/shimx64.efi" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 11 "Unable to copy $PATH_ShimX64 into release folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done (./release/shimx64.efi)"

dots "Copying grubnetx64.efi.signed"
cp -v "$PATH_GrubNETX64" "$(get_basedir_release)/grubx64.efi" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 12 "Unable to copy $PATH_GrubNETX64 into release folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done (./release/grubx64.efi)"

dots "Copying init.xz to temp folder"
cp -v "$foginit_xz" "$(get_basedir_temp)/foginit.xz" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 13 "Unable to copy init.xz into temp folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

dots "Uncompressing foginit.xz to 'foginit'"
xz --decompress "$(get_basedir_temp)/foginit.xz" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 14 "Unable to uncompresss foginit.xz into temp folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

dots "Mounting foginit (ext2)"
mkdir -v "$(get_basedir_temp)/init_fog" >> "$do_logfile" 2>&1
mount -v "$(get_basedir_temp)/foginit" "$(get_basedir_temp)/init_fog" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 15 "Unable to mount foginit." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

# ===== HERE, copy packages into rootfs...=================================================================

dots "Copying dialog"
#cp -rvf "$(get_basedir_temp)/dialog/out/"* "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
# !!! See line 320
rsync -avxHAX --progress "$(get_basedir_temp)/dialog/out/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 25 "Unable to copy dialog into dialog folder." "${FUNCNAME} - (${LINENO})"
fi
# PATCH : The package 'dialog' add file /bin/run-parts, wich collide with FOS filesystem (and ulimately creates a Kernel Panic)
rm "$(get_basedir_rootfs)/bin/run-parts" || throw_error 24 "Unable to cleanup /bin/run-parts from the rootfs folder." "${FUNCNAME} - (${LINENO})"
msg_finished "Done"

dots "Copying memtester"
#cp -rvf "$(get_basedir_temp)/memtester/out/"* "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
# !!! See line 320
rsync -avxHAX --progress "$(get_basedir_temp)/memtester/out/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 26 "Unable to copy memtester into rootfs folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

dots "Copying dtach"
#cp -rvf "$(get_basedir_temp)/dtach/out/"* "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
# !!! See line 320
rsync -avxHAX --progress "$(get_basedir_temp)/dtach/out/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 27 "Unable to copy dtach into rootfs folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"
dots "Copying socat"
#cp -rvf "$(get_basedir_temp)/socat/out/"* "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
# !!! See line 320
rsync -avxHAX --progress "$(get_basedir_temp)/socat/out/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 28 "Unable to copy socat into rootfs folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

dots "Copying wimtools"
#cp -rvf "$(get_basedir_temp)/wimtools/out/"* "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
# !!! See line 320
rsync -avxHAX --progress "$(get_basedir_temp)/wimtools/out/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 28 "Unable to copy wimtools into rootfs folder." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"
# ==================================================================================================================================

# PATCH : Some packages can be refering to /lib64. But /lib64 dosen't exist into the FOS Filesystem.
dots "Moving rootfs /lib64 to /lib (+cleaning)"
cp -rvd "$(get_basedir_rootfs)"/lib64/* "$(get_basedir_rootfs)/lib/" >> "$do_logfile" 2>&1
rm -rfv "$(get_basedir_rootfs)"/lib64  >> "$do_logfile" 2>&1
msg_finished "Done"

# PATCH : Some packages can be refering to /var/cache. FOS Filesystem mention it, i wipe it.
dots "Cleaning rootfs '/var/cache'"
rm -rfv "$(get_basedir_rootfs)"/var/cache  >> "$do_logfile" 2>&1
msg_finished "Done"

dots "Copying 'FOS' rootfs to ./rootfs"
# !!! DANGER !!! For an unknown reason, cp generates a segfault on Debian 12 (and the entire FS become inaccessible) : 
#[24347.189617] cp[80179]: segfault at 1d3560 ip 00007efeafa8b2f2 sp 00007fff419a9588 error 4 in libc.so.6[7efeafa7c000+155000] likely on CPU {0..NbrCPU} (core X, socket 0)
#[24347.189634] Code: 48 03 04 25 00 00 00 00 c3 66 66 2e 0f 1f 84 00 00 00 00 00 0f 1f 40 00 48 8b 05 59 cc 19 00 48 8b 0d da ca 19 00 64 48 8b 00 <48> 8b 00 48 8b 70 38 48 8d 96 00 01 00 00 64 48 89 11 48 8b 78 40
#cp -rvf "$(get_basedir_temp)"/init_fog/* "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1 
rsync -avxHAX --progress "$(get_basedir_temp)/init_fog/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 16 "Unable to copy FOS rootfs to $(get_basedir_rootfs)" "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

dots "I'm done with FOG 'FOS' rootfs 'foginit', umounting it."
umount -v "$(get_basedir_temp)/init_fog" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 17 "Unable to unmount FOS rootfs." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

dots "Cleaning old modules from 'FOS' rootfs"
rm -rfv "$(get_basedir_rootfs)"/lib/modules/* >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 18 "Unable to clean old modules." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

dots "Copying Linux modules to the new rootfs"
#cp -rv "$(get_basedir_temp)"/squash/usr/lib/modules "$basedir_rootfs/lib/modules" > /dev/null 2>&1
RootofModules=$(echo "${PATH_LinuxModules}" | xargs dirname)
#cp -rv "$RootofModules" "$(get_basedir_rootfs)"/lib/modules >> "$do_logfile" 2>&1
# !!! See line 320
rsync -avxHAX --progress "${RootofModules}/" "$(get_basedir_rootfs)"/lib/modules >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 19 "Unable to transfer new modules to rootfs." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

dots "CHMODing new modules with the right permissions"
chmod -Rv 0755 "$(get_basedir_rootfs)/lib/modules" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 20 "Unable to transfer new modules to rootfs." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"


dots "Cleaning inused modules"
# Raison : Bruits dans les logs
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/input/evbug.ko -rfv >> "$do_logfile" 2>&1
# Raison : Inutile
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/sound -rf
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/media -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/net/wireless -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/net/can -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/infiniband -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/comedi -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/bluetooth -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/gpu -rfv >> "$do_logfile" 2>&1

rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/net/ethernet/mellanox -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/net/ethernet/chelsio -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/net/ethernet/qlogic -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/net/ethernet/sfc -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/net/ethernet/cavium -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/net/ethernet/dec -rfv >> "$do_logfile" 2>&1

rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/iio -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/usb/ethernet/gadget -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/usb/ethernet/serial -rfv >> "$do_logfile" 2>&1
rm "$(get_basedir_rootfs)"/lib/modules/*/kernel/drivers/usb/ethernet/misc -rfv >> "$do_logfile" 2>&1
msg_finished "Done"

dots "Copying folder project into the new rootfs"
#cp -rfv "$(get_basedir_project)"/* "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
# !!! See line 320
rsync -avxHAX --progress "$(get_basedir_project)/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
if [ $? -ne 0 ]
then
	throw_error 21 "Unable to copying folder project into the new rootfs." "${FUNCNAME} - (${LINENO})"
fi
msg_finished "Done"

sysbasedir=$PWD
cd "$(get_basedir_rootfs)" || throw_error 22 "Unable to change directory into $(get_basedir_rootfs)" "${FUNCNAME} - (${LINENO})"
dots "CHMODing files into the rootfs"
chmod -v -R +x "$(get_basedir_rootfs)"/ >> "$do_logfile" 2>&1
msg_finished "Done"

dots "Simulate ldconfig inside rootfs"
simulateLdconfig
msg_finished "Done"

dots "Create ./dev/null special file"
mknod "$(get_basedir_rootfs)/dev/null" c 1 3 >> "$do_logfile" 2>&1
chmod -v 0666 "$(get_basedir_rootfs)/dev/null" >> "$do_logfile" 2>&1
msg_finished "Done"

dots "Convert the new rootfs into a CPIO"
ln -sv ./bin/busybox ./init >> "$do_logfile" 2>&1
msg_finished "Done"

dots "Create the CPIO archive from the rootfs folder"
echo ""
find . 2>/dev/null | cpio -o -H newc -R root:root | xz -7 -T0 -C crc32 > "$(get_basedir_temp)"/newroot.xz
cd "$sysbasedir" || throw_error 23 "Unable to change directory into ${sysbasedir}" "${FUNCNAME} - (${LINENO})"
msg_finished "Finished"

dots "Move the freshly created CPIO into release folder."
mv -v "$(get_basedir_temp)"/newroot.xz "$(get_basedir_release)/${cpio_release_filename}" >> "$do_logfile" 2>&1
msg_finished "Done (./release/${cpio_release_filename})"

dots "Creating FOS USB Boot image...."
buildUSBBoot
msg_finished "Done (./release/usbboot.img)"

dots "Move the USB Boot image into FOG client folder."
mv -v "$(get_basedir_release)/usbboot.img" "${docroot}/fog/client/usbboot.img" >> "$do_logfile" 2>&1
msg_finished "Done (${httpproto}://${ipaddress}${webroot}/client/usbboot.img)"

# Patching FOG files to allow usbboot.img to be downloaded  (./fog/client/download.php)
dots "! Patching FOG file (./fog/client/download.php)."
tempfile="$(mktemp)"
tempmanfile="$(mktemp)"
if [ ! -f "$tempfile" ]; then
	throw_error 30 "Error when creating a temp file." "${FUNCNAME} - (${LINENO})" 
fi
echo "<?php" > "$tempfile"
echo "// #################################################################" >> "$tempfile"
echo "// This file has been patched by the FOGUefi project"                 >> "$tempfile"
echo "// Alexandre BOTZUNG (alexandre.botzung@grandest.fr)"                 >> "$tempfile"
echo ""                                                                     >> "$tempfile"
echo "// This patch is nedded for downloading usbboot.img via the webpage"  >> "$tempfile"
echo "// If USB Boot is clicked, prep variable as the usbboot.img file."    >> "$tempfile"
echo 'if (isset($_REQUEST["usbbootimage"])) {'                              >> "$tempfile"
echo '    $filename = "usbboot.img";'                                       >> "$tempfile"
echo '}'                                                                    >> "$tempfile"
echo "// #################################################### END OF PATCH" >> "$tempfile"
echo "?>" >> "$tempfile"

# Copy download.php to temp
cp -v "${docroot}/fog/client/download.php" "${tempmanfile}" >> "$do_logfile" 2>&1
# Create the temp file (download.php) patched
cat "${tempfile}" "${docroot}/fog/client/download.php" > "${tempmanfile}"
# Rename download.php to download_old.php
mv -v "${docroot}/fog/client/download.php" "${docroot}/fog/client/download_old.php" >> "$do_logfile" 2>&1
# Disable execution of the old file
chmod -v 0644 "${docroot}/fog/client/download_old.php" >> "$do_logfile" 2>&1
# Move the patched file to FOG (download.php)
mv -v "${tempmanfile}" "${docroot}/fog/client/download.php" >> "$do_logfile" 2>&1
# Prep the file for execution
chmod 0755 "${docroot}/fog/client/download.php"

msg_finished "Done"

# Replacing the FOG file clientmanagementpage.class.php to include the USB boot image panel
dots "! Replacing FOG file (clientmanagementpage.class.php)."
# Rename clientmanagementpage.class.php to clientmanagementpage.class_old.php
mv -v "${docroot}/fog/lib/pages/clientmanagementpage.class.php" "${docroot}/fog/lib/pages/clientmanagementpage.class_old.php" >> "$do_logfile" 2>&1
# Disable execution of the old file
chmod -v 0644 "${docroot}/fog/lib/pages/clientmanagementpage.class_old.php" >> "$do_logfile" 2>&1
# Copy file clientmanagementpage.class.php to ./fog/lib/pages
cp -v "$(get_current_path)/fogproject_files/clientmanagementpage.class.php" "${docroot}/fog/lib/pages/clientmanagementpage.class.php" >> "$do_logfile" 2>&1
# Enable execution of the new file
chmod -v +x "${docroot}/fog/lib/pages/clientmanagementpage.class.php" >> "$do_logfile" 2>&1
msg_finished "Done"

msg_finished "ALL DONE * Exiting"
exit 0
