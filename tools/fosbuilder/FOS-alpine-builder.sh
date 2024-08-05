#!/bin/bash
# FOS Alpine Linux builder - 2024.01.24
#
#
# External deps : curl, wget, tput, stat, du, _binutils_ (ar), zstd, realpath, tar, _rsync_, xz
#
# Alpine core (apk): https://gitlab.alpinelinux.org/api/v4/projects/5/packages/generic/v2.12.10/x86_64/apk.static
# APK debs : alpine-baselayout apk-tools busybox busybox-suid musl-utils alpine-release alpine-base
#
# Some constants :

# v --- Used when downloading linux-kernel and TODO
: "${UBUNTU_repo_url:=http://archive.ubuntu.com/ubuntu}"
: "${UBUNTU_package_name:=linux-image-generic}"
: "${UBUNTU_architecture:=amd64}"
: "${UBUNTU_distroname:=noble}"
: "${GITHUB_alpine_chroot_install:=https://github.com/alpinelinux/alpine-chroot-install/}"
: "${GITHUB_FOS:=https://github.com/FOGProject/FOS/}"
: "${ALPINE_distroname:=v3.20}"
# -----
_retval=''
# List of apk to be installed into Alpine Linux
apk_list=('alpine-base' 'acl' 'bash' 'btrfs-progs' 'bzip2' 'cabextract' 'chntpw' 'cifs-utils' 'coreutils' \
'cryptsetup' 'dmidecode' 'dmraid' 'dosfstools' 'e2fsprogs' 'e2tools' 'efibootmgr' \
'efivar' 'elfutils' 'ethtool' 'eudev' 'udev-init-scripts' 'f2fs-tools' 'gawk' 'gettext' \
'gcompat' 'gptfdisk' 'sgdisk' 'zlib' 'haveged' 'hdparm' 'genext2fs' 'jq' 'patchelf' \
'zstd' 'hwdata' 'ifupdown-ng' 'iperf' 'iperf3' 'kbd' 'lshw' 'lvm2' 'lzo' 'mdadm' \
'ntfs-3g-progs' 'nvme-cli' 'openssh' 'nfs-utils' 'parted' 'ntfs-3g' 'pciutils' \
'pcre' 'pigz' 'popt' 'rsync' 'sed' 'smartmontools' 'socat' 'util-linux' 'nano' \
'xfsprogs' 'xz' 'zlib' 'zstd' 'curl' 'wget' 'testdisk' 'dialog' \
'kmod' \
'dtach' 'ttyd' 'mini_httpd' 'memtester' 'openssl') # Ajouts pour FOGUefi
# Ajout 20240522 - kmod -> Nécessaire pour depmod/insmod correctement les modules d'Ubuntu 24.04

# Quitte immédiatement si il y a une erreur non gérée
set -eE -o functrace
set -o pipefail -o errexit -o errtrace
shopt -s inherit_errexit
_ERRMSG="" # Utilisée dans le cas où on souhaite changer le message d'erreur par défaut.
trap 'throw_error $?  "$([[ -n "$_ERRMSG" ]] && echo "$_ERRMSG" || echo "Unhandled fatal error!")" "$0 (${FUNCNAME} - line: $LINENO)" "$BASH_COMMAND"' ERR

# Pas de chemin de travail ? Définis le dossier courant !
: "${sysbasepath:="$PWD"}"
sysbasepath=$(realpath "$sysbasepath") # Bug alacon ^^'
function get_current_path {
	# Fournis un point de base aux fichiers
	if [ "$sysbasepath" == '/' ]; then
        echo "FATAL ERROR"
        echo "sysbasepath ($sysbasepath) is / ! get_current_path - (${LINENO})"
        false; exit 1
  fi
  echo "$sysbasepath"
}

do_logfile="$(get_current_path)/installer.log"
# Write message to $do_logfile
do_log() {
	echo "$(date +"%d.%m.%Y %H:%M:%S") $1" >> "$do_logfile" || true
}

# Show message on stdout and log message to $do_logfile
_logecho() {
	echo "$(date +"%d.%m.%Y %H:%M:%S") $1" >> "$do_logfile" || true
  >&2 echo -e "$1"
}

# Throw an error and log it to $do_logfile
function throw_error {
  local errcode="$1"        # $1 - Error level 
  local message="$2"        # $2 - Human "readable" message
  local funct_linenum="$3"  # $3 - Function - LineNumber
  local faulty_cmd="$4"  # $4 - Faulty command
  if [ -z "$funct_linenum" ]; then
	funct_linenum='(main?)'
  fi

  i=-1
  execution_trace=" -- Execution stack :"
  for funct in "${FUNCNAME[@]}"
  do
    #if [ "$i" != -1 ]; then # Ignore la fonction courante (throw_error)
    execution_trace="$execution_trace\r\n Function : $funct line : ${BASH_LINENO[$i]}"
    #fi
    i=$((i+1))
  done
  

  if [ "$errcode" != 0 ]; then
    _logecho ""
    _logecho ""
    _logecho " =-=-=-=-= AN ERROR HAS BEEN THROWN ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" || true
    _logecho " Error code : $errcode" || true
    _logecho " Function : $funct_linenum" || true
    _logecho " Command : $faulty_cmd" || true
    _logecho " Message : $message" || true
    _logecho "" || true
    _logecho "$execution_trace" || true
    _logecho "" || true
    do_log " -- BEGIN Variable"
    do_log "$(set -o posix ; set)"
    do_log " -- END Variable"
    _logecho " Script stopped. Please report this error to the developpers, with the console output." || true
    _logecho "  Thank you !" || true
    _logecho " =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=" || true
    kill $$
    sleep 1 # Donnes le temps à kill de faire l'affaire
    exit "$errcode" # TODO FIXME : Ne fait rien sur les subshell ! 
  fi
}

function _get_basedir {
  local fldr="$1"
	local bdir
  local curr
  rm --help 2>&1 | grep -Fq 'one-file-system' && rm_opts='--one-file-system'
  curr="$(get_current_path)"
  if [ -z "$fldr" ]; then _ERRMSG="var fldr is empty! Giving up"; false; exit 1; fi
	bdir="${curr:?}/${fldr:?}"
  if [ -d "$bdir" ] && [ "$_CLEANUP" == 1 ]; then do_log "Do unmount $bdir"; umount_devproc "$bdir"; fi # If dev, sys, proc is already mounted, unmount it before! 
  # shellcheck disable=SC2086
  if [ -d "$bdir" ] && [ "$_CLEANUP" == 1 ]; then do_log "Delete folder $bdir"; rm -Rf $rm_opts "$bdir"; fi
  #if [ -d "$bdir" ] && [ "$_CLEANUP" == 1 ]; then do_log "SIMULATOR : Delete folder $bdir"; fi
	if [ ! -d "$bdir" ]; then do_log "Create folder $bdir"; mkdir "$bdir"; fi
	echo "$bdir"
}

