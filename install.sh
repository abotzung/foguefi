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
# Version      : 20240811
# Licence      : http://opensource.org/licenses/gpl-3.0
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
#
#============================================================================ 
# install.sh
#   This script deploy FOGUefi on this system.
#
#   This script :
#    - Download *or* compiles a FOS Client 
#    - Deploy Linux kernel, GRUB and SHIM (latest signed) into /tftpboot (provided by Canonical)
#    - Deploy GrubBootMenu php files (copied into /var/www/?/fog)
#    - If FOG works on HTTPS, reconfigure Apache2.
#============================================================================

C_FOGUEFI_VERSION='20240812'

# Oh ! Dirty !  ;
source /opt/fog/.fogsettings

basedir="$PWD"

echo ' *** FOGUefi installer ***'
echo ''

if [[ ! -r "/opt/fog/.fogsettings" ]]; then
	echo "ERROR ! No FOG installation detected on this server."
	echo "Reason : file /opt/fog/.fogsettings not found."
	exit 1
fi
if [[ -z "${docroot}${webroot}" ]]; then
	echo "ERROR ! No FOG installation detected on this server."
	echo "Reason : \$docroot / \$webroot is NULL"
	exit 1
fi
if [[ -z "$hostname" ]]; then
	echo "ERROR ! No FOG installation detected on this server."
	echo "Reason : \$hostname is NULL"
	exit 1
fi

echo -e "\033[97;44m                                                                     \033[0m"
echo -e "\033[97;44m   ███████████████████████████████████████████████████████████████   \033[0m"
echo -e "\033[97;44m   ███        ████    █████      ███  ████  █████████████████  ███   \033[0m"
echo -e "\033[97;44m   ███  █████████  ██  ███   ██   ██  ████  █████████████████  ███   \033[0m"
echo -e "\033[97;44m   ███  ████████  ████  ██  ████  ██  ████  ███     ███    ███████   \033[0m"
echo -e "\033[97;44m   ███  ████████  ████  ██  ████████  ████  ██  ██████  █████  ███   \033[0m"
echo -e "\033[97;44m   ███      ████  ████  ██  ████████  ████  ██  ██████  █████  ███   \033[0m"
echo -e "\033[97;44m   ███  ████████  ████  ██  ███   ██  ████  ██      ██    ███  ███   \033[0m"
echo -e "\033[97;44m   ███  ████████  ████  ██  ████  ██  ████  ██  ██████  █████  ███   \033[0m"
echo -e "\033[97;44m   ███  █████████  ██  ███   ██   ██  ████  ██  ██████  █████  ███   \033[0m"
echo -e "\033[97;44m   ███  ██████████    █████      ████      ████     ██  █████  ███   \033[0m"
echo -e "\033[97;44m   ███████████████████████████████████████████████████████████████   \033[0m"
echo -e "\033[97;44m   ██████████ Free Opensource Ghost, batteries included ██████████   \033[0m"
echo -e "\033[97;44m   ███████████████████████████████████████████████████████████████   \033[0m"
echo -e "\033[97;44m   ████████████████████████== Credits == █████████████████████████   \033[0m"
echo -e "\033[97;44m   █ https://fogproject.org/Credits  https://github.com/abotzung █   \033[0m"
echo -e "\033[97;44m   ███████████████████████████████████████████████████████████████   \033[0m"
echo -e "\033[97;44m   ████████████████ Released under GPL Version 3 █████████████████   \033[0m"
echo -e "\033[97;44m   ███████████████████████████████████████████████████████████████   \033[0m"
echo -e "\033[97;44m                                                                     \033[0m"
echo "   Installer version : $C_FOGUEFI_VERSION"
echo ''
echo "   This installer runs on server '$hostname' (${ipaddress})"
echo "   FOG Path : ${docroot}${webroot}"
echo ''
echo '   This installer extends the FOG PXE by installing shim, grub, GNU/Linux signed and a custom FOG "FOS" stub'
echo '   It consists of 2 parts : '
echo '   - Files required for PXE (shim/GRUB/Linux kernel, all signed by Canonical), and FOG Stub patched ("FOGUefi")'
echo '   - PHP Files for handling newer menus for GRUB'
echo ''
echo ' This patch are free software; the exact distribution terms for each program are described in the individual files.'
echo ' This patch comes with ABSOLUTELY NO WARRANTY, to the extent permitted by applicable law.'
echo ''
echo ''

zstd -V > /dev/null 2>&1
if [ $? -ne "0" ]; then
	echo "ERROR ! FOGUefi requires zstd to be installed. (apt install zstd)"
	exit 1
fi
curl -V > /dev/null 2>&1
if [ $? -ne "0" ]; then
	echo "ERROR ! FOGUefi requires curl to be installed. (apt install curl)"
	exit 1
fi


echo ''
if [[ "$1" == "--unattended-yes" ]]; then
	question='y'
	echo ' --> UNATTENDED, STARTING IN 5 Sec. <--'
	sleep 5
else
	read -n1 -p "Do you want to install FOGUefi (y/N) ? :" question
fi
echo ''
if [[ "$question" == "y" || "$question" == "Y" ]]; then
	# ========== Rebuild and patch FOG Stub "FOS" ==========
	# Rebuild now, because if the patching failed, the installer stop early and dosent leave nasty traces into the system
	echo "=> The installer now gonna patch FOG Stub. This can takes up to 20 minutes. Please wait..."
	cd "$basedir/tools/fosbuilder" || exit

	./FOS-alpine-builder.sh

	if [ $? -ne "0" ]; then
		echo "An ERROR has been detected and the installer cannot continue. Please share your console output logs with the devlopper, thank you !"
		exit 1
	fi

	cp -rf ./release/* /tftpboot/
	cd "$basedir" || exit


	echo "=> Copy GRUB files..."
	cp -rf "$basedir"/src/tftpboot/* /tftpboot/
	chown -R fogproject:root /tftpboot
	chmod -R 0755 /tftpboot

    echo "=> Create '@apk' to /images + settings permissions..."
    [[ ! -d "${docroot}${webroot}/service/grub/tftp" ]] && mkdir "/images/@apk"
	# NOTE : @apk MUST BELONG to root
	chown -R root:root "/images/@apk"
	chmod -R 0755 "/images/@apk"

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

    echo "=> Configure Apache server..."
    FOGApacheFile=$(grep -rnw '/management/other/ca.cert.der$ - ' /etc/apache2 | head -n1 | cut -f1 -d:)
    FOGApachefileAlreadyPatched=$(grep -rnw 'Add made by foguefi patch' /etc/apache2 | head -n1 | cut -f1 -d:)
    if [ -f "$FOGApacheFile" ]; then
		if [ ! -f "$FOGApachefileAlreadyPatched" ]; then
			# mkrandom ? ^^
			TempConf=$(mktemp)
			cat <<'EOF' >> "${TempConf}"
# -=-=-=- Add made by foguefi patch    
RewriteRule /service/grub/grub.php$ - [L]        # Needed for GRUB (unable to fetch ressources HTTPS mode)
RewriteRule /service/grub/tftp/.*$ - [L]        # Needed for GRUB
# -=-=-=--=-=-=-=-=-=-
EOF
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
	echo -e " You must change your PXE Boot file to \033[30;42m shimx64.efi \033[0m in your DHCP Server to use FOGUefi. (option 67)"
	echo ''	
	cd "$basedir" || exit
else
	echo "Goodbye"
fi
