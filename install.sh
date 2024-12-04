#!/bin/bash
C_FOGUEFI_VERSION='20241204'
C_FOGUEFI_APIVERSION='20240806'
#============================================================================
#         F O G U E F I - Free Opensource Ghost, batteries included
# An unofficial portage of GRUB and FOS for an easy useage of FOG Server on
#                      Secure Boot enabled computers.
#
#             FOGUefi (https://github.com/abotzung/foguefi)
#
# Author       : Alexandre BOTZUNG [alexandre.botzung@grandest.fr]
# Author       : The FOG Project team (https://github.com/FOGProject/fogproject)
# Version      : (see $C_FOGUEFI_VERSION)
# Licence      : GPL-3 (http://opensource.org/licenses/gpl-3.0)
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
#
#---help---
# This script :
#    - Download *or* make a FOGUefi Client
#    - Deploy Linux kernel, GRUB and SHIM into /tftpboot
#      NOTE : Theses files are signed and provided by Canonical (C) in a binary form.
#    - Deploy GRUB php files (copied into /var/www/?/fog)
#    - Deploy GRUB menu files (copied into /tftpboot/grub)
#    - Deploy FOGUefi files (copied into /tftpboot)
#    - If FOG Server works on HTTPS, reconfigure Apache2 to allow web/grub.php to work on HTTP mode.
#
# Usage :
#   ./install.sh
#
# Options :
#	-a				Skip Apache2 configuration
#
#	-b				Build files from the latest sources, rather than downloading it from Github
#
#	-f				Force (re)installation of FOGUefi
#
#	-h				Show this help
#
#	-n				No internet flag ; This forces the installer to NOT use internet. (useful for air-gapped networks)
#					NOTE : You need to download theses files into the root directory of this script :
#					https://github.com/abotzung/FOGUefi/releases/latest/download/fog_uefi.cpio.xz
#					https://github.com/abotzung/FOGUefi/releases/latest/download/fog_uefi.cpio.xz.sha256
#					https://github.com/abotzung/FOGUefi/releases/latest/download/grubx64.efi
#					https://github.com/abotzung/FOGUefi/releases/latest/download/grubx64.efi.sha256
#					https://github.com/abotzung/FOGUefi/releases/latest/download/linux_kernel
#					https://github.com/abotzung/FOGUefi/releases/latest/download/linux_kernel.sha256
#					https://github.com/abotzung/FOGUefi/releases/latest/download/release
#					https://github.com/abotzung/FOGUefi/releases/latest/download/shimx64.efi
#					https://github.com/abotzung/FOGUefi/releases/latest/download/shimx64.efi.sha256
#
#	-u				Unattended installation.
#
#This program comes with ABSOLUTELY NO WARRANTY; for details type `show w'.
#This is free software, and you are welcome to redistribute it
#under certain conditions; type `show c' for details.
#
#---help---
#

usage() {
	echo " install.sh - 2024 Alexandre BOTZUNG <alexandre@botzung.fr>"
	echo ''
	echo " This script install FOGUefi on this system. (version : $C_FOGUEFI_VERSION)"
	echo ''
	sed -En '/^#---help---/,/^#---help---/p' "$0" | sed -E 's/^# ?//; 1d;$d;'
}

if [[ "$1" != "--unattended-yes" ]]; then
	while getopts 'bfhnua' OPTION; do
		case "$OPTION" in
			b) _rebuildFOGUEFI=1;;
			f) _forceINSTALL=1;;
			u) _unattendedINSTALL=1;;
			n) _noINTERNET=1;;
			a) _skipAPACHECNFG=1;;
			h) usage; exit 0;;
			*) usage; exit 0;;
		esac
	done
else
	_rebuildFOGUEFI=0
	_forceINSTALL=1
	_unattendedINSTALL=1
fi

: "${_skipAPACHECNFG:=0}"
: "${_rebuildFOGUEFI:=0}"
: "${_forceINSTALL:=0}"
: "${_noINTERNET:=0}"
: "${_unattendedINSTALL:=0}"
ipaddress='' # else ShellCheck freaksout


# Oh ! Dirty !  ;
[[ -r "/opt/fog/.fogsettings" ]] && source /opt/fog/.fogsettings

basedir="$(realpath "$PWD")"
if [ "$basedir" == '/' ]; then
	echo "FATAL : current directory is / !"
	exit 1
fi


echo ' *** FOGUefi installer ***'
echo ''
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
echo ''
if [[ ! -r "/opt/fog/.fogsettings" ]]; then
	echo "ERROR ! No FOG Server installation detected on this server."
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
if [ "$EUID" -ne 0 ]; then 
	echo "FATAL : This installer must be run as root."
	exit 1