function get_basedir_src {
  local _tmp_CLEANUP
  _tmp_CLEANUP="$_CLEANUP"
  _get_basedir 'src'
  _CLEANUP="$_tmp_CLEANUP"
}

function get_basedir_sources {
	_get_basedir 'sources'
}

function get_basedir_temp {
	_get_basedir 'temp'
}

function get_basedir_release {
	_get_basedir 'release'
}

function get_basedir_rootfs {
	_get_basedir 'rootfs'
}

function get_basedir_buildtool {
	_get_basedir 'buildtool'
}

# Function to download a package and its dependencies recursively
function _dl_package() {
  local package_name="$1"       # "linux-image-generic"
  local architecture="$2"       # "amd64"
  local download_location="$3"  # "/foo/bar/some/folder"
  local repo_url="$4"           # "http://archive.ubuntu.com/ubuntu"
  local skip_deps="$5"          # 0 (No skipping) / 1 (Skip)
  local package_info
  local package_filename
  local package_url
  local dependencies

  #echo " --- Now downloading package $1"
  do_log " Begin _dl_package ${package_name} % ${architecture} % ${download_location} % ${repo_url} % ${skip_deps}"
  
  package_info=$(grep -A 20 "^Package: $package_name\$" "$(get_basedir_temp)/repository")

  if [ -z "$package_info" ]; then
    #echo "Package $package_name not found in the repository."
    _ERRMSG="FATAL : Package $package_name not found in the repository."
    return 1
  fi

  #local package_version=$(echo "$package_info" | grep "^Version:" | awk '{print $2}')
  #local package_url="${repo_url}/pool/main/${package_name:0:1}/${package_name}/${package_name}_${package_version}_${architecture}.deb"

  package_filename=$(echo "$package_info" | grep "^Filename:" | awk '{print $2}')
  package_url="${repo_url}/${package_filename}"

  # Download the package
  # Part of the code : Jakub Jirutka <jakub@jirutka.cz> (MIT License)
  _ERRMSG="FATAL : Error when downloading deb package ${download_location}"
	if command -v curl >/dev/null; then
		curl --output-dir "${download_location}" --remote-name --connect-timeout 10 -fsSL "${package_url}" >> "$do_logfile" 2>&1
	elif command -v wget >/dev/null; then
		wget -P "${download_location}" -T 10 --no-verbose "${package_url}" >> "$do_logfile" 2>&1
	else
		_ERRMSG='FATAL: Cannot download package package_url to download_location : neither curl nor wget is available!'
    false; exit 1
	fi

  # Download dependencies
  dependencies=$(echo "$package_info" | sed -n '/^Depends:/ s/Depends: //p' | tr ',' '\n')
  if [ -n "$dependencies" ] && [ "$skip_deps" -eq 0 ]; then
    for dependency in $dependencies; do
      dependency=$(echo "$dependency" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')  # Remove leading and trailing spaces
        
      local internal_keep_package="0"
      [ -z "$pkgdl_keeppkg" ] && pkgdl_keeppkg="linux-image;linux-modules;signed" # Allowed package name list
      if [ -n "$pkgdl_keeppkg" ]; then
        oldIFS=$IFS
        IFS=';'
        for expr in $pkgdl_keeppkg
        do
          # Package with a similar name on the list ? We keep it
          if [[ "$dependency" == *"$expr"* ]]; then
            internal_keep_package="1"
          fi
        done
        IFS=$oldIFS

        # If we found a dependancy for the modules "-extra", we dosent keep it.
        #if [[ "$dependency" == *"-extra"* ]]; then internal_keep_package=0; fi
      else
          internal_keep_package="1"
      fi	# --> if [ -n "$pkgdl_keeppkg" ]; then
        
      if [ "$internal_keep_package" -eq "1" ]; then
        do_log " do DEPS _dl_package ${dependency}"
        _dl_package "$dependency" "$architecture" "$download_location" "$repo_url" "$skip_deps"
      fi
		done
	fi
}

function init_dl_package {
  # This function download the repository from Ubuntu's $distroname and unpacks it
  # Return on success, otherwise throw an error with exit

  # Create the URL for the compressed Packages file
  packages_url="${UBUNTU_repo_url}/dists/${UBUNTU_distroname}/main/binary-${UBUNTU_architecture}/Packages.gz"

  do_log "Do init_dl_package with URL $packages_url"

  _ERRMSG="FATAL: Error when downloading packages list ${packages_url}"
  # Download and extract the compressed Packages file
  # Part of the code : Jakub Jirutka <jakub@jirutka.cz> (MIT License)
	if command -v curl >/dev/null; then
		curl -o "$(get_basedir_temp)/repository.gz" --remote-name --connect-timeout 10 -fsSL "${packages_url}" >> "$do_logfile" 2>&1
	elif command -v wget >/dev/null; then
		wget -O "$(get_basedir_temp)/repository.gz" -T 10 --no-verbose "${packages_url}" >> "$do_logfile" 2>&1
	else
		_ERRMSG='FATAL: Cannot download repository packages_url: neither curl nor wget is available!'
    false; exit 1
	fi
  _ERRMSG='FATAL: Uncompress repository failed'
  gunzip "$(get_basedir_temp)/repository.gz"
  do_log "Done init_dl_package"
}

function unpack_deb {
  # $1 - Package output directory
  # $2 - Absolute path deb package
  # Return - the path to the data.tar.{gz/xz/zst}
  # Fail if not data.tar.? can be found
  local _oldPWD
  local _pkgout
  local _pkgdeb
  local _tarpkg

  _oldPWD="$sysbasepath"
  _pkgout="$1"
  _pkgdeb="$2"

  cd "$_pkgout"
  ar vx "$_pkgdeb" data.tar.gz data.tar.xz data.tar.zst data.tar >> "$do_logfile" 2>&1
  cd "$_oldPWD"
  _tarpkg="${_pkgout}/data.tar.gz"
  if [ ! -r "$_tarpkg" ]; then _tarpkg="${_pkgout}/data.tar.xz"; fi
  if [ ! -r "$_tarpkg" ]; then _tarpkg="${_pkgout}/data.tar.zst"; fi
  if [ ! -r "$_tarpkg" ]; then _tarpkg="${_pkgout}/data.tar"; fi
  if [ ! -r "$_tarpkg" ]; then _ERRMSG="FATAL : Unable to find package output for $_pkgdeb"; false; exit 1; fi

  _retval="$_tarpkg"
}

function mount_devproc {
  # $1 - Folder where dev, proc, sys shm is to be mounted
  _ERRMSG="FATAL: Folder not found $1"
  if [ ! -d "$1" ]; then false; exit 1; fi

  {
    mount -v -t proc none "${1}/proc"
    mount -v --rbind /sys "${1}/sys"
    mount --make-rprivate "${1}/sys"
    mount -v --rbind /dev "${1}/dev"
    mount --make-rprivate "${1}/dev"
  } >> "$do_logfile" 2>&1
 
  # Some systems (Ubuntu?) symlinks /dev/shm to /run/shm.
  if [ -L /dev/shm ] && [ -d /run/shm ]; then
    {
      mkdir -p "${1}/run/shm"
      mount -v --bind /run/shm "${1}/run/shm"
      mount --make-private "${1}/run/shm"
    } >> "$do_logfile" 2>&1
  fi
  {
    mkdir -p "${1}/sources"
    mount -v --bind "$(get_basedir_sources)" "${1}/sources"
    mount --make-private "${1}/sources"
  } >> "$do_logfile" 2>&1
}

function umount_devproc {
  # $1 - Folder where dev, proc, sys shm is already mounted
  _ERRMSG="FATAL: Folder not found $1"
  if [ ! -d "$1" ]; then false; exit 1; fi
  do_log "Begin unmounting"
  
  
  if < /proc/mounts cut -d' ' -f2 | grep -q "^${1}."; then # La logique de grep est "à l'envers ; 1= Non trouvé / 0=Trouvé
    do_log "unmount_devproc: Path $1 FOUND, proceed..."
    # shellcheck disable=SC2002
    cat /proc/mounts | cut -d' ' -f2 | grep "^${1}." | sort -r | while read -r path; do
      do_log "Unmounting $path"
      umount -fn "$path" || true >> "$do_logfile" 2>&1
    done
  else
    do_log "unmount_devproc: Path $1 not found in /proc/mounts"
  fi
}

# Code from Mikel (https://unix.stackexchange.com/users/3169/mikel)
# check if stdout is a terminal...
C_ColTERM=0
if test -t 1; then
    # see if it supports colors...
    ncolors=$(tput colors)
    if test -n "$ncolors" && test "$ncolors" -ge 8; then
        # shellcheck disable=SC2034
        C_BOLD="$(tput bold)"
        # shellcheck disable=SC2034
        C_UNDERLINE="$(tput smul)"
        # shellcheck disable=SC2034
        C_standout="$(tput smso)"
        C_NO_COLOUR="$(tput sgr0)"
        C_BLACK="$(tput setaf 0)"
        C_RED="$(tput setaf 1)"
        C_GREEN="$(tput setaf 2)"
        C_YELLOW="$(tput setaf 3)"
        C_BLUE="$(tput setaf 4)"
        C_MAGENTA="$(tput setaf 5)"
        C_CYAN="$(tput setaf 6)"
        C_WHITE="$(tput setaf 7)"
        C_ColTERM=1
    else
        C_NO_COLOUR=""
        # shellcheck disable=SC2034
        C_BLACK="0"
        # shellcheck disable=SC2034
        C_RED="1"
        C_GREEN="2"
        # shellcheck disable=SC2034
        C_YELLOW="3"
        # shellcheck disable=SC2034
        C_BLUE="4"
        # shellcheck disable=SC2034
        C_MAGENTA="5"
        # shellcheck disable=SC2034
        C_CYAN="6"
        # shellcheck disable=SC2034
        C_WHITE="7"
        C_ColTERM=0
    fi
fi

eenter() {
  local term_width
  term_width=$(tput cols)
  term_width=$((term_width-10))

  printf " * %s" "$1"
  do_log "MSG (eenter) : $1"
  internal_task="${1}"
  _ERRMSG="FATAL: ${1}" # By default, set the error message to eenter msg. An other error message overrides the default behaviour
  return 0
}

eend() {
  local pad
  local term_width
  local temp_strlen
  local temp_msg="$1"
  local temp_msglen
  temp_msglen=${#temp_msg}
  term_width=$(tput cols)
  term_width=$((term_width-8))
  temp_strlen=${#internal_task}
  term_width=$((term_width-temp_strlen))
  term_width=$((term_width-temp_msglen))

  printf -v pad '%*s' "$term_width" ""
  #printf " * %s%*.*s" "$1" 0 $((term_width-${#1})) "$pad"
  echo "${pad}[$2 $temp_msg $C_NO_COLOUR]"
	do_log "TASK FINISHED (eend) '$1' State:$2 (Task: ${internal_task})"
	internal_task=''
	return 0
}

pBar() {
  if [ "$C_ColTERM" -eq 1 ]; then
    # Process data
        # shellcheck disable=SC2017
        _progress=$(((${1}*100/${2}*100)/100))
        _done=$((( _progress * 4 ) / 10 ))
        _left=$((40-_done))
    # Build progressbar string lengths
        _fill=$(printf "%${_done}s")
        _empty=$(printf "%${_left}s")

    printf "\r Progress : [${_fill// /█}${_empty// /-}] (${1}/${2}) ${_progress}%%"
  fi
}

function alpine_exec() {
  # $3 - Command to execute
  # $2 - Run command as user (default : root)
  # $1 - Alpine Linux rootfs
  # Return nothing 
  local _user
  do_log "[ALPINE] - Execute a command $3"
  _ERRMSG="FATAL: [ALPINE] Command $3 return non-zero"
  _user="${2}"
  if [ -z "$_user" ]; then _user='root'; fi
  # shellcheck disable=SC2086
  "${1}"/enter-chroot -u "$_user" $3 >> "$do_logfile" 2>&1
}

function alpine_add_apk() {
  # $2 - One package to add
  # $1 - Alpine Linux rootfs
  # Return nothing 
  do_log "[ALPINE] - Install a APK package : $2"
  _ERRMSG="FATAL: [ALPINE] Unable to install APK package $2 ${1}/enter-chroot"
  # shellcheck disable=SC2086
  "${1}"/enter-chroot apk add $2 >> "$do_logfile" 2>&1
}

 
_logecho ' ---- FOS "FOGUefi" Builder ----'
_logecho ''
do_log ''
do_log "Running as $USER on host $HOSTNAME (PWD:$(get_current_path))"

# Check if git is present
_ERRMSG='git is not installed ; Please install git first.'
git version >> "$do_logfile" 2>&1

# Check if we are root
if [ "$(id -u)" -ne 0 ]; then 
  _ERRMSG='This script must be run as root.'; exit 1
fi

# Est-ce que je nettoie les dossiers de travail avant ? Par défaut : OUI
: "${_CLEANUP:="1"}" 
: "${_OFFLINE:="0"}"
[ "$_OFFLINE" -eq "1" ] && _CLEANUP=0 # Offline mode ? No cleanup ! 

# !!! DANGER !! NOT DOT USE get_basedir_* _BEFORE THIS LINE_ !!!
# If _CLEANUP = 1, these folder is cleaned. (unmount + rm -rf'ed)
_ERRMSG='Error when preping essentials directory.'
do_log "_CLEANUP is $_CLEANUP"
do_log "_OFFLINE is $_OFFLINE"
do_log "get_basedir_sources is $(get_basedir_sources)"
do_log "get_basedir_temp is $(get_basedir_temp)"
do_log "get_basedir_release is $(get_basedir_release)"
do_log "get_basedir_rootfs is $(get_basedir_rootfs)"
do_log "get_basedir_buildtool is $(get_basedir_buildtool)"
_CLEANUP=0 # Fin du cleanup (les énumérer suffit à les nettoyer)

# Recopie le dossier src dans ./sources (src=Source des scripts..., source=Source téléchargée, nettoyée par le script à chaque démarrage)
if [ -d "$(get_current_path)/src" ]; then
  cp -rv "$(get_current_path)/src" "$(get_basedir_sources)" >> "$do_logfile" 2>&1
else
  _ERRMSG="FATAL: The folder $(get_current_path)/src does not exist."
  exit 1
fi

# Are we online ? If yes, please download all theses precious ressources needed :)
if [ "$_OFFLINE" -eq "0" ]; then 
  eenter 'Clone git alpinelinux/alpine-chroot-install/...'
    _ERRMSG="FATAL: Failed to git clone $GITHUB_alpine_chroot_install. Is Internet unreacheable ?"
    git clone "$GITHUB_alpine_chroot_install" "$(get_basedir_sources)"/alpine-chroot-install >> "$do_logfile" 2>&1
  eend "Done ($(du -hs --apparent-size "$(get_basedir_sources)"/alpine-chroot-install | cut -f1))" "$C_GREEN"

  eenter 'Clone git FOGProject/FOS/...'
    _ERRMSG="FATAL: Failed to git clone $GITHUB_FOS. Is Internet unreacheable ?"
    git clone "$GITHUB_FOS" "$(get_basedir_sources)"/FOS >> "$do_logfile" 2>&1
  eend "Done ($(du -hs --apparent-size "$(get_basedir_sources)"/FOS | cut -f1))" "$C_GREEN"
  
  eenter "Fetch Ubuntu $UBUNTU_distroname repository..."
    _ERRMSG="FATAL: Unable to fetch Ubuntu $UBUNTU_distroname repository"
    init_dl_package
  eend "Done ($(du -hs --apparent-size "$(get_basedir_temp)"/repository | cut -f1))" "$C_GREEN"

  eenter "Download linux-image-generic (+modules)..."
    mkdir -p "$(get_basedir_sources)/linux-image-generic/linux-out"
    mkdir -p "$(get_basedir_sources)/linux-image-generic/modules-out"
    mkdir -p "$(get_basedir_sources)/linux-image-generic/modules-extra-out"
    _dl_package "linux-image-generic" "$UBUNTU_architecture" "$(get_basedir_sources)/linux-image-generic" "$UBUNTU_repo_url" "0"
  eend "Done ($(du -hs --apparent-size "$(get_basedir_sources)"/linux-image-generic | cut -f1))" "$C_GREEN"

  eenter "Download shim-signed..."
    mkdir -p "$(get_basedir_sources)/shim-signed/out"
    _dl_package "shim-signed" "$UBUNTU_architecture" "$(get_basedir_sources)/shim-signed" "$UBUNTU_repo_url" "1"
  eend "Done ($(du -hs --apparent-size "$(get_basedir_sources)"/shim-signed | cut -f1))" "$C_GREEN"

  eenter "Download grub-efi-amd64-signed..."
    mkdir -p "$(get_basedir_sources)/grub-efi-amd64-signed/out"
    _dl_package "grub-efi-amd64-signed" "$UBUNTU_architecture" "$(get_basedir_sources)/grub-efi-amd64-signed" "$UBUNTU_repo_url" "1"
  eend "Done ($(du -hs --apparent-size "$(get_basedir_sources)"/grub-efi-amd64-signed | cut -f1))" "$C_GREEN"
fi
# Brief test to see if we all our sources where it should be.
_ERRMSG="alpine-chroot-install : Unable to find $(get_basedir_sources)/alpine-chroot-install/alpine-chroot-install (_OFFINE=$_OFFLINE)"
if [ ! -r "$(get_basedir_sources)/alpine-chroot-install/alpine-chroot-install" ]; then false; exit 1; fi
_ERRMSG="FOS : Unable to find $(get_basedir_sources)/FOS/Buildroot/board/FOG/FOS/rootfs_overlay/bin/fog (_OFFINE=$_OFFLINE)"
if [ ! -r "$(get_basedir_sources)/FOS/Buildroot/board/FOG/FOS/rootfs_overlay/bin/fog" ]; then false; exit 1; fi
_FOS_SRCFLDR="$(get_basedir_sources)/FOS/Buildroot/board/FOG/FOS/rootfs_overlay"
if [ ! -r "$_FOS_SRCFLDR" ]; then false; exit 1; fi
_ERRMSG="FATAL : Unable to find linux-image-generic [[linux-image-[0-9].*.deb] (_OFFINE=$_OFFLINE)"
_LINUXKRNL_DEBPKG=$(find "$(get_basedir_sources)" -iregex '.*linux-image-[0-9].*.deb' -size +5M | head -n 1 | xargs realpath); if [ ! -r "$_LINUXKRNL_DEBPKG" ]; then false; exit 1; fi
_ERRMSG="FATAL : Unable to find linux-image-generic:modules [linux-modules-[0-9].*.deb] (_OFFINE=$_OFFLINE)"
_MODULES_DEBPKG=$(find "$(get_basedir_sources)" -iregex '.*linux-modules-[0-9].*.deb' -size +5M | head -n 1 | xargs realpath); if [ ! -r "$_MODULES_DEBPKG" ]; then false; exit 1; fi
_ERRMSG="FATAL : Unable to find linux-image-generic:modules-extra [linux-modules-extra-[0-9].*.deb] (_OFFINE=$_OFFLINE)"
_MODULES_EXTRA_DEBPKG=$(find "$(get_basedir_sources)" -iregex '.*linux-modules-extra-[0-9].*.deb' -size +5M | head -n 1 | xargs realpath); if [ ! -r "$_MODULES_EXTRA_DEBPKG" ]; then false; exit 1; fi
_ERRMSG="FATAL : Unable to find shim-signed [shim-signed_[0-9].*.deb] (_OFFINE=$_OFFLINE)"
_SHIM_DEBPKG=$(find "$(get_basedir_sources)" -iregex '.*shim-signed_[0-9].*.deb'  | head -n 1 | xargs realpath); if [ ! -r "$_SHIM_DEBPKG" ]; then false; exit 1; fi
_ERRMSG="FATAL : Unable to find grub-efi-amd64-signed [grub-efi-amd64-signed_[0-9].*.deb] (_OFFINE=$_OFFLINE)"
_GRUB_DEBPKG=$(find "$(get_basedir_sources)" -iregex '.*grub-efi-amd64-signed_[0-9].*.deb' | head -n 1 | xargs realpath); if [ ! -r "$_GRUB_DEBPKG" ]; then false; exit 1; fi

# 1..4 : linux,modules,shim,grub (DEB)
eenter "Unpack deb packages (1/8) : linux-image-generic"
  unpack_deb "$(get_basedir_sources)/linux-image-generic/linux-out" "$_LINUXKRNL_DEBPKG" # 2-liner for catching error in function
  _LINUXKRNL_tarPKG="$_retval"
eend "Done" "$C_GREEN"
eenter "Unpack deb packages (2/8) : linux-modules"
  _ERRMSG="FATAL: Error when unpacking linux-modules?.deb"
  unpack_deb "$(get_basedir_sources)/linux-image-generic/modules-out" "$_MODULES_DEBPKG"
  _MODULES_tarPKG="$_retval"
  _ERRMSG="FATAL: Error when unpacking linux-modules-extra?.deb"
  unpack_deb "$(get_basedir_sources)/linux-image-generic/modules-extra-out" "$_MODULES_EXTRA_DEBPKG"
  _MODULES_EXTRA_tarPKG="$_retval"
eend "Done" "$C_GREEN"
eenter "Unpack deb packages (3/8) : shim-signed"
  unpack_deb "$(get_basedir_sources)/shim-signed/out" "$_SHIM_DEBPKG"
  _SHIM_tarPKG="$_retval"
eend "Done" "$C_GREEN"
eenter "Unpack deb packages (4/8) : grub-efi-amd64-signed"
  unpack_deb "$(get_basedir_sources)/grub-efi-amd64-signed/out" "$_GRUB_DEBPKG"
  _GRUB_tarPKG="$_retval"
eend "Done" "$C_GREEN"

# 4..8 : linux,modules,shim,grub (data.tar.?)
eenter "Unpack tar packages (5/8) : linux-image-generic"
  tar -C "$(get_basedir_sources)/linux-image-generic/linux-out" -xf "$_LINUXKRNL_tarPKG"  >> "$do_logfile" 2>&1
eend "Done" "$C_GREEN"
eenter "Unpack tar packages (6/8) : linux-modules"
  _ERRMSG="FATAL: Error when unTARing linux-modules?.deb"
  tar -C "$(get_basedir_sources)/linux-image-generic/modules-out" -xf "$_MODULES_tarPKG"  >> "$do_logfile" 2>&1
  _ERRMSG="FATAL: Error when unTARing linux-modules-extra?.deb"
  tar -C "$(get_basedir_sources)/linux-image-generic/modules-extra-out" -xf "$_MODULES_EXTRA_tarPKG"  >> "$do_logfile" 2>&1
eend "Done" "$C_GREEN"
eenter "Unpack tar packages (7/8) : shim-signed"
  tar -C "$(get_basedir_sources)/shim-signed/out" -xf "$_SHIM_tarPKG" >> "$do_logfile" 2>&1
eend "Done" "$C_GREEN"
eenter "Unpack tar packages (8/8) : grub-efi-amd64-signed"
  tar -C "$(get_basedir_sources)/grub-efi-amd64-signed/out" -xf "$_GRUB_tarPKG" >> "$do_logfile" 2>&1
eend "Done" "$C_GREEN"

# Search linux kernel in tar output
eenter "Search Linux kernel"
  _ERRMSG="FATAL : Unable to find vmlinuz.*-generic"
  _LINUXKRNL=$(find "$(get_basedir_sources)/linux-image-generic/linux-out" -iregex '.*vmlinuz.*-generic' | head -n 1 | xargs realpath); if [ ! -r "$_LINUXKRNL" ]; then false; exit 1; fi
eend "Found : $(basename "$_LINUXKRNL")" "$C_BLUE"

# Search linux modules in tar output
eenter "Search Linux modules"
  _ERRMSG="FATAL : Unable to find modules.builtin"
  _MODULES=$(find "$(get_basedir_sources)/linux-image-generic/modules-out" -name 'modules.builtin' | head -n 1 | xargs realpath | xargs dirname); if [ ! -r "$_MODULES" ]; then false; exit 1; fi
  _MODULES_EXTRA=$(ls "$(get_basedir_sources)/linux-image-generic/modules-extra-out/lib/modules/" | head -n 1) # Modules-extra is already tested upper. I assume (for now) this folder is okay. 
  _MODULES_EXTRA="$(get_basedir_sources)/linux-image-generic/modules-extra-out/lib/modules/${_MODULES_EXTRA}" # Oh boy...this is messy!
eend "Found : $(basename "$_MODULES")" "$C_BLUE"

# Search shim in tar output
eenter "Search Shim"
  _ERRMSG="FATAL : Unable to find shimx64.efi.signed.*"
  _SHIM=$(find "$(get_basedir_sources)/shim-signed/out" -name 'shimx64.efi.signed' | head -n 1 || true )
  if [ ! -r "$_SHIM" ]; then do_log 'WARNING : shimx64.efi.signed not found in (sources)/shim-signed/out'; _SHIM=$(find "$(get_basedir_sources)/shim-signed/out" -name 'shimx64.efi.signed.latest' | head -n 1 || true); fi
  if [ ! -r "$_SHIM" ]; then do_log 'WARNING : shimx64.efi.signed.latest not found in (sources)/shim-signed/out'; _SHIM=$(find "$(get_basedir_sources)/shim-signed/out" -name 'shimx64.efi.signed.previous' | head -n 1 || true); fi
  if [ ! -r "$_SHIM" ]; then do_log 'WARNING : shimx64.efi.signed.previous not found in (sources)/shim-signed/out'; _SHIM=$(find "$(get_basedir_sources)/shim-signed/out" -name 'shimx64.efi.dualsigned' | head -n 1 || true); fi
  if [ ! -r "$_SHIM" ]; then _ERRMSG='FATAL : Unable to find a valid shimx64.efi.signed.*'; false; exit 1; fi
  _SHIM=$(echo "$_SHIM" | xargs realpath)
eend "Found : $(basename "$_SHIM")" "$C_BLUE"

# Search Grub in tar output
eenter "Search Grub"
  _ERRMSG="FATAL : Unable to find grubnetx64.efi.signed"
  _GRUB=$(find "$(get_basedir_sources)/grub-efi-amd64-signed/out" -name 'grubnetx64.efi.signed' | head -n 1 | xargs realpath); if [ ! -r "$_GRUB" ]; then false; exit 1; fi
eend "Found : $(basename "$_GRUB")" "$C_BLUE"

# Linux  : (File) $_LINUXKRNL   (/foo/bar/(...)/vmlinuz-6.2.0-20-generic)
# Modules: (Dir.) $_MODULES     (/foo/bar/(...)/6.2.0-20-generic)
# shim   : (File) $_SHIM        (/foo/bar/(...)/shimx64.efi.signed.*)
# Grub   : (File) $_GRUB        (/foo/bar/(...)/grubnetx64.efi.signed)
# FOS    : (Dir.) $_FOS_SRCFLDR (/foo/bar/(...)/FOS/Buildroot/board/FOG/FOS/rootfs_overlay/)

eenter 'Copy Linux, Shim and Grub to the release folder'
  _ERRMSG='FATAL : Unable to copy Linux, Shim and Grub to the release folder'
  {
  cp -vf "$_LINUXKRNL" "$(get_basedir_release)/linux_kernel"
  chmod +r "$(get_basedir_release)/linux_kernel"
  cp -vf "$_SHIM" "$(get_basedir_release)/shimx64.efi"
  chmod +r "$(get_basedir_release)/shimx64.efi"
  cp -vf "$_GRUB" "$(get_basedir_release)/grubx64.efi"
  chmod +r "$(get_basedir_release)/grubx64.efi"
  } >> "$do_logfile" 2>&1
eend 'Done' "$C_GREEN"

# So, at this point, we are successfuly downloaded alpine-chroo-install and FOS. Shall we begin the process ? 

# TODO : Remove ME ! 
_OFFLINE=0

if [ "$_OFFLINE" -eq "0" ]; then 
  # alpine-baselayout is already included in the base package. This exist to consume "$ALPINE_PACKAGES".
  # Also, http_proxy and https_proxy are passed to the chroot to utilize a proxy server

  # TODO : Remove ME! 
	#export http_proxy=http://192.168.0.250:3128
	#export https_proxy=http://192.168.0.250:3128
  # shellcheck disable=SC2016
  #sed -i 's/curl --remote-name --connect-timeout 10 -fsSL "$url"/curl --remote-name --insecure --connect-timeout 10 -fsSL "$url"/g' "$(get_basedir_sources)/alpine-chroot-install/alpine-chroot-install"
  # -------

  eenter 'Create Alpine Linux rootfs (base)'
    "$(get_basedir_sources)/alpine-chroot-install/alpine-chroot-install" -a 'x86_64' -b "${ALPINE_distroname}" -d "$(get_basedir_rootfs)" -t "$(get_basedir_temp)" -p 'alpine-baselayout' -k 'ARCH CI QEMU_EMULATOR TRAVIS_.* http_proxy https_proxy' >> "$do_logfile" 2>&1
    # Remove mount point
    umount_devproc "$(get_basedir_rootfs)"
  eend 'Done' "$C_GREEN"

  # *** Prepare Alpine Linux build env 'buildtool'
  eenter 'Prepare Alpine Linux build env'
    rsync -avxHAX --progress "$(get_basedir_rootfs)/" "$(get_basedir_buildtool)" >> "$do_logfile" 2>&1
    mount_devproc "$(get_basedir_buildtool)"

    alpine_add_apk "$(get_basedir_buildtool)" "abuild"
    alpine_add_apk "$(get_basedir_buildtool)" "git"
    alpine_add_apk "$(get_basedir_buildtool)" "bash"
    alpine_add_apk "$(get_basedir_buildtool)" "nano"
    # alpine_exec "$(get_basedir_buildtool)" 'root' 'adduser -D bob'
    # alpine_exec "$(get_basedir_buildtool)" 'root' 'addgroup bob abuild'
    alpine_exec "$(get_basedir_buildtool)" 'root' 'abuild-keygen -a -n'
    mkdir "$(get_basedir_sources)/apkout"
  eend 'Done' "$C_GREEN"
  eenter 'Compile partclone'
  _ERRMSG='FATAL: Compilation of partclone failed'
    alpine_exec "$(get_basedir_buildtool)" 'root' <<-EOF
    cd /sources/src/partclone
    abuild -F -r
    find /root/packages -name '*.apk' -exec cp "{}" /sources/apkout/  \;
    rm -rf /root/packages
EOF
  eend 'Done' "$C_GREEN"
  eenter 'Compile partimage'
    _ERRMSG='FATAL: Compilation of partimage failed'
    alpine_exec "$(get_basedir_buildtool)" 'root' <<-EOF
    cd /sources/src/partimage
    abuild -F -r
    find /root/packages -name '*.apk' -exec cp "{}" /sources/apkout/  \;
    rm -rf /root/packages
EOF
  eend 'Done' "$C_GREEN"
  eenter 'Compile fogmbrfix'
    _ERRMSG='FATAL: Compilation of fogmbrfix failed'
    alpine_exec "$(get_basedir_buildtool)" 'root' <<-EOF
    cd /sources/src/fogmbrfix
    abuild -F -r
    find /root/packages -name '*.apk' -exec cp "{}" /sources/apkout/  \;
    rm -rf /root/packages
EOF
  eend 'Done' "$C_GREEN"
#  eenter 'Compile framebuffer-vncserver'
#    _ERRMSG='FATAL: Compilation of framebuffer-vncserver failed'
#    alpine_exec "$(get_basedir_buildtool)" 'root' <<-EOF
#    cd /sources/src/framebuffer-vncserver
#    abuild -F -r
#    find /root/packages -name '*.apk' -exec cp "{}" /sources/apkout/  \;
#    rm -rf /root/packages
#EOF
#  eend 'Done' "$C_GREEN"
  eenter 'Unmount buildtool'
    umount_devproc "$(get_basedir_buildtool)"
  eend 'Done' "$C_GREEN"
  # ***** END OF Prepare Alpine Linux build env 'buildtool

  do_log 'Remount devproc into rootfs'
  mount_devproc "$(get_basedir_rootfs)"

  eenter '  Install OpenRC (alpine-base)'
    alpine_add_apk "$(get_basedir_rootfs)" 'alpine-base'
  eend 'Done' "$C_GREEN"

  eenter '  Configure boot services'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add devfs sysinit'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add dmesg sysinit'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add mdev sysinit'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add hwclock boot'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add modules boot'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add sysctl boot'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add hostname boot'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add bootmisc boot'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add syslog boot'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add mount-ro shutdown'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add killprocs shutdown'
		alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add savecache shutdown'
  eend 'Done' "$C_GREEN"

  eenter '  Add essentials packages'; echo ""
  _temp=1
  for package in "${apk_list[@]}"
  do
    pBar "$_temp" "${#apk_list[@]}"
    alpine_add_apk "$(get_basedir_rootfs)" "$package"
    ((_temp++))
  done
  echo ""

  eenter '  Add sdparm and udpcast (edge testing)'
    alpine_exec "$(get_basedir_rootfs)" 'root' <<-EOF
	cp -vf /etc/apk/repositories /etc/apk/repositories_bak
	echo 'http://dl-cdn.alpinelinux.org/alpine/edge/testing/' >> /etc/apk/repositories
	apk update
	# INSTALL
	apk add sdparm
	apk add udpcast
  rm /etc/apk/repositories
	mv /etc/apk/repositories_bak /etc/apk/repositories
EOF
  eend 'Done' "$C_GREEN"

  eenter '  Add partclone,partimage,fogmbrfix (APK)' #; echo ""
    alpine_exec "$(get_basedir_rootfs)" 'root' <<-EOF
    apk add --allow-untrusted /sources/apkout/*.apk
EOF
  eend 'Done' "$C_GREEN"
  
  eenter 'Prepare FOS'
  rsync -avxHAX --progress "$_FOS_SRCFLDR/" "$(get_basedir_temp)/FOS" >> "$do_logfile" 2>&1
  eend 'Done' "$C_GREEN"
  eenter 'Patch FOS'
  _ERRMSG='FATAL: Patch FOS (1/3) : patch -p0 failed.'
  _oldPWD="$PWD"
    cd "$(get_basedir_temp)/FOS"
    patch -p0 < "$(get_basedir_src)/_patch/patch-FOS-for-AlpineLinux.patch" >> "$do_logfile" 2>&1
    # chmod -R +x ./* # Not needed since we are only patching some FOS files already present
  cd "$_oldPWD"
  _ERRMSG='FATAL: Patch FOS (2/3) : cleanup failed.'
  if [ -r "$(get_basedir_temp)/FOS/etc/profile" ]; then do_log "PATCH Cleanup ; rm -r $(get_basedir_temp)/FOS/etc/profile"; rm -v "$(get_basedir_temp)/FOS/etc/profile" >> "$do_logfile" 2>&1; fi
  if [ -r "$(get_basedir_temp)/FOS/etc/inittab" ]; then do_log "PATCH Cleanup ; rm -r $(get_basedir_temp)/FOS/etc/inittab"; rm -v "$(get_basedir_temp)/FOS/etc/inittab" >> "$do_logfile" 2>&1; fi
  if [ -r "$(get_basedir_temp)/FOS/etc/init.d" ]; then do_log "PATCH Cleanup ; rm -rv $(get_basedir_temp)/FOS/etc/init.d"; rm -rv "$(get_basedir_temp)/FOS/etc/init.d" >> "$do_logfile" 2>&1; fi
  _ERRMSG='FATAL: Patch FOS (3/3) : merge with Alpine Linux rootfs failed.'
  rsync -avxHAXI --progress "$(get_basedir_temp)/FOS/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
  eend 'Done' "$C_GREEN"
  
  eenter 'Inject FOGUefi files into the rootfs'
    _ERRMSG='FATAL: Inject FOGUefi : Error in rsync command.'
    rsync -avxHAXI --progress "$(get_basedir_src)/_rootfs/" "$(get_basedir_rootfs)" >> "$do_logfile" 2>&1
    sed -i "s/^export initversion=[0-9][0-9]*$/export initversion=$(date +%Y%m%d)/" "$(get_basedir_rootfs)/usr/share/fog/lib/funcs.sh"
  eend 'Done' "$C_GREEN"

  eenter 'Import Linux Modules into rootfs'
    rsync -avxHAX --progress "$_MODULES" "$(get_basedir_rootfs)/lib/modules/" >> "$do_logfile" 2>&1 
    rsync -avxHAX --progress "$_MODULES_EXTRA" "$(get_basedir_rootfs)/lib/modules/" >> "$do_logfile" 2>&1  # ADD 67 Mio into CPIO (!!)
    chmod -Rv 0755 "$(get_basedir_rootfs)/lib/modules/" >> "$do_logfile" 2>&1 
  eend 'Done' "$C_GREEN"

  eenter 'Configure FOS services'
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add aaaa-sysinit-depmod sysinit'
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add aaab-default-network default'
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add aaaa-default-keylayout default'
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add aaad-default-changerootpwd default'
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add aaae-default-rebootin24hrs default'
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add aaaf-default-FOS-InstallAPK default'

    # Now managed directly by OpenRC/agetty
    #alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add zzzz-default-fog default'

    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add ttyd default'
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add mini_httpd default'

    #alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add sshd boot' # Init SSH at boot
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add udev sysinit' # Init udev at sysinit
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add udev-trigger sysinit' # Init udev-trigger at sysinit
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add udev-settle sysinit' # Init udev-settle at sysinit
    alpine_exec "$(get_basedir_rootfs)" 'root' 'rc-update add udev-postmount default' # Init udev-postmount at default
  eend 'Done' "$C_GREEN"

  # ---- ICI, je fait du nettoyage dans la ROOTFS ----
  eenter 'Cleaning rootfs' # BASE:63M / EXTENDED:130M

    # == Remove 10M (BASE:53M / EXT:120M)
    _ERRMSG='FATAL: ROOTFS : Cleaning of Python failed'
    _tmp_ROOTFS="$(get_basedir_rootfs)"
    {
      rm -rfv "${_tmp_ROOTFS:?}"/usr/lib/python*
      rm -rfv "${_tmp_ROOTFS:?}"/usr/lib/libpy*
      rm -rfv "${_tmp_ROOTFS:?}"/usr/bin/pyth*
      rm -rfv "${_tmp_ROOTFS:?}"/usr/bin/pydo*
      rm -rfv "${_tmp_ROOTFS:?}"/usr/bin/2to3*
    } >> "$do_logfile" 2>&1
    
    # == Remove 36M (BASE:49M / EXT:84M)
    _ERRMSG='FATAL: ROOTFS : Cleaning of inused modules failed'
    {
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/input/evbug.ko
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/sound
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/media
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/net/wireless
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/net/can
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/infiniband
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/comedi
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/bluetooth
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/gpu
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/net/ethernet/mellanox
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/net/ethernet/chelsio
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/net/ethernet/qlogic
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/net/ethernet/sfc
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/net/ethernet/cavium
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/net/ethernet/dec
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/iio
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/usb/ethernet/gadget
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/usb/ethernet/serial
      rm -rfv "${_tmp_ROOTFS:?}"/lib/modules/*/kernel/drivers/usb/ethernet/misc
    } >> "$do_logfile" 2>&1
  
    # == Remove 2M (BASE:47M / EXT:81M)
    _ERRMSG='FATAL: ROOTFS : Cleaning of apk cache failed'
    rm -rfv "${_tmp_ROOTFS:?}"/var/cache/apk/* >> "$do_logfile" 2>&1


  eend 'Done' "$C_GREEN"
  # ---- Fin de la zone de netttoyage ----

  # A ce point, je ne DOIS PAS avoir dev, proc, sys... montée dans la rootfs. Je les démontes...
  _ERRMSG='FATAL: Prepare CPIO : unmount_devproc failed for ./rootfs'
  umount_devproc "$(get_basedir_rootfs)"
  _ERRMSG='FATAL: Prepare CPIO : unmount_devproc failed for ./buildtool'
  umount_devproc "$(get_basedir_buildtool)"

  eenter 'Patching ssh to enable sftp fonctionality'
  sed -i '/Subsystem/c\Subsystem sftp internal-sftp' "$(get_basedir_rootfs)/etc/ssh/sshd_config"
  eend 'Done' "$C_GREEN"
  
  # !!! DANGER AREA !!!
  # The Linux kernel generates a Kernel Panic 'Unable to mount root fs on unknown-block(0,0)' if (or based condition):
  #  * NO "/init" executable file are present into the CPIO ("ln -sv ./bin/busybox ./init" should do the trick)
  #  * INITRD has NOT been conceived with : xz -7 -T0 -C crc32 "$(get_basedir_temp)"/fog_uefi.cpio
  eenter 'Create CPIO Archive (1/2)'
    _oldPWD="$PWD"
      cd "$(get_basedir_rootfs)"
      ln -sv ./bin/busybox ./init >> "$do_logfile" 2>&1 # Needed for Linux
      find . 2>>"$do_logfile" | cpio -o -H newc -R root:root > "$(get_basedir_temp)"/fog_uefi.cpio 2>>"$do_logfile"
    cd "$_oldPWD"
  eend "Done" "$C_GREEN"

  eenter 'Compress CPIO Archive using xz (2/2)'
    xz -e -7 -T0 -C crc32 "$(get_basedir_temp)"/fog_uefi.cpio >> "$do_logfile" 2>&1
    #xz -7 -T0 -C crc32 "$(get_basedir_temp)"/fog_uefi.cpio >> "$do_logfile" 2>&1
    mv "$(get_basedir_temp)"/fog_uefi.cpio.xz "$(get_basedir_release)"/fog_uefi.cpio.xz
    chmod +r "$(get_basedir_release)"/fog_uefi.cpio.xz
  eend "Done ($(du -hs --apparent-size "$(get_basedir_release)"/fog_uefi.cpio.xz | cut -f1))" "$C_GREEN"

  _logecho "=> $(basename "$0") finished. Thanks for using my script."
  # FIXME : Refaire la liste des services communément utilisée dans FOGUefi (VNC, PWD, Earlyshell, ...)
  # FIXME : Faire un script pour "catch" les Fatal Error et générer un rapport à destination du serveur FOG.
  #         -> Avec, pourquoi pas, une capture d'écran et la trace réalisée? Aussi si mode=UP, demander si on veut un ntfsfix pour le plaisir... :)
  #         -> Voir pour faire un "chkdsk" directement dans FOS
  
else
  # tar -C "$(get_basedir_rootfs)" -xf "$(get_basedir_sources)/alpine-minirootfs-3.19.1-x86_64.tar.gz"
  # Add enter-chroot an<d destroy script
  # Add this to enter-chroot script : 
  #   mount -v -t proc none proc
  #   mount -v --rbind /sys sys
  #   mount --make-rprivate sys
  #   mount -v --rbind /dev dev
  #   mount --make-rprivate dev
  #   
  #   # Some systems (Ubuntu?) symlinks /dev/shm to /run/shm.
  #   if [ -L /dev/shm ] && [ -d /run/shm ]; then
  #   	mkdir -p run/shm
  #   	mount -v --bind /run/shm run/shm
  #   	mount --make-private run/shm
  #   fi
  #   
  #   if [ -d "$BIND_DIR" ]; then
  #   	mkdir -p "${CHROOT_DIR}${BIND_DIR}"
  #   	mount -v --bind "$BIND_DIR" "${CHROOT_DIR}${BIND_DIR}"
  #   	mount --make-private "${CHROOT_DIR}${BIND_DIR}"
  #   fi
  # "apk update"
  # Find a way to install loads of apk packages (+recompilation ?), by hand.
  _ERRMSG='Not implemented'
  false
fi
