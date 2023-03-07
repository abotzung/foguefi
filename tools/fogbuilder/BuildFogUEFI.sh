#!/bin/bash
#
# *** Rebuild the FOG Stub with the project/ folder
#
# @category FOGStub
# @package  FOGUefi
# @author   Alexandre Botzung <alexandre.botzung@grandest.fr>
# @license  http://opensource.org/licenses/gpl-3.0 GPLv3
# @link     https://github.com/abotzung/foguefi
#
#
# Génère le nouveau FOG Operating system "FOG Stub" à partir de Clonezilla et du dernier init.xz en date
#
# NOTE : dialog, dtach efiboot*, framebuffer-vncserver && socat sont des fichiers binaires
#        dialog, dtach efiboot* et socat proviennent de la distribution en cours (Debian 11 au moment de la création de ce dossier)
#        framebuffer-vncserver a été compilé depuis le dossier tools/
#
#
# ---vvv------------ Le répertoire racine pour FOG Builder
basedir=$PWD
# ---vvv------------ Quelques constantes. . .
basedir_sources="$basedir/sources"
basedir_temp="$basedir/temp"
basedir_rootfs="$basedir/rootfs"
basedir_project="$basedir/project"
basedir_release="$basedir/release"

[[ ! -d "$basedir_sources" ]] && mkdir "$basedir_sources"
[[ ! -d "$basedir_temp" ]] && mkdir "$basedir_temp"
[[ ! -d "$basedir_rootfs" ]] && mkdir "$basedir_rootfs"
[[ ! -d "$basedir_project" ]] && mkdir "$basedir_project"
[[ ! -d "$basedir_release" ]] && mkdir "$basedir_release"

clonezilla_iso="$basedir_sources/clonezilla_lastest.iso"
# !!! ATTENTION !!! Comme FOG à besoin d'un GRUB signée ayant le module http + smbios inclus, 
#   il est nécessaire de démarrer le système avec le GRUB signed de Ubuntu (car celui de Debian ne l'a pas).
#   Comme shim est signée par Microsoft, qui valide la signature de GRUB, qui valide la signature du kernel Linux, il est IMPERATIF d'utiliser la saveur "Ubuntu" de Clonezilla.
#   La version Debian ne fonctionne pas ; elle provoquera un "Bad shim signature" au démarrage.
#clonezilla_iso_url="https://osdn.net/frs/redir.php?f=clonezilla%2F77962%2Fclonezilla-live-20221103-kinetic-amd64.iso"
clonezilla_iso_url="https://sourceforge.net/projects/clonezilla/files/clonezilla_live_alternative/20230212-kinetic/clonezilla-live-20230212-kinetic-amd64.iso/download"


# C'est moyen cool, mais ça fera l'affaire pour quelques bidouilles...
# file ./...filesystem : ./iso/live/filesystem.squashfs: Squashfs filesystem, little endian, version 4.0, xz compressed(...)
hardcoded_clonezilla_iso_filesystem="$basedir_temp/iso/live/filesystem.squashfs"

# file ./...vmlinuz : ./iso/live/vmlinuz: Linux kernel x86 boot executable bzImage, version 5.17.0-2-amd64 (...)
hardcoded_clonezilla_iso_linuxkrnl="$basedir_temp/iso/live/vmlinuz"


foginit_xz="$basedir_sources/foginit_latest.xz"
foginit_xz_url="https://github.com/FOGProject/fos/releases/latest/download/init.xz"

flag_sourcesok="$basedir_sources/sources_ok"

[ -z "$basedir" ] && eval 'echo "Il manque variables.sh, je ne peut rien faire !";exit 1'
[ -z "$basedir_sources" ] && eval 'echo "basedir_sources ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$basedir_temp" ] && eval 'echo "basedir_temp ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$basedir_rootfs" ] && eval 'echo "basedir_rootfs ne semble pas correctement configurée, j'\''arrête là !";exit 1'

