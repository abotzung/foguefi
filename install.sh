#!/bin/bash
#============================================================================
#         F O G U E F I - Free Opensource Ghost, batteries included
# An unofficial portage of GRUB and FOS for an easy useage of FOG Server on 
#                      Secure Boot enabled computers.
# 
#             FOGUefi (https://github.com/abotzung/foguefi)
#
# Author       : Alexandre BOTZUNG [alexandre.botzung@grandest.fr]
# Author       : The FOG Project team (https://github.com/FOGProject/fogproject)
# Version      : 20240808
# Licence      : http://opensource.org/licenses/gpl-3.0
#============================================================================ 
# install.sh
#   This script deploy FOGUefi on this system.
#
#   This script :
#    - Download *or* compiles a FOS Client 
#    - Deploy Linux kernel, GRUB and SHIM (latest signed) into /tftpboot
#    - Deploy GrubBootMenu php files (copied into /var/www/?/fog)
#    - If FOG works on HTTPS, reconfigure Apache2.
#============================================================================


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
echo ''
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
	cd "$basedir/tools/fosbuilder" || exit
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


	echo "=> Copy GRUB files..."
	cp -rf "$basedir"/src/tftpboot/* /tftpboot/
	chown -R fogproject:root /tftpboot
	chmod -R 0755 /tftpboot
	# DEBUGME DEBUGME - Switched to no delay for dev purposes
	#sleep 1

	echo "=> Copy FOG PHP files..."
	cp -rf "$basedir"/src/fog/* "${docroot}${webroot}"
	chown -R www-data:www-data "${docroot}${webroot}"
	chmod -R 0755 "${docroot}${webroot}/lib"
	chmod -R 0755 "${docroot}${webroot}/service"
	[[ -L "${docroot}${webroot}/service/grub/tftp" && -d "${docroot}${webroot}/service/grub/tftp" ]] && rm "${docroot}${webroot}/service/grub/tftp"
	[[ -r "${docroot}${webroot}/service/grub/grub_https.php" ]] && rm "${docroot}${webroot}/service/grub/grub_https.php"
	ln -s /tftpboot "${docroot}${webroot}/service/grub/tftp"
	ln -s "${docroot}${webroot}/service/grub/grub.php" "${docroot}${webroot}/service/grub/grub_https.php"
	chmod +x "${docroot}${webroot}/service/grub/grub_https.php"
	# DEBUGME DEBUGME - Switched to no delay for dev purposes
	#sleep 1

    echo "=> Configure Apache server..."
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
	echo -e " REMEMBER to change your PXE Boot file to \033[30;42m shimx64.efi \033[0m in your DHCP Server to use FOGUefi. (option 67)"
	echo ''
	echo ' - Have a nice day !'	
	
	cd "$basedir" || exit
else
	echo "Goodbye"
fi