fi

#_noINTERNET = 1 ? => OFFLINE Installation
#_noINTERNET = 0 ? 
#	_rebuildFOGUEFI = 1 ? => FOS-alpine-builder.sh
#	_rebuildFOGUEFI = 0 ? => Download from Github
#	

_mode=''
if [[ "$_noINTERNET" -eq 1 ]]; then
	_mode="offline installation"
else
	if [[ "$_rebuildFOGUEFI" -eq 1 ]]; then
		_mode="rebuild FOGUefi"
	else
		_mode="download from Github"
	fi
fi
[[ "$_skipAPACHECNFG" -eq 1 ]] && _mode="$_mode (Skipping Apache configuration)"

if [[ "$_noINTERNET" -eq 1 ]] && [[ "$_rebuildFOGUEFI" -eq 1 ]]; then
	echo "FATAL : FOGUefi cannot be rebuild without an internet access"
	exit 1
fi

echo "   Installer version : $C_FOGUEFI_VERSION (mode: $_mode)"
echo ''
echo "   This installer runs on server '${hostname}/${ipaddress}'"
echo "   FOG Path : ${docroot}${webroot}"
echo ''
echo '   This installer extends the FOG PXE by installing shim, grub, GNU/Linux signed and a custom FOG "FOS" stub'
echo '    allowing FOGUefi to be booted on a computer with Secure Boot enabled. (FOGUefi is a flavor of FOG "FOS")'
echo ''
echo '   It consists of 2 parts : '
echo '   - Files required for PXE (shim/GRUB/Linux kernel, all signed by Canonical), and FOG Stub patched ("FOGUefi")'
echo '   - PHP Files for handling newer menus for GRUB'
echo ''
echo ' This installer are free software; the exact distribution terms for each program are described in the individual files.'
echo ' This installer comes with ABSOLUTELY NO WARRANTY, to the extent permitted by applicable law.'
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
if [[ "$_unattendedINSTALL" -eq 1 ]]; then
	question='y'
else
	read -n1 -p "Do you want to install FOGUefi (y/N) ? :" question