[ -z "$foginit_xz" ] && eval 'echo "foginit_xz ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$clonezilla_iso" ] && eval 'echo "clonezilla_iso ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$flag_sourcesok" ] && eval 'echo "flag_sourcesok ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$foginit_xz_url" ] && eval 'echo "foginit_xz_url ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$clonezilla_iso_url" ] && eval 'echo "clonezilla_iso_url ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$basedir_release" ] && eval 'echo "basedir_release ne semble pas correctement configurée, j'\''arrête là !";exit 1'
[ -z "$basedir_project" ] && eval 'echo "basedir_project ne semble pas correctement configurée, j'\''arrête là !";exit 1'


# TODO : chmod -R -v +x ./project/*

if [ ! -f "$clonezilla_iso" ]; then
    echo "I'm missing Clonezilla ISO ($clonezilla_iso), trying to download it . . ."
	echo "---------------------------------------------------------------"
	echo "======> I'm downloading latest Clonezilla ubuntu amd64 ISO. . . "
	echo "---------------------------------------------------------------"
	wget -O "$clonezilla_iso" "$clonezilla_iso_url"
	retval=$?
	if [ $retval -ne 0 ]; then
		echo "ERROR while downloading Clonezilla ISO:"
		echo "$clonezilla_iso_url -> $clonezilla_iso"
		echo "Réalisez le téléchargement à la main, puis réessayez."
		# Nettoie l'image dans le doute
		rm "$clonezilla_iso"
		exit 1
	fi
	if [ ! -f "$clonezilla_iso" ]; then
		# on reteste. Si il manque toujours l'iso, c'est que ça s'est Malpasset
		echo "ERROR ! Clonezilla ISO is missing ($clonezilla_iso)"
		exit 1
	fi
fi
if [ ! -f "$foginit_xz" ]; then
    echo "I'm missing STUB Fog 'FOS' ($foginit_xz), trying to download it . . ."
	echo "-------------------------------------------------------"
	echo "=========> I'm downloading latest STUB Fog 'FOS'  . . . "
	echo "-------------------------------------------------------"
	wget -O "$foginit_xz" "$foginit_xz_url"
	retval=$?
	# v v v ERREUR ICI v v v 
	if [ $retval -ne 0 ]; then
		echo "ERROR while downloading STUB Fog 'FOS' :"
		echo "$foginit_xz_url -> $foginit_xz"
		echo "Réalisez le téléchargement à la main, puis réessayez."
		# Nettoie l'image dans le doute
		rm "$foginit_xz"
		exit 1
	fi
	if [ ! -f "$foginit_xz" ]; then
		# on reteste. Si il manque toujours, c'est que ça s'est Malpasset
		echo "ERROR ! STUB Fog 'FOS' is missing ($foginit_xz)"
		exit 1
	fi
fi

echo ""
echo "=-=-=-=-=-=-=-=-=-=-=- FOG STUB reBUILDER - Alexandre BOTZUNG -=-=-=-=-=-=-=-=-=-=-=-=-="
echo ""

