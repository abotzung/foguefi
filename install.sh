#!/bin/bash
#============================================================================
#              F O G    P R O J E C T    v 1 . 5 . x
#                    Unofficial Secure Boot Patch
#             FOGUefi (https://github.com/abotzung/foguefi)
#
# Auteur       : Alexandre BOTZUNG [alexandre.botzung@grandest.fr]
# Auteur       : The FOG Project team (https://github.com/FOGProject/fogproject)
# Version      : 20240321
# Licence      : http://opensource.org/licenses/gpl-3.0
#============================================================================ 
# install.sh
#   Ce script déploie le patch foguefi sur le système.
#
#   Celui-ci est composée en 3 parties : 
#    - GRUB et SHIM (déployés dans /tftpboot) 
#    - Divers fichiers php (déployés dans /var/www/?/fog)
#    - Le chroot bureau graphique (déployé dans /images) (absent dans cette version)
#============================================================================

# TODO FIXME : The english language used in this installer (BuilfFogUefi included) is
#    at best approximate. A complete cleaning is in order!
#
# TODO (FOG Version : https://raw.githubusercontent.com/FOGProject/fogproject/master/packages/web/lib/fog/system.class.php )
#

# Oh ! Dirty !  ;
source /opt/fog/.fogsettings

basedir=$PWD

# A little bit of color (useful for separating command messages / installer message)
RED="\e[31m"
GREEN="\e[32m"
BLUE="\e[34m"
MAGENTA="\e[35m"
YELLOW="\e[33m"
ENDCOLOR="\e[0m"

echo 'FOG GRUB uEFI (FOGUefi) patch installer'
echo ''

if [[ -z "${docroot}${webroot}" ]]; then
	echo "ERROR ! No FOG installation detected on this server."
	exit 1
fi

echo "Installer runs on server $hostname (${ipaddress})"
echo ''
echo ' > This patch extends the FOG PXE boot possibility to Secure Boot enabled computers via GRUB and SHIM.'
echo '   It consists of 3 parts : '
echo '   - Files required for PXE (shim/GRUB), and FOG Stub patched'
echo '   - PHP Files for handling newer menus for GRUB'
echo '   - An optionnal tool : X Server for FOG Stub, allowing to surfing/remote desktop while FOG is working'
echo ''
echo ' This patch contains files from :'
echo ' - The FOG Project <https://fogproject.org/> (init.xz & scripts & logos)'
echo ' - Clonezilla (C) 2003-2023, NCHC, Taiwan <https://clonezilla.org/> (scripts)'
echo ' - Ubuntu (C) 2023 Canonical Ltd. <https://ubuntu.com/> (GNU/Linux signed kernel, shim-signed, grub-efi-arm64-signed)'
echo ' - The Alpine Linux Development team <https://www.alpinelinux.org/> (base env)'
echo ' - Redo Rescue (C) 2010.2020 Zebradots Software <http://redorescue.com/> (GRUB Theme, heavily modified)'
echo ' - Mcder3 <github.com/KaOSx/midna> (icons)'
echo ' - Gnome icon pack <https://download.gnome.org/sources/gnome-icon-theme/> (icons) (c) 2002-2008 :'
echo '  '
echo ''
echo 'This patch are free software; the exact distribution terms for each program are described in the individual files.'
echo 'This patch comes with ABSOLUTELY NO WARRANTY, to the extent permitted by applicable law.'
echo ''
echo ''

zstd -V > /dev/null 2>&1
if [ $? -ne "0" ]; then
	echo "ERROR ! This patch requires zstd to be installed. (apt install zstd)"
	exit 1
fi

echo "Welcome to the installer ! (FOG path : ${docroot}${webroot})"
echo 'This patch comes with ABSOLUTELY NO WARRANTY'
echo ''
if [[ "$1" == "--unattended-yes" ]]; then
	question='y'
	echo ' --> UNATTENDED, STARTING IN 5 Sec. <--'
	sleep 5
else
	read -n1 -p "Do you wish to install this patch (y/N) ? :" question
