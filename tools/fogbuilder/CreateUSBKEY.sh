#!/bin/bash



# Oh ! Dirty !  ;
source /opt/fog/.fogsettings
if [[ -z "${docroot}${webroot}" ]]; then
	echo "ERROR ! No FOG installation detected on this server."
	exit 1
fi

mkfs.vfat --help > /dev/null 2>&1
if [ $? -ne "0" ]; then
	echo "ERROR ! This patch requires dosfstools to be installed. (apt install dosfstools)"
	exit 1
fi

echo "ALPHA SCRIPT !!! USE WITH CARE !!! ctrl+c to ABORT (10 sec pause)"
sleep 10

# Extract initversion from the rootfs folder
initversion=$(grep "export initversion" ./rootfs/usr/share/fog/lib/funcs.sh | cut -d'=' -f2)

if [ -z "$initversion" ]; then initversion="Unknown"; fi

rm ./temp/usbboot.bin
umount /tmp/usb
rm -rf /tmp/usb
mkdir /tmp/usb

dd if=/dev/zero of=./temp/usbboot.bin bs=1M count=256
mkfs.vfat -F 32 -n FOGBOOT ./temp/usbboot.bin

# Monte-là
mkdir /tmp/usb
mount ./temp/usbboot.bin /tmp/usb

# Prepare les dossiers
mkdir -p /tmp/usb/EFI/boot
mkdir -p /tmp/usb/boot/grub
#mkdir /tmp/usb/grub


# Copie les fichiers d'amorçage
PWD="/opt/foguefi/tools/fogbuilder/temp"
cp ./temp/shim-signed/out/usr/lib/shim/shimx64.efi.signed.latest /tmp/usb/EFI/boot/bootx64.efi
cp ./temp/grub-efi-amd64-signed/out/usr/lib/grub/x86_64-efi-signed/grubnetx64.efi.signed /tmp/usb/EFI/boot/grubx64.efi
cp -rv /tftpboot/grub /tmp/usb/boot/
cp -rv /tftpboot/grub /tmp/usb/
cp -v /tftpboot/linux_kernel /tmp/usb
cp -v /tftpboot/fog_uefi.cpio.xz /tmp/usb
MonFichier=$(mktemp)
echo '# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'  > "$MonFichier"
echo '# This file has been modified by CreateUSBKEY.sh'                                >> "$MonFichier"
echo 'clear'                                                                           >> "$MonFichier"
echo "set FOG_serverIP=\"${ipaddress}\""                                               >> "$MonFichier"
echo "set FOG_httpproto=\"${httpproto}\""                                              >> "$MonFichier"
echo '# GRUB_Fastboot=1 -> Light menu / GRUB_Fastboot=0 -> FOG Server menu'            >> "$MonFichier"
echo '# (NOTE : The FOG Server menu is a bit slower, but loose the dynamic menu)'      >> "$MonFichier"
echo 'set GRUB_Fastboot=0'                                                             >> "$MonFichier"
echo 'echo ""'                                                                         >> "$MonFichier"
echo 'echo "   =================================="'                                    >> "$MonFichier"
echo 'echo "   ===        ====    =====      ===="'                                    >> "$MonFichier"
echo 'echo "   ===  =========  ==  ===   ==   ==="'                                    >> "$MonFichier"
echo 'echo "   ===  ========  ====  ==  ====  ==="'                                    >> "$MonFichier"
echo 'echo "   ===  ========  ====  ==  ========="'                                    >> "$MonFichier"
echo 'echo "   ===      ====  ====  ==  ========="'                                    >> "$MonFichier"
echo 'echo "   ===  ========  ====  ==  ===   ==="'                                    >> "$MonFichier"
echo 'echo "   ===  ========  ====  ==  ====  ==="'                                    >> "$MonFichier"
echo 'echo "   ===  =========  ==  ===   ==   ==="'                                    >> "$MonFichier"
echo 'echo "   ===  ==========    =====      ===="'                                    >> "$MonFichier"
echo 'echo "   =================================="'                                    >> "$MonFichier"
echo 'echo "   ===== Free Opensource Ghost ======"'                                    >> "$MonFichier"
echo 'echo "   =================================="'                                    >> "$MonFichier"
echo 'echo "   ============ Credits ============="'                                    >> "$MonFichier"
echo 'echo "   = https://fogproject.org/Credits ="'                                    >> "$MonFichier"
echo 'echo "   =================================="'                                    >> "$MonFichier"
echo 'echo "   == Released under GPL Version 3 =="'                                    >> "$MonFichier"
echo 'echo "   =================================="'                                    >> "$MonFichier"
echo "echo '   Init Version: $initversion'"                                            >> "$MonFichier"
echo 'echo ""'                                                                         >> "$MonFichier"
echo 'echo " * [GRUB] - DHCP Request, please wait..."'                                 >> "$MonFichier"
echo 'net_dhcp'                                                                        >> "$MonFichier"
echo 'if [ -n "$net_efinet0_dhcp_mac" ]; then set mac="${net_efinet0_dhcp_mac}"; fi'   >> "$MonFichier" 
echo '# No MAC Addr ? -> Recovery MODE!'                                               >> "$MonFichier"
echo 'if [ -z "$net_efinet0_dhcp_mac" ]; then set GRUB_Fastboot=1; fi'                 >> "$MonFichier"
echo '# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~' >> "$MonFichier"
cat "${MonFichier}" /tmp/usb/grub/grub.cfg > /tmp/usb/grub/grub_PATCHED.cfg
mv /tmp/usb/grub/grub.cfg /tmp/usb/grub/grub.cfg_ORIGINAL
mv /tmp/usb/grub/grub_PATCHED.cfg /tmp/usb/grub/grub.cfg
rm "$MonFichier"

#cp grub.cfg /tmp/usb/grub
df -m /tmp/usb

umount /tmp/usb