fi
echo ''
if [[ "$question" == "y" || "$question" == "Y" ]]; then
	# ----------- FOGUEFI INSTALLATION BLOCK --------------------
	if [[ "$_noINTERNET" -eq 1 ]]; then
		# => OFFLINE Installation
		_githubURL='https://github.com/abotzung/FOGUefi/releases/latest/download/'
		FOGUEFI_files=('fog_uefi.cpio.xz' 'grubx64.efi' 'linux_kernel' 'shimx64.efi')

		# NOTE : "${basedir}/release" is a FILE
		if [[ ! -r "${basedir}/release" ]]; then
			echo "FATAL : The file ${basedir}/release is missing"
			echo "You must download all missing files into the root of this script (${basedir})."
			exit 1
		fi

		builddate="$(cat "${basedir}"/release | grep 'builddate=' | cut -d'=' -f2|sed 's|[^0-9]||g')"
		clientAPIversion="$(cat "${basedir}"/release | grep 'clientAPIversion=' | cut -d'=' -f2|sed 's|[^0-9]||g')"

		echo "The current OFFLINE FOGUefi version is $builddate (Client API version : $clientAPIversion)"

		if [[ "$C_FOGUEFI_APIVERSION" != "$clientAPIversion" ]]; then
			echo "FATAL : The API version of this installer is incompatible with this release of FOGUefi."
			echo " You must update your installer with theses commands : "
			echo " git clean -fd"
			echo " git reset --hard"
			echo " git pull"
			echo ""
			echo "(FATAL_API_MISMATCH : Installer API version=$C_FOGUEFI_APIVERSION / FOGUefi version=$clientAPIversion)"
			echo ""
			exit 1
		fi

		for _dlfiles in "${FOGUEFI_files[@]}"
		do
			_LeSHA256="$(cat "${basedir}/${_dlfiles}.sha256")"
			echo "$_LeSHA256 ${basedir}/${_dlfiles}" | sha256sum --check --status
			if [[ $? != 0 ]]; then
				echo "FATAL : SHA256 verification failed for file ${basedir}/${_dlfiles}"
				echo "You must redownload all corrupted files into the root of this script (${basedir})."
				exit 1;
			fi
		done
		for _dlfiles in "${FOGUEFI_files[@]}"
		do
			cp -f "${basedir}/${_dlfiles}" "/tftpboot/${_dlfiles}"
			cp -f "${basedir}/${_dlfiles}.sha256" "/tftpboot/${_dlfiles}.sha256"
		done
		cp -f "${basedir}/release" "/tftpboot/foguefi_release"
	else
		if [[ "$_rebuildFOGUEFI" -eq 1 ]]; then
			# => FOG-rebuild.sh
			# ========== Rebuild and patch FOG Stub "FOS" ==========
			# Rebuild now, because if the patching failed, the installer stop early and dosent leave nasty traces into the system
			echo "=> The installer now gonna rebuild FOGUefi. This can takes up to 20 minutes. Please wait..."
			cd "$basedir/tools/fosbuilder" || exit

			./FOS-alpine-builder.sh

			if [ $? -ne "0" ]; then
				echo "An ERROR has been detected and the installer cannot continue."
				echo " Please share the log in ./tools/fosbuilder/installer.log, your console output logs with the developper, thank you !"
				exit 1
			fi
			chmod -R +r ./release/release
			chmod -R +x ./release/release
			cp ./release/release ./release/foguefi_release
			cp -rf ./release/* /tftpboot/
			cd "$basedir" || exit
		else
			# => Download from Github (default)
			echo "=> The installer now gonna install FOGUefi (from the latest Github release). Please wait..."
			_githubURL='https://github.com/abotzung/FOGUefi/releases/latest/download/'
			FOGUEFI_files=('fog_uefi.cpio.xz' 'grubx64.efi' 'linux_kernel' 'shimx64.efi')

			echo "Clean old downloaded files..."
			[[ -r "${basedir}/release" ]] && rm "${basedir}/release"
			for _dlfiles in "${FOGUEFI_files[@]}"
			do
				[[ -r "${basedir}/${_dlfiles}" ]] && rm "${basedir}/${_dlfiles}"
				[[ -r "${basedir}/${_dlfiles}.sha256" ]] && rm "${basedir}/${_dlfiles}.sha256"
			done

			echo "Download the release manifest..."

			curl --silent -o ${basedir}/release -kOL ${_githubURL}release >>/dev/null 2>&1
			# NOTE : "${basedir}/release" is a FILE
			if [[ ! -r "${basedir}/release" ]]; then
				echo "FATAL : Could not download file ${_githubURL}release properly"
				echo "Check your internet connection and retry."
				exit 1
			fi

			builddate="$(cat "${basedir}"/release | grep 'builddate=' | cut -d'=' -f2|sed 's|[^0-9]||g')"
			clientAPIversion="$(cat "${basedir}"/release | grep 'clientAPIversion=' | cut -d'=' -f2|sed 's|[^0-9]||g')"

			echo "The current FOGUefi version is $builddate (Client API version : $clientAPIversion)"
			if [[ "$C_FOGUEFI_APIVERSION" != "$clientAPIversion" ]]; then
				echo "FATAL : The API version of this installer is incompatible with this release of FOGUefi."
				echo " You must update your installer with theses commands : "
				echo " git clean -fd"
				echo " git reset --hard"
				echo " git pull"
				echo ""
				echo "(FATAL_API_MISMATCH : Installer API version=$C_FOGUEFI_APIVERSION / FOGUefi version=$clientAPIversion)"
				echo ""
				exit 1
			fi

			echo "=> Download files, please wait..."
			for _dlfiles in "${FOGUEFI_files[@]}"
			do
				#echo "Download ${basedir}/${_dlfiles}.sha256"
				curl --silent -o "${basedir}/${_dlfiles}.sha256" -kOL "${_githubURL}${_dlfiles}.sha256" >>/dev/null 2>&1
				#echo "Download ${basedir}/${_dlfiles}"
				curl --silent -o "${basedir}/${_dlfiles}" -kOL "${_githubURL}${_dlfiles}" >>/dev/null 2>&1

				_LeSHA256=$(cat "${basedir}/${_dlfiles}.sha256")
				#echo " LE SUUUM:$_LeSHA256 (for ${basedir}/${_dlfiles}.sha256)"
				echo "$_LeSHA256 ${basedir}/${_dlfiles}" | sha256sum --check --status
				if [[ $? != 0 ]]; then
					echo "FATAL : SHA256 verification failed for file ${basedir}/${_dlfiles}"
					echo "Check your internet connection and retry."
					exit 1;
				fi
			done
			for _dlfiles in "${FOGUEFI_files[@]}"
			do
				cp -f "${basedir}/${_dlfiles}" "/tftpboot/${_dlfiles}"
				cp -f "${basedir}/${_dlfiles}.sha256" "/tftpboot/${_dlfiles}.sha256"
			done
			cp -f "${basedir}/release" "/tftpboot/foguefi_release"
		fi
	fi

	#  --------------- END OF INSTALLATION BLOCK
	#
	#  HERE, put the Apache installation block

	# Workaround - shim in certain case, with certain specific computers will load a bad second loader : https://github.com/rhboot/shim/issues/649
	if [[ -r "/tftpboot/grubx64.efi" ]]; then
		for val in {128..254}
			do
				dec2hex="$(printf %x "$val")"
				ln "/tftpboot/grubx64.efi" "/tftpboot/$(printf "\x$dec2hex")Onboard"
			done
	else
		echo '/tftpboot/grubx64.efi does not exist, workaround for shim ignored'
	fi
	
	echo "=> Copy GRUB files..."
	cp -rf "$basedir"/src/tftpboot/* /tftpboot/
	[[ ! -r "/tftpboot/grub/custom.cfg" ]] && cp "/tftpboot/grub/custom.cfg.example" "/tftpboot/grub/custom.cfg"
	chown -R fogproject:root /tftpboot
	chmod -R 0755 /tftpboot

    echo "=> Create '@apk' to /images + settings permissions..."
    [[ ! -d "/images/@apk" ]] && mkdir "/images/@apk"
	# NOTE : @apk MUST BELONG to root
	chown -R root:root "/images/@apk"
	chmod -R 0755 "/images/@apk"

	echo "=> Copy FOGUefi PHP files..."
	cp -rf "$basedir"/src/fog/* "${docroot}${webroot}"
	chown -R www-data:www-data "${docroot}${webroot}"
	chmod -R 0755 "${docroot}${webroot}/lib"
	chmod -R 0755 "${docroot}${webroot}/service"
	[[ -L "${docroot}${webroot}/service/grub/tftp" && -d "${docroot}${webroot}/service/grub/tftp" ]] && rm "${docroot}${webroot}/service/grub/tftp"
	[[ -r "${docroot}${webroot}/service/grub/grub_https.php" ]] && rm "${docroot}${webroot}/service/grub/grub_https.php"
	ln -s /tftpboot "${docroot}${webroot}/service/grub/tftp"
	ln -s "${docroot}${webroot}/service/grub/grub.php" "${docroot}${webroot}/service/grub/grub_https.php"
	chmod +x "${docroot}${webroot}/service/grub/grub_https.php"

	if [[ "$_skipAPACHECNFG" -eq 0 ]]; then
		echo "=> Configure Apache server..."
		# Configurying the Apache server is required by GRUB (in the case of using HTTPS on the front server).
		#   This is a workaround to provide a valid configuration for GRUB, even if the webserver uses https.
		# If not supported or ignored, GRUB cannot work.
		#
		#FOGApacheFile=$(grep -rnw '/management/other/ca.cert.der$ - ' /etc/apache2 | head -n1 | cut -f1 -d:)
		FOGApacheFile=$(find /etc/apache2/sites-enabled/ -type l -exec readlink -f {} \; | xargs grep -l '/management/other/ca.cert.der$ - ' | head -n1 | cut -f1 -d:)
		[ -z "$FOGApacheFile" ] && FOGApacheFile="."
		grep 'Add made by foguefi patch' "$FOGApacheFile" > /dev/null 2>&1
		FOGApachefileAlreadyPatched_FLAG=$?

		if [ -f "$FOGApacheFile" ]; then
			if [ "$FOGApachefileAlreadyPatched_FLAG" -ne 0 ]; then
				cp -f "$FOGApacheFile" "${FOGApacheFile}.bak_foguefi"
				# mkrandom ? ^^
				TempConf=$(mktemp)
				cat <<'EOF' >> "${TempConf}"
# -=-=-=- Add made by FOGUefi patch
RewriteRule /service/grub/grub.php$ - [L]        # Needed for GRUB (unable to fetch ressources HTTPS mode)
RewriteRule /service/grub/tftp/.*$ - [L]        # Needed for GRUB
# -=-=-=--=-=-=-=-=-=-
EOF
				sed -i "/RewriteRule \/management\/other\/ca.cert.der/r ${TempConf}" "$FOGApacheFile"
				rm "${TempConf}"
				service apache2 reload
			else
				echo "INFO : FOG Apache2 configuration file appears to be already patched."
			fi
		else
			echo "INFO : FOG Apache2 configuration file appears to be in HTTP mode."
		fi
	else
		echo "=> Skip Apache server configuration..."
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