fi
echo ''
if [[ "$question" == "y" || "$question" == "Y" ]]; then
	# ========== Rebuild and patch FOG Stub "FOS" ==========
	# Rebuild now, because if the patching failed, the installer stop early and dosent leave nasty traces into the system
	echo "=> The installer now gonna patch FOG Stub. This can takes up to 20 minutes. Please wait..."
	cd $basedir/tools/fosbuilder
	#./BuildFogUEFI.sh
	./FOS-alpine-builder.sh
	if [ $? -ne "0" ]; then
		echo "An ERROR has been detected and the installer cannot continue. Please share your console output logs with the devlopper, thank you !"
		echo "Goodbye"
		exit 1
	fi
	# TODO ; Implement a methodology for uninstalling the patch
	cp -rf ./release/* /tftpboot/
	cd "$basedir" || exit


	echo "=> Copying GRUB files..."
	cp -rf "$basedir"/src/tftpboot/* /tftpboot/
	chown -R fogproject:root /tftpboot
	chmod -R 0755 /tftpboot
	# DEBUGME DEBUGME - Switched to no delay for dev purposes
	#sleep 1

	# xserver n'est pas super pertinent pour le moment
	#echo "=> Copying Xserver ressources..."
	#cp -rf "$basedir"/src/images/* /images/
	#chown -R root:root '/images/!xserver'
	#chmod -R 0755 '/images/!xserver'
	# DEBUGME DEBUGME - Switched to no delay for dev purposes
	#sleep 1

	echo "=> Copying FOG PHP files..."
	cp -rf "$basedir"/src/fog/* "${docroot}${webroot}"
	chown -R www-data:www-data "${docroot}${webroot}"
	chmod -R 0755 "${docroot}${webroot}/lib"
	chmod -R 0755 "${docroot}${webroot}/service"
	rm "${docroot}${webroot}/service/grub/tftp"
	rm "${docroot}${webroot}/service/grub/grub_https.php"
	ln -s /tftpboot "${docroot}${webroot}/service/grub/tftp"
	ln -s "${docroot}${webroot}/service/grub/grub.php" "${docroot}${webroot}/service/grub/grub_https.php"
	chmod +x "${docroot}${webroot}/service/grub/grub_https.php"
	# DEBUGME DEBUGME - Switched to no delay for dev purposes
	#sleep 1
	  
	cp -rf ./release/* /tftpboot/

    echo "=> Configurying Apache server..."
    FOGApacheFile=$(grep -rnw '/management/other/ca.cert.der$ - ' /etc/apache2 | head -n1 | cut -f1 -d:)
    FOGApachefileAlreadyPatched=$(grep -rnw 'Add made by foguefi patch' /etc/apache2 | head -n1 | cut -f1 -d:)
    if [ -f "$FOGApacheFile" ]; then
		if [ ! -f "$FOGApachefileAlreadyPatched" ]; then
			# mkrandom ? ^^
			TempConf=$(mktemp)
			cat <<'EOF' >> "${TempConf}"
# -=-=-=- Add made by foguefi patch    
RewriteRule /service/grub/grub.php$ - [L]        # Nécessaire pour GRUB ne supportant pas HTTPS
RewriteRule /service/grub/tftp/.*$ - [L]        # Nécessaire pour fetch les fichiers en HTTP
# -=-=-=--=-=-=-=-=-=-
EOF
			#sed "/RewriteRule \/management\/other\/ca.cert.der/r /tmp/$TempConf" "$FOGApacheFile"
			sed -i "/RewriteRule \/management\/other\/ca.cert.der/r ${TempConf}" "$FOGApacheFile"
			rm "${TempConf}"
			service apache2 reload
		else
			echo "INFO : FOG Apache2 configuration file appears to be already patched, ignoring..."
		fi
    else
        echo "INFO : FOG Apache2 configuration file appears to be in HTTP mode, ignoring..."
    fi
    
    # Buxfix : https://github.com/abotzung/foguefi/issues/4
    touch "${docroot}${webroot}fog_login_accepted.log"
    touch "${docroot}${webroot}fog_login_failed.log"
    chmod 0200 "${docroot}${webroot}fog_login_accepted.log"
    chmod 0200 "${docroot}${webroot}fog_login_failed.log"
    chown www-data:www-data "${docroot}${webroot}fog_login_accepted.log"
    chown www-data:www-data "${docroot}${webroot}fog_login_failed.log"
    
	echo "==== Installation done ! ===="
	echo ''
	echo " REMEMBER to change your PXE Boot file $bootfilename to shimx64.efi in your DHCP Server (option 67)"
	echo ''
	echo ' - Have a nice day !'	
	
	cd "$basedir" || exit
else
	echo "Goodbye"
fi
