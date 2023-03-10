#!/bin/bash
#============================================================================
#              F O G    P R O J E C T    v 1 . 5 . 9 . x
#                    Unofficial Secure Boot Patch
#             FOGUefi (https://github.com/abotzung/foguefi)
#
# Auteur       : Alexandre BOTZUNG [alexandre.botzung@grandest.fr]
# Auteur       : The FOG Project team (https://github.com/FOGProject/fogproject)
# Version      : 20230307
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

# Oh ! Dirty !  ;
source /opt/fog/.fogsettings

basedir=$PWD

echo 'FOG GRUB uEFI (FOGUefi) patch installer'
echo ''
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
echo ' - Clonezilla (C) 2003-2023, NCHC, Taiwan <https://clonezilla.org/> (GNU/Linux signed kernel & scripts)'
echo ' - Ubuntu (C) 2023 Canonical Ltd. <https://ubuntu.com/> (shim-signed, grub-efi-arm64-signed)'
echo ' - Redo Rescue (C) 2010.2020 Zebradots Software <http://redorescue.com/> (GRUB Theme, heavily modified)'
echo ' - Mcder3 <github.com/KaOSx/midna> (icons)'
echo ' - Gnome icon pack <https://download.gnome.org/sources/gnome-icon-theme/> (icons) (c) 2002-2008 :'
echo '      Ulisse Perusin <uli.peru@gmail.com>'
echo '      Riccardo Buzzotta <raozuzu@yahoo.it>'
echo '      Josef Vybíral <cornelius@vybiral.info>'
echo '      Hylke Bons <h.bons@student.rug.nl>'
echo '      Ricardo González <rick@jinlabs.com>'
echo '      Lapo Calamandrei <calamandrei@gmail.com>'
echo '      Rodney Dawes <dobey@novell.com>'
echo '      Luca Ferretti <elle.uca@libero.it>'
echo '      Tuomas Kuosmanen <tigert@gimp.org>'
echo '      Andreas Nilsson <nisses.mail@home.se>'
echo '      Jakub Steiner <jimmac@novell.com>'
echo ' - '
echo ' - '
echo ' - '
echo ' - '


echo ''
echo 'The programs and files included with this patch are free software; the exact distribution terms for each program are described in the individual files.'
echo 'This patch comes with ABSOLUTELY NO WARRANTY, to the extent permitted by applicable law.'
echo ''
echo ''

if [[ -z "${docroot}${webroot}" ]]; then
	echo "ERROR ! No FOG installation detected on this server."
	exit 1
fi

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
	echo "=> Copying GRUB files..."
	cp -rf "$basedir"/src/tftpboot/* /tftpboot/
	chown -R fogproject:root /tftpboot
	chmod -R 0755 /tftpboot
	sleep 1

	echo "=> Copying Xserver ressources..."
	cp -rf "$basedir"/src/images/* /images/
	chown -R root:root '/images/!xserver'
	chmod -R 0755 '/images/!xserver'
	sleep 1

	echo "=> Copying FOG PHP files..."
	cp -rf "$basedir"/src/fog/* "${docroot}${webroot}"
	chown -R www-data:www-data "${docroot}${webroot}"
	chmod -R 0755 "${docroot}${webroot}/lib"
	chmod -R 0755 "${docroot}${webroot}/service"
	rm "${docroot}${webroot}/service/grub/tftp"
	ln -s /tftpboot "${docroot}${webroot}/service/grub/tftp"
	ln -s "${docroot}${webroot}/service/grub/grub.php" "${docroot}${webroot}/service/grub/grub_https.php"
	chmod +x "${docroot}${webroot}/service/grub/grub_https.php"
	sleep 1
	  
	echo "=> The installer now gonna patch FOG Stub. This can takes up to 20 minutes. Please wait..."
	cd $basedir/tools/fogbuilder
	./BuildFogUEFI.sh
	if [ $? -ne "0" ]; then
		echo "An ERROR has been detected and the installer cannot continue. Please share your console output logs with the devlopper, thank you !"
		echo "Goodbye"
		exit 1
	fi
	cp -rf ./release/* /tftpboot/

    echo "=> Configurying Apache server..."
    FOGApacheFile=$(grep -rnw '/management/other/ca.cert.der$ - ' /etc/apache2 | head -n1 | cut -f1 -d:)
    if [ -f "$FOGApacheFile" ]; then
		# mkrandom ? ^^
		TempConf="$RANDOM$RANDOM$RANDOM.apache2.conf"
		cat <<'EOF' >> /tmp/$TempConf
# -=-=-=- Add made by foguefi patch    
RewriteRule /service/grub/grub.php$ - [L]        # Nécessaire pour GRUB ne supportant pas HTTPS
RewriteRule /service/grub/tftp/.*$ - [L]        # Nécessaire pour fetch les fichiers en HTTP
# -=-=-=--=-=-=-=-=-=-
EOF
		sed "/RewriteRule \/management\/other\/ca.cert.der/r /tmp/$TempConf" "$FOGApacheFile"
		sed -i "/RewriteRule \/management\/other\/ca.cert.der/r /tmp/$TempConf" "$FOGApacheFile"
		rm /tmp/$TempConf
		service apache2 reload
    else
        echo "INFO : FOG Apache2 configuration file appears to be in HTTP mode, ignoring..."
    fi
    
	echo "==== Installation done ! ===="
	echo ''
	echo " REMEMBER to change your PXE Boot file $bootfilename to shimx64.efi in your DHCP Server (option 67)"
	echo ''
	echo ' - Have a nice day !'	
	
	cd "$basedir" || exit
else
	echo "Goodbye"
fi