# On est jamais trop sur ! 
echo "-------------------------------------------------------"
echo "  ============> Cleaning the temp folder . . . "
umount "$basedir_temp"/*
rm -rf "${basedir_temp:?}"/*

echo "-------------------------------------------------------"
echo "  ============> Cleaning the release folder . . . "
rm -rf "${basedir_release:?}"/*

echo "-------------------------------------------------------"
echo "  ============> Cleaning the rootfs folder . . . "
rm -rf "${basedir_rootfs:?}"/*

echo "-------------------------------------------------------"
echo " => Create a backup of this tool  . . . "
# TODO : A Supprimer 
# Crée une photocopie de ce script vers le project afin d'avoir une copie viable de l'outil.
# Créé aussi un SHA256 de tous les fichiers du projets.
mkdir "$basedir_project"/build/FOG_BUILDER
# Vide le dossier pour avoir les sources à jour.
rm -rf "$basedir_project"/build/FOG_BUILDER/*

cp "$basedir"/BuildFogUEFI.sh "$basedir_project"/build/FOG_BUILDER
cp "$basedir"/clean_buildEnvironment.sh "$basedir_project"/build/FOG_BUILDER
cp "$basedir"/refresh_EnvironmentSources.sh "$basedir_project"/build/FOG_BUILDER
cp "$basedir"/variables.sh "$basedir_project"/build/FOG_BUILDER/variables.sh_EditME

echo '#!/bin/bash' > "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
echo '# Rebuild source folder from files inside Initrd' >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
echo '# variable source_dir is the source folder (eg : /tmp/cpio_unpacked/)' >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
echo '# variable dest_dir is the destination folder (eg : /root/source)' >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
sha256_file=$(sha256sum "$clonezilla_iso")
sha256_file_stripped=$(printf '%s\n' "${sha256_file//$basedir/}")
ls_al_file=$(ls -al "$clonezilla_iso")
ls_al_file_stripped=$(printf '%s\n' "${ls_al_file//$basedir/}")
echo "# Build with Clonezilla ISO (${clonezilla_iso_url})" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
echo "# SHA256:${sha256_file_stripped}" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
echo "# $ls_al_file_stripped" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
sha256_file=$(sha256sum "$foginit_xz")
sha256_file_stripped=$(printf '%s\n' "${sha256_file//$basedir/}")
ls_al_file=$(ls -al "$foginit_xz")
ls_al_file_stripped=$(printf '%s\n' "${ls_al_file//$basedir/}")
echo "# Build with FOG init.xz (${foginit_xz_url})" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
echo "# SHA256:${sha256_file_stripped}" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
echo "# $ls_al_file_stripped" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh

# Etape 1 ; liste les dossiers
for f in $(find "$basedir_project"); do
  if [[ -d "$f" ]]; then
	fldr=$(printf '%s\n' "${f//$basedir_project/}")
	if [[ -n "$fldr" ]]; then
		echo "mkdir \${dest_dir}$fldr" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
	fi
  fi
done

# Etape 2 ; liste les fichiers
for f in $(find "$basedir_project"); do
  if [[ ! -d "$f" ]]; then
	file=$(printf '%s\n' "${f//$basedir_project/}")
	if [[ -n "$file" ]]; then
		sha256_file=$(sha256sum "$f")
		sha256_file_stripped=$(printf '%s\n' "${sha256_file//$basedir_project/}")
		ls_al_file=$(ls -al "$f")
		ls_al_file_stripped=$(printf '%s\n' "${ls_al_file//$basedir_project/}")
		echo "# SHA256:$sha256_file_stripped" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
		echo "# LS -al:$ls_al_file_stripped" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
		echo "cp \"\${source_dir}$file\" \"\${dest_dir}$file\"" >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh
	fi
  fi
done

echo 'echo Done' >> "$basedir_project"/build/FOG_BUILDER/RebuildSourceFolderFromINITRD.sh

date > "$basedir_project"/build/FOG_BUILDER/buildtime

echo "-------------------------------------------------------"
echo "  ============> Mounting Clonezilla ISO . . ."
mkdir "$basedir_temp/iso"
mount "$clonezilla_iso" "$basedir_temp/iso"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande mount ! ! ! ! !"
	exit 1
fi

echo "----------------------------------------------------------"
echo "  ============> Copying Clonezilla's squashfs . . . "
cp "$hardcoded_clonezilla_iso_filesystem" "$basedir_temp/clonezille_filesystem.squashfs"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande cp ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  ============> Copying Clonezilla's signed Linux kernel. . . "
cp "$hardcoded_clonezilla_iso_linuxkrnl" "$basedir_release/linux_clonezilla"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande cp ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  ====> I'm done with Clonezilla ISO, umounting it . . . "
umount "$basedir_temp/iso"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande umount ! ! ! ! !"
	exit 1
fi
rm -rf "$basedir_temp/iso"

echo "-------------------------------------------------------"
echo "  ===========> Mounting Clonezilla squashfs. . . "
mkdir "$basedir_temp/squash"
mount "$basedir_temp/clonezille_filesystem.squashfs" "$basedir_temp/squash"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande mount squashfs ! ! ! ! !"
	exit 1
fi
echo "-------------------------------------------------------"
echo "  ================> Determining Linux distro type. . . "
if [ ! -f "$basedir_temp/squash/etc/lsb-release" ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR while checking if lsb-release exists ! ! ! !"
	echo " --- FILE NOT FOUND - UNABLE TO DETERMINE LiNUX DISTRO ---"
	exit 1
fi
# Try to load distro parameters...
DISTRIB_ID="" #Ubuntu
DISTRIB_RELEASE="" #22.10
DISTRIB_CODENAME="" #kinetic
#DISTRIB_DESCRIPTION="" #"Ubuntu 22.10"
source "$basedir_temp"/squash/etc/lsb-release

if [[ ! "$DISTRIB_ID" == *"Ubuntu"* ]]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR while checking file lsb-release : DISTRIB_ID unknown ! ! ! !"
	echo " --- DISTRIB_ID = $DISTRIB_ID ---"
	exit 1
fi
echo " INFO : Ok, Clonezilla distribution is $DISTRIB_ID $DISTRIB_RELEASE ($DISTRIB_CODENAME)"
echo " I'm gonna download shim-signed and grub-efi-amd64-signed for Ubuntu $DISTRIB_CODENAME"
echo " !!! HERE BE DRAGONS !!!"
sleep 3

# This is very wrong, but the easyest methods i know so far ~Alex
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-= 

#ubuntu_ver="jammy"

ARY_DLlink_shim=($(wget -q -O - https://packages.ubuntu.com/$DISTRIB_CODENAME/amd64/shim-signed/download | grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' |grep .deb))
ARY_DLlink_grub=($(wget -q -O - https://packages.ubuntu.com/$DISTRIB_CODENAME/amd64/grub-efi-amd64-signed/download | grep -io '<a href=['"'"'"][^"'"'"']*['"'"'"]' |   sed -e 's/^<a href=["'"'"']//i' -e 's/["'"'"']$//i' |grep .deb))


#lineSHIM=$RANDOM
#let "lineSHIM %= ${#ARY_DLlink_shim[@]}"
#lineGRUB=$RANDOM
#let "lineGRUB %= ${#ARY_DLlink_grub[@]}"
#wget -O $basedir_temp/shim.deb ${ARY_DLlink_shim[$lineSHIM]}
#wget -O $basedir_temp/grub.deb ${ARY_DLlink_grub[$lineGRUB]}

# A better way to tests if download succeed... still good enough for me ^^'
for t in "${ARY_DLlink_shim[@]}"
do
  rm "${basedir_temp:?}"/shim.deb
  wget -q --no-check-certificate --timeout=10 -O "$basedir_temp"/shim.deb "$t" > /dev/null
  errlvl=$?
  if [ $errlvl -ne "0" ]; then
	echo "Download failed, trying next server..."
	sleep 1
  else
    dl_succeed=1
	break
  fi
done
if [ $dl_succeed -ne "1" ]; then
	echo "! ! ! ! ! ERROR while DOWNLOADING shim-signed ! ! ! ! !"
	echo "Download for https://packages.ubuntu.com/$DISTRIB_CODENAME/amd64/shim-signed/download FAILED ! "
	exit 1
fi

for t in "${ARY_DLlink_grub[@]}"
do
  rm "${basedir_temp:?}"/grub.deb
  wget -q --no-check-certificate --timeout=10 -O "$basedir_temp"/grub.deb "$t" > /dev/null
  errlvl=$?
  if [ $errlvl -ne "0" ]; then
	echo "Download failed, trying next server..."
	sleep 1
  else
	dl_succeed=1
	break
  fi
done
if [ $dl_succeed -ne "1" ]; then
	echo "! ! ! ! ! ERROR while DOWNLOADING grub-efi-amd64-signed ! ! ! ! !"
	echo "Download for https://packages.ubuntu.com/$DISTRIB_CODENAME/amd64/grub-efi-amd64-signed/download FAILED ! "
	exit 1
fi
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
# Quel bordel...vivement que dpkg supporte zstd (!)
echo "-------------------------------------------------------------"
echo "  ========> Extracting shim.deb . . . "
mkdir "$basedir_temp"/shim_out_intermediate
mkdir "$basedir_temp"/shim_out
ar -x --output="$basedir_temp"/shim_out_intermediate "$basedir_temp"/shim.deb
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR while extracting files from shim.deb ! ! ! ! !"
	exit 1
fi
echo "-------------------------------------------------------------"
echo "  ========> Extracting shim ressources . . . "
tar -C "$basedir_temp"/shim_out -xf "$basedir_temp"/shim_out_intermediate/data.tar.* 
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR while extracting shim ressources ! ! ! ! !"
	exit 1
fi
echo "-------------------------------------------------------------"
echo "  ========> Extracting grub.deb . . . "
mkdir "$basedir_temp"/grub_out_intermediate
mkdir "$basedir_temp"/grub_out
ar -x --output="$basedir_temp"/grub_out_intermediate "$basedir_temp"/grub.deb
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR while extracting files from grub.deb ! ! ! ! !"
	exit 1
fi
echo "-------------------------------------------------------------"
echo "  ========> Extracting grub ressources . . . "
tar -C "$basedir_temp"/grub_out -xf "$basedir_temp"/grub_out_intermediate/data.tar.* 
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR while extracting grub ressources ! ! ! ! !"
	exit 1
fi


echo "-------------------------------------------------------------"
echo "  ========> Copying shimx64.efi.signed . . . "
shimx64=$(find "$basedir_temp/shim_out" -name shimx64.efi.signed| head -n 1)
if [ ! -f "$shimx64" ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR : shimx64.efi.signed is nowhere to be found ! ! ! ! !"
	exit 1
fi
cp "$shimx64" "$basedir_release/shimx64.efi"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR while copying shimx64.efi.signed ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  ========> Copying grubnetx64.efi.signed . . . "
grubnetboot=$(find "$basedir_temp"/grub_out -name grubnetx64.efi.signed| head -n 1)
if [ ! -f "$grubnetboot" ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR : grubnetx64.efi.signed is nowhere to be found ! ! ! ! !"
	exit 1
fi
cp "$grubnetboot" "$basedir_release/grubx64.efi"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERROR while copying grubnetx64.efi.signed ! ! ! ! !"
	exit 1
fi
# On a ENFIN FINI de faire joujou avec shim && gub signed, on reprends la sauce
# =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=
echo "-------------------------------------------------------------"
echo "  ========> Copying init.xz to temp folder . . . "
cp "$foginit_xz" "$basedir_temp/foginit.xz"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande cp ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  =============> Uncompressing foginit.xz to 'foginit' . . . "
xz --decompress "$basedir_temp/foginit.xz"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande xz ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  ============================> Mounting foginit (ext2). . . "
mkdir "$basedir_temp/init_fog"
mount "$basedir_temp/foginit" "$basedir_temp/init_fog"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande mount ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  ================> Copying FOG 'FOS' rootfs to ./rootfs. . . "
cp -rv "$basedir_temp"/init_fog/* "$basedir_rootfs" > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande cp ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  => I'm done with FOG 'FOS' rootfs 'foginit', umounting it. "
umount "$basedir_temp/init_fog"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande umount ! ! ! ! !"
	exit 1
fi
rm -rf "$basedir_temp/init_fog"

echo "-------------------------------------------------------------"
echo "  ========> Cleaning old modules from 'FOS' rootfs. . . "
rm -rf "$basedir_rootfs"/lib/modules/*
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande rm ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  =====> Copying Clonezilla modules to the new rootfs. . . "
cp -rv "$basedir_temp"/squash/usr/lib/modules "$basedir_rootfs/lib/modules" > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande cp ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  ====> I'm done with Clonezilla squashfs, umounting it. . . "
umount "$basedir_temp/squash"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande umount ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  =====> CHMODing new modules with the right permissions. . . "
chmod -R 0755 "$basedir_rootfs/lib/modules"
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande chmod ! ! ! ! !"
	exit 1
fi

echo "-------------------------------------------------------------"
echo "  =======================> Cleaning inused modules. . . "

[ -z "$basedir_rootfs" ] && eval 'echo "basedir_rootfs ne semble pas correctement configurée, j'\''arrête là !";exit 1'
# Raison : Bruits dans les logs
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/input/evbug.ko -rf
# Raison : Inutile
rm "$basedir_rootfs"/lib/modules/*/kernel/sound -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/media -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/net/wireless -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/net/can -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/infiniband -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/comedi -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/bluetooth -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/gpu -rf
# 97Mio -> 73.7 Mio (+23,3 Mio)


rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/net/ethernet/mellanox -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/net/ethernet/chelsio -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/net/ethernet/qlogic -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/net/ethernet/sfc -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/net/ethernet/cavium -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/net/ethernet/dec -rf
# 73.7 Mio -> 70.7 Mio (+3 Mio)

rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/iio -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/usb/ethernet/gadget -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/usb/ethernet/serial -rf
rm "$basedir_rootfs"/lib/modules/*/kernel/drivers/usb/ethernet/misc -rf
# 70.7 Mio -> 68.9 Mio (+1.8 Mio)


echo "-------------------------------------------------------------"
echo "  ==========> Copying folder project into the new rootfs. . . "
cp -rvf "$basedir_project"/* "$basedir_rootfs" > /dev/null 2>&1
if [ $? -ne 0 ]
then
	echo "ERRLVL : $?"
	echo "! ! ! ! ! ERREUR lors de la commande cp ! ! ! ! !"
	exit 1
fi



olddir=$PWD
cd "$basedir_rootfs" || exit
echo "-------------------------------------------------------------"
echo "  ==========> CHMODing files into the rootfs. . . "
chmod -R +x "$basedir_rootfs/"



echo "-------------------------------------------------------------"
echo "  ==========> Convert the new rootfs into a CPIO. . . "
#~~~~~~~~~~~~~~~~~ PATCH DE DERNIERE MINUTE ~~~~~~~~~~~~~~~~~~~~
# Comme on convertis un ext2 en cpio, le fichier de démarrage change.
# Il passe de {/linuxrc,...} en {/init,...}. Il convient donc de réaliser
#  un lien symbolique pour que la fs puisse être "amorcée".
ln -s ./bin/busybox ./init
echo "-------------------------------------------------------------"
echo "  =====> Create the CPIO archive from the rootfs folder. . . "
#~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
#find . 2>/dev/null | cpio -o -H newc -R root:root | xz -v -9 -T0 --format=lzma > $basedir_temp/newroot.xz
find . 2>/dev/null | cpio -o -H newc -R root:root | xz -v -7 -T0 -C crc32 > "$basedir_temp"/newroot.xz
#find . 2>/dev/null | cpio -o -H newc -R root:root | gzip > $olddir/$nomImage.gz
#find . ! -name . | LC_ALL=C sort | cpio -o -H newc -R root:root | gzip > $olddir/$nomImage.gz
cd "$olddir" || exit

echo "-------------------------------------------------------------"
echo "  => Move the freshly created CPIO into $basedir_release/fog_uefi.cpio.xz. . . "
mv "$basedir_temp"/newroot.xz "$basedir_release/fog_uefi.cpio.xz"

echo "DONE !"
