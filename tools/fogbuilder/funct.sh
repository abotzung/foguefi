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
# Utilities/function for BuildFogUEFI.sh
# Alexandre BOTZUNG <alexandre.botzung@grandest.fr> 20230601

# Some code come from :
# Yusuph Wickama <yusuph.wickama@wickerlabs.com> : https://github.com/yusuphwickama
# The FOG Project - Copyright (C) 2007  Chuck Syperski & Jian Zhang

# colors
black=0; red=1; green=2; yellow=3; blue=4; magenta=5; cyan=6; white=7;

function throw_error {
  local errcode="$1"        # $1 - Error level 
  local message="$2"        # $2 - Human "readable" message
  local funct_linenum="$3"  # $3 - Function - LineNumber
  if [ -z "$funct_linenum" ]; then
	funct_linenum='(main?)'
  fi
  >&2 echo ""
  >&2 echo ""
  >&2 echo ""
  >&2 echo " =-=-=-=-= AN ERROR HAS BEEN THROWN ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  >&2 echo " Error code : ${errcode}"
  >&2 echo " Function : ${funct_linenum}"
  >&2 echo " Message : ${message}"
  >&2 echo ""
  >&2 echo " Script stopped. Please report this error to the developpers, with the console output."
  >&2 echo "  Thanks you !"
  >&2 echo " =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  do_log " =-=-=-=-= AN ERROR HAS BEEN THROWN ! -=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  do_log " Error code : ${errcode}"
  do_log " Function : ${funct_linenum}"
  do_log " Message : ${message}"
  do_log ""
  do_log " Script stopped. Please report this error to the developpers, with the console output."
  do_log "  Thanks you !"
  do_log " =-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-=-="
  exit ${errcode}
}

# prints a message with a given color.
function printclr {
	# $1 - Color code
	# $2 - Message
    tput setaf $1
    echo -ne "$2"
    tput sgr0
}

# reset the timer
function start_timer {
    SECONDS=0
}

# prints time elapsed since `start_timer`
function get_elapsed_time {
	duration=$SECONDS
	min=$(($duration/60))
	sec=$((duration % 60))
	[[ ${min} -eq 0 && ${sec} -gt 0 ]] && echo "$sec Seconds"
	[[ ${min} -gt 0 && ${sec} -gt 0 ]] && echo "${min}m ${sec}s"
	[[ ${min} -eq 0 && ${sec} -eq 0 ]] && echo "${sec}s"
}

# check if a dependency(package) is not present in the masterlist
function is_not_present {
    # $1 package name
    echo $(cat ${masterlist} | grep -ic "$1")
}

# add a dependecy(package) to the masterlist
function add_to_master_list {
    # $1 package name
    
	presr=$(is_not_present "$1")
	if [[ ${presr} -eq 0 ]]; then
		echo "$1" >> ${masterlist}
		echo "[-] Added $(printclr ${cyan} "$1") to dependency list"
	fi
}

# checks if the last command was successful
function check_if_successful {
    # $1 - Command exit code
    # $2 - Message

    if [[ $1 -eq 0 ]]; then
        # Command success
        tput cuu1
        echo "$2 $(printclr ${green} "[OK]")"
    else
        # Command failed
        tput cuu1
        echo "$2 $(printclr ${red} "[x]")"
    fi
}

# downloads package and dependencies
function download_packages {
    # $1 - File with packages listed

    # Append the main package to file
    echo "${package}" >> $1
    add_to_master_list ${package}
    # Iterate through the list and download each dependency
    while read -r line
    do
        name="$line"
        
        echo "[-] Downloading: $(printclr ${cyan} "$name")"
        # *** ICI débute le traitement de la conservation des paquets ***
        
		internal_keep_package="0"
		if [ ! -z "$pkgdl_keeppkg" ]; then
			oldIFS=$IFS
			IFS=';'
			for expr in $pkgdl_keeppkg
			do
					if [[ "$name" == *"$expr"* ]]; then
							internal_keep_package="1"
					fi
			done
			IFS=$oldIFS
		else
			internal_keep_package="1"
		fi
		if [ "$internal_keep_package" != "0" ]; then
			apt-get download "$name" ${apt_global_parameter} &> /dev/null

			if [[ $? -eq 0 ]]; then
				# Download success
				tput cuu1
				echo "$(tput setaf 7)[-] Downloading: $(printclr ${cyan} "$name") $(printclr ${green} "[OK]")"
			else
				# Download failed
				tput cuu1
				echo "$(tput setaf 7)[-] Downloading: $(printclr ${cyan} "$name") $(printclr ${red} "[x]")"
			fi
		else
			# Download failed
			tput cuu1
			echo "$(tput setaf 7)[-] Downloading: $(printclr ${cyan} "$name") $(printclr ${yellow} "[SKIP]")"
		fi

    done < "$1"
}

# convert deb compressed with zstd to xz compression
function convert_deb {
	shopt -s nullglob
	for f in *.deb
	do
		if [ -f "$f" ]; then
			IS_COMPRESSED_WITH_ZSTD=$(file "$f" |grep -icws "data compression zst")
			if [ "$IS_COMPRESSED_WITH_ZSTD" != "0" ]; then
				echo "Converting $f to xz format..."
				# https://unix.stackexchange.com/a/745467
				# TODO : Implement a function to test dpkg current version (https://tracker.debian.org/news/1407587/accepted-dpkg-12118-source-into-unstable/)
				#         & and don't convert packages if dpkg natively supports it.
				# Extract files from the archive
				ar x "$f"
				# Remove old archive (compressed with zstd)
				rm "$f"
				# Uncompress zstd files an re-compress them using xz
				zstd -d < control.tar.zst | xz -T0 > control.tar.xz
				zstd -d < data.tar.zst | xz -T0 > data.tar.xz
				# Re-create the Debian package
				ar -m -c -a sdsd "$f" debian-binary control.tar.xz data.tar.xz
				# Clean up
				rm debian-binary control.tar.xz data.tar.xz control.tar.zst data.tar.zst
				tput cuu1
				echo "$(tput setaf 7)[-] Conversion successful: $(printclr ${cyan} "$f") $(printclr ${green} "[OK]")"
			else
				echo "$(tput setaf 7)[-] Already in xz format: $(printclr ${cyan} "$f") $(printclr ${yellow} "[SKIP]")"
			fi
		else
            echo "$(tput setaf 7)[-] Error when accessing file : $(printclr ${cyan} "$f") $(printclr ${red} "[Conversion failed]")"
        fi
	done
	# unset it now
	shopt -u nullglob
}

# gets dependencies and append them to package list file (deb.list)
function get_dependencies {
    # $1 package name
    p1="$1"
    apt-cache depends ${p1} ${apt_global_parameter} | grep -v "<" | grep -w "Depends:" > "${p1}_${filename}"

    sed -i -e 's/[<>|:]//g' "${p1}_${filename}"
    sed -i -e 's/Depends//g' "${p1}_${filename}"
    sed -i -e 's/ //g' "${p1}_${filename}"

    # Local count
    lcount=$(apt-cache depends ${p1} ${apt_global_parameter}| grep -v "<" | grep -icw "Depends:")
    lit=0

    while [ ${lit} -lt ${lcount} ]
    do
        read -r line
        name="$line"
        # Add dependency if not in the master list.
        if [[ $(is_not_present "$name") -eq 0 ]]; then
            add_to_master_list ${name}
            get_dependencies ${name}
        fi
        # lit++
        lit=$(expr ${lit} + 1)
    done < "$1_$filename"
}

# gets dependencies for a package.
function get_global {
    # $1 package name

    echo "$(tput setaf 7)[-] Found $gcount dependencies for:$(tput setaf 6) $1 $(tput setaf 7)"
    # Store all dependencies to file.
    apt-cache depends $1 ${apt_global_parameter}| grep -v "<" | grep -w "Depends:" > "$1_$filename"
    # Clean file from unnecessary characters.
    sed -i -e 's/[<>|:]//g' "$1_$filename"
    sed -i -e 's/Depends//g' "$1_$filename"
    sed -i -e 's/ //g' "$1_$filename"

    while [ ${it} -lt ${gcount} ]
    do
        while read -r line
        do
            name="$line"
            round=$(expr ${it} + 1)

            if [[ $( echo ${name} | grep -v "<" | grep -c -w "Depends:") -lt 1 ]]; then
                if [[ $(is_not_present "$name") -eq 0 ]]; then
                    #echo "[-] Adding ${name} to masterlist"
                    add_to_master_list ${name}
                    get_dependencies ${name}
                fi
            fi
            it=$(expr ${it} + 1)
        done < "$1_$filename"
    done
}

# Pas de chemin de travail ? Définis le dossier courant !
[ -z "$sysbasepath" ] && sysbasepath="$PWD"
function get_current_path {
	# Fournis un point de base aux fichiers
	echo "$sysbasepath"
}

function get_basedir_sources {
	local bdir
	bdir="$(get_current_path)/sources"
	if [[ ! -d "$bdir" ]]; then
		mkdir "$bdir"
		[[ $? -ne 0 ]] && throw_error 1 "Unable to create folder $bdir" "${FUNCNAME} - (${LINENO})"
	fi
	echo "$bdir"
}

function get_basedir_temp {
	local bdir
	bdir="$(get_current_path)/temp"
	if [[ ! -d "$bdir" ]]; then
		mkdir "$bdir"
		[[ $? -ne 0 ]] && throw_error 1 "Unable to create folder $bdir" "${FUNCNAME} - (${LINENO})"
	fi
	echo "$bdir"
}

function get_basedir_rootfs {
	local bdir
	bdir="$(get_current_path)/rootfs"
	if [[ ! -d "$bdir" ]]; then
		mkdir "$bdir"
		[[ $? -ne 0 ]] && throw_error 1 "Unable to create folder $bdir" "${FUNCNAME} - (${LINENO})"
	fi
	echo "$bdir"
}

function get_basedir_project {
	local bdir
	bdir="$(get_current_path)/project"
	if [[ ! -d "$bdir" ]]; then
		mkdir "$bdir"
		[[ $? -ne 0 ]] && throw_error 1 "Unable to create folder $bdir" "${FUNCNAME} - (${LINENO})"
	fi
	echo "$bdir"
}

function get_basedir_release {
	local bdir
	bdir="$(get_current_path)/release"
	if [[ ! -d "$bdir" ]]; then
		mkdir "$bdir"
		[[ $? -ne 0 ]] && throw_error 1 "Unable to create folder $bdir" "${FUNCNAME} - (${LINENO})"
	fi
	echo "$bdir"
}


# Init apt repositories (from Ubuntu)
function init_apt_repo {
	
	# pkgdl_keeppkg       -> Search $needle in package dependancies. If $needle found, keep the package, else ignored. If $needle if empty, keep all packages.
	#                          needle separated with semicolon. Eg: "linux-image;linux-modules;signed"
	# export pkgdl_keeppkg="linux-image;linux-modules;signed"
	[ -z "$pkgdl_keeppkg" ] && pkgdl_keeppkg="linux-image;linux-modules;signed"
	
	urlRepo="$1"
	distroName="$2"
	depotName="$3"
	#http://cz.archive.ubuntu.com/ubuntu lunar main universe
	
	
	aptsrc=$(mktemp)
	chmod 0777 "$aptsrc"
	# trusted=yes because the system dont have GPG keys to authenticate the repository
	echo "deb [trusted=yes] ${urlRepo} ${distroName} ${depotName}" > "$aptsrc"
	# 'dialog' package is in the universe repository
	#echo 'deb [trusted=yes] http://cz.archive.ubuntu.com/ubuntu lunar main universe' >> "$aptsrc"
	apt_global_parameter='-o Dir::Etc::sourcelist='${aptsrc}' -o Dir::Etc::sourceparts="-" -o APT::Get::List-Cleanup="0"'
	# Update listing (IMPORTANT!)
	apt update $apt_global_parameter &> /dev/null
}

function download_a_package {
	# $1 - Name of package 
	zstd -V > /dev/null 2>&1
	if [ $? -ne "0" ]; then
		#echo "ERROR ! This patch requires zstd to be installed. (apt install zstd)"
		throw_error 3 "This patch requires zstd to be installed. (apt install zstd)" "${FUNCNAME} - (${LINENO})"
	fi	
	ar V > /dev/null 2>&1
	if [ $? -ne "0" ]; then
		#echo "ERROR ! This patch requires zstd to be installed. (apt install zstd)"
		throw_error 3 "This patch requires ar to be installed. (apt install binutils)" "${FUNCNAME} - (${LINENO})"
	fi		
	
	package="$1"
	filename="deb.list"
	fname="complete_deb.txt"
	gcount=$(apt-cache depends ${package} $apt_global_parameter| grep -v "<" | grep -icw "Depends:")
	it=0
	masterlist="dependencies_master_$RANDOM.mlist"
	
	if [[ ${gcount} -eq 0 ]]; then
		throw_error 2 "Package '$package' does not exist. Please verify sources/package name." "${FUNCNAME} - (${LINENO})"
	fi
	
	local tempdir
	local oldpwd
	tempdir="$(get_basedir_temp)/$package"
	
	if [[ -d "$tempdir" ]]; then
		if [[ ! -d "$(get_basedir_temp)" ]]; then
			throw_error 1 "temp folder does not exist." "${FUNCNAME} - (${LINENO})"
		fi
	
		rm -rf "$(get_basedir_temp)/$package"
		[[ $? -ne 0 ]] && throw_error 1 "Unable to clean folder $tempdir" "${FUNCNAME} - (${LINENO})"
	fi
	
	mkdir "$tempdir"
	[[ $? -ne 0 ]] && throw_error 1 "Unable to create temp folder $bdir" "${FUNCNAME} - (${LINENO})"
	
	oldpwd="$PWD"
	
	
	# cd to deb repositories
	cd "$(get_basedir_temp)/$package"
	
    # create masterlist file
    touch ${masterlist}

    # get dependencies for package and populate masterlist
    get_global "$package"

    # Sort and remove duplicates
    echo "" >> ${fname}
    sort *.list | uniq > ${fname}

    # read the masterlist to get child dependencies
    echo "[++] Checking for child dependencies"
    while read -r line
    do
        name="$line"
        # check if is package name
        if [[ $( echo ${name} | grep -v "<" | grep -icw "Depends:") -lt 1 ]]; then
            #echo "[$] Round $round:$(tput setaf 6) $name $(tput setaf 7)"
            pre=$(cat ${masterlist} | grep -ic "$name")

            #echo "Pret: $pre"
            if [ ${pre} -eq 0 ]; then
                get_dependencies ${name}
                add_to_master_list ${name}
            fi
        fi
        # it++
        it=$(expr ${it} + 1)
    done < "$fname"

    # delete all list files
    rm *.list

    # download packages from masterlist
    download_packages ${masterlist}

    # delete *.deb.list file
    rm ${fname}
    
    # ...delete also the masterlist, as we dont need.
    rm ${masterlist}
    
    # Finally, convert .deb to Debian "xz" format. (Only for Debian 11 or lower)
    convert_deb
    
    cd "$oldpwd"
}

function unpack_debs {
	# $1 - Name of original package
	
	local package
	local tempdir
	local oldpwd
	package="$1"
	tempdir="$(get_basedir_temp)/$package"
	
	if [[ ! -d "$(get_basedir_temp)" ]]; then
		throw_error 1 "temp folder does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	if [[ ! -d "$tempdir" ]]; then
		throw_error 1 "The temp folder for package $package does not exist." "${FUNCNAME} - (${LINENO})"
	fi
	
	oldpwd="$PWD"
	
	
	# cd to deb $package folder
	cd "$tempdir"
	if [[ ! -d "./out" ]]; then
		mkdir "./out"
		if [ $? -ne "0" ]; then
			throw_error 3 "Unable to create the out folder ($tempdir)" "${FUNCNAME} - (${LINENO})"
		fi	
	else
		rm -rf "./out"
		mkdir "./out"
		if [ $? -ne "0" ]; then
			throw_error 3 "Unable to create the out folder ($tempdir)" "${FUNCNAME} - (${LINENO})"
		fi	
	fi
	
	shopt -s nullglob
	for f in *.deb
	do
		if [ -f "$f" ]; then
			echo "[-] Unpacking $f ..."
			dpkg-deb -x "$f" ./out
			tput cuu1
			echo "$(tput setaf 7)[-] Unpacking successful: $(printclr ${cyan} "$f") $(printclr ${green} "[OK]")"
		else
            echo "$(tput setaf 7)[-] Error when accessing file : $(printclr ${cyan} "$f") $(printclr ${red} "[Unpacking failed]")"
        fi
	done
	# unset it now
	shopt -u nullglob
	cd "$oldpwd"
}

#function search_for_linux-image-generic {
	## This function is intended to search the linux image between all the .deb mess.
	## $1 : Base directory (eg: /opt/foguefi/tools/fogbuilder/temp/linux-image-generic/out)
	## $2 : Where the linux image is to be copied (eg: /opt/foguefi/tools/fogbuilder/out/linux-kernel)
	## 
	## $1 MUST BE a directory (generally the name of the package)
	## $2 MUST BE a destination file. If file already exist, it will be destroyed.
	
	#file -v > /dev/null 2>&1
	#if [ $? -ne "0" ]; then
		##echo "ERROR ! This patch requires zstd to be installed. (apt install zstd)"
		#throw_error 3 "This patch requires file to be installed. (apt install file)" "${FUNCNAME} - (${LINENO})"
	#fi		
	
	#local tempdir
	#local package
	#local destinationfile
	#local f
	#local result
	#result="0"
	#destinationfile="$2"
	
	
	
	#package="$1"
	#tempdir="$(get_basedir_temp)/$package/out"
	
	#if [[ ! -d "$(get_basedir_temp)" ]]; then
		#throw_error 1 "temp folder does not exist." "${FUNCNAME} - (${LINENO})"
	#fi	
	
	#if [[ ! -d "$tempdir" ]]; then
		#throw_error 1 "The temp folder for package $package does not exist." "${FUNCNAME} - (${LINENO})"
	#fi	
	
	
	#if [ ! -d "$tempdir" ]; then
		#throw_error 1 "The searching folder $tempdir does not exist." "${FUNCNAME} - (${LINENO})"
	#fi
	#if [ -z "$destinationfile" ]; then
		#throw_error 4 "The destination file variable is empty." "${FUNCNAME} - (${LINENO})"
	#fi
	#if [ -f "$destinationfile" ]; then
		#rm "$destinationfile" || throw_error 5 "Unable to delete file $destinationfile ." "${FUNCNAME} - (${LINENO})"
	#fi
		
	## =-=-=-=-=-= BADLANDS - Hacky stuff =-=-=-=-=-=
	##
	## After extraction, i must find with "file", the string "Linux kernel" && "boot executable" into the description,
	##   inside a file into the "<OUT Folder>/boot" directory.
	##
	## By default, i assume the linux-image-generic is signed.
	##
	
	#for f in $(find "${tempdir}/boot" -name '*'); 
	#do	
		#result=$(file -b "${f}" |grep -iws "Linux kernel"| grep -icws "boot executable")
		#if [[ "$result" -eq 1 ]]; then
			#cp "${f}" "$destinationfile"
			#break
		#fi
	#done
	
	#if [[ "$result" -eq 0 ]]; then
		#echo "*** Start of find"
		#find "$tempdir"
		#echo "****"
		#for f in $(find "${tempdir}/boot" -name '*'); 
		#do	
			#result=$(file -b "${f}")
			#echo " File ${f} --> ${result}"
		#done
		#throw_error 1 "Unable to find Linux kernel into deb output package. Please contact the devlopper with the console output. Thank you!" "${FUNCNAME} - (${LINENO})"
	#fi
#}

function unpack_debs {
	# $1 - Name of original package
	
	local package
	local tempdir
	local oldpwd
	package="$1"
	tempdir="$(get_basedir_temp)/$package"
	
	if [[ ! -d "$(get_basedir_temp)" ]]; then
		throw_error 1 "temp folder does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	if [[ ! -d "$tempdir" ]]; then
		throw_error 1 "The temp folder for package $package does not exist." "${FUNCNAME} - (${LINENO})"
	fi
	
	oldpwd="$PWD"
	
	
	# cd to deb $package folder
	cd "$tempdir"
	if [[ ! -d "./out" ]]; then
		mkdir "./out"
		if [ $? -ne "0" ]; then
			throw_error 3 "Unable to create the out folder ($tempdir)" "${FUNCNAME} - (${LINENO})"
		fi	
	else
		rm -rf "./out"
		mkdir "./out"
		if [ $? -ne "0" ]; then
			throw_error 3 "Unable to create the out folder ($tempdir)" "${FUNCNAME} - (${LINENO})"
		fi	
	fi
	
	shopt -s nullglob
	for f in *.deb
	do
		if [ -f "$f" ]; then
			echo "[-] Unpacking $f ..."
			dpkg-deb -x "$f" ./out
			tput cuu1
			echo "$(tput setaf 7)[-] Unpacking successful: $(printclr ${cyan} "$f") $(printclr ${green} "[OK]")"
		else
            echo "$(tput setaf 7)[-] Error when accessing file : $(printclr ${cyan} "$f") $(printclr ${red} "[Unpacking failed]")"
        fi
	done
	# unset it now
	shopt -u nullglob
	cd "$oldpwd"
}

PATH_LinuxKernel="" # Initialize the path/file with empty string. If found, this variable is populated with path/file.
function search_for_linux-image-generic {
	# This function is intended to search the linux image between all the .deb mess.
	# $1 : Base directory (eg: /opt/foguefi/tools/fogbuilder/temp/linux-image-generic/out)
	########### $2 : Where the linux image is to be copied (eg: /opt/foguefi/tools/fogbuilder/out/linux-kernel)
	# 
	# $1 MUST BE a directory (generally the name of the package)
	########### $2 MUST BE a destination file. If file already exist, it will be destroyed.
	
	file -v > /dev/null 2>&1
	if [ $? -ne "0" ]; then
		throw_error 3 "This patch requires file to be installed. (apt install file)" "${FUNCNAME} - (${LINENO})"
	fi		
	
	local tempdir
	local package
	local destinationfile
	local f
	local result
	result="0"
	#destinationfile="$2"
	
	
	
	package="$1"
	tempdir="$(get_basedir_temp)/$package/out"
	
	if [[ ! -d "$(get_basedir_temp)" ]]; then
		throw_error 1 "temp folder does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	if [[ ! -d "$tempdir" ]]; then
		throw_error 1 "The temp folder for package $package does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	
	if [ ! -d "$tempdir" ]; then
		throw_error 1 "The searching folder $tempdir does not exist." "${FUNCNAME} - (${LINENO})"
	fi
	#if [ -z "$destinationfile" ]; then
		#throw_error 4 "The destination file variable is empty." "${FUNCNAME} - (${LINENO})"
	#fi
	#if [ -f "$destinationfile" ]; then
		#rm "$destinationfile" || throw_error 5 "Unable to delete file $destinationfile ." "${FUNCNAME} - (${LINENO})"
	#fi
		
	# =-=-=-=-=-= BADLANDS - Hacky stuff =-=-=-=-=-=
	#
	# After extraction, i must find with "file", the string "Linux kernel" && "boot executable" into the description,
	#   inside a file into the "<OUT Folder>/boot" directory.
	#
	# By default, i assume the linux-image-generic is signed.
	#
	
	for f in $(find "${tempdir}/boot" -name '*'); 
	do	
		result=$(file -b "${f}" |grep -iws "Linux kernel"| grep -icws "boot executable")
		if [[ "$result" -eq 1 ]]; then
			#cp "${f}" "$destinationfile" # TODO : Remove this
			PATH_LinuxKernel="${f}"
			return 0 # By default 0 mean no error (=found)
			break
		fi
	done
	
	return 1
	
	#if [[ "$result" -eq 0 ]]; then
		#echo "*** Start of find"
		#find "$tempdir"
		#echo "****"
		#for f in $(find "${tempdir}/boot" -name '*'); 
		#do	
			#result=$(file -b "${f}")
			#echo " File ${f} --> ${result}"
		#done
		#throw_error 1 "Unable to find Linux kernel into deb output package. Please contact the devlopper with the console output. Thank you!" "${FUNCNAME} - (${LINENO})"
	#fi
}

PATH_ShimX64="" # Initialize the path/file with empty string. If found, this variable is populated with path/file.
function search_for_shimx64 {
	# This function is intended to search "shimx64.efi.*sign" between all the .deb mess.
	# $1 : Base directory (eg: /opt/foguefi/tools/fogbuilder/temp/linux-image-generic/out)
	######## $2 : Where the linux image is to be copied (eg: /opt/foguefi/tools/fogbuilder/out/linux-kernel)
	# 
	# $1 MUST BE a directory (generally the name of the package)
	######## $2 MUST BE a destination file. If file already exist, it will be destroyed.
	
	file -v > /dev/null 2>&1
	if [ $? -ne "0" ]; then
		throw_error 3 "This patch requires file to be installed. (apt install file)" "${FUNCNAME} - (${LINENO})"
	fi		
	
	local tempdir
	local package
	#local destinationfile
	local f
	local result
	result='0'
	#destinationfile="$2"
	
	
	
	package="$1"
	tempdir="$(get_basedir_temp)/$package/out"
	
	if [[ ! -d "$(get_basedir_temp)" ]]; then
		throw_error 1 "temp folder does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	if [[ ! -d "$tempdir" ]]; then
		throw_error 1 "The temp folder for package $package does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	
	if [ ! -d "$tempdir" ]; then
		throw_error 1 "The searching folder $tempdir does not exist." "${FUNCNAME} - (${LINENO})"
	fi
	#if [ -z "$destinationfile" ]; then
		#throw_error 4 "The destination file variable is empty." "${FUNCNAME} - (${LINENO})"
	#fi
	#if [ -f "$destinationfile" ]; then
		#rm "$destinationfile" || throw_error 5 "Unable to delete file $destinationfile ." "${FUNCNAME} - (${LINENO})"
	#fi
		
	# =-=-=-=-=-= BADLANDS - Hacky stuff =-=-=-=-=-=
	#
	# After extraction, i must find with "file", the file "shimx64.efi.signed*",
	#   into the "<OUT Folder>" directory.
	#
	#

	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'shimx64.efi.signed'); # Original filename
		do	
			result='1'
			#cp "${f}" "$destinationfile" # TODO : Remove this
			PATH_ShimX64="${f}"
			return 0
			break
		done
	fi
	
	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'shimx64.efi.signed.latest');  # New filename, signed by Micr0soft, containt Canonical signature
		do	
			result='1'
			#cp "${f}" "$destinationfile" # TODO : Remove this
			PATH_ShimX64="${f}"
			return 0
			break
		done
	fi
	
	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'shimx64.efi.signed.previous'); # New filename, old signature, signed by Micr0soft, containt Canonical signature
		do	
			result='1'
			#cp "${f}" "$destinationfile" # TODO : Remove this
			PATH_ShimX64="${f}"
			return 0
			break
		done
	fi
		
	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'shimx64.efi.dualsigned'); # New filename, old signature, signed by Micr0soft, containt Canonical signature
		do	
			result='1'
			#cp "${f}" "$destinationfile" # TODO : Remove this
			PATH_ShimX64="${f}"
			return 0
			break
		done
	fi
	
	return 1
	#if [[ "$result" -eq 0 ]]; then
		#echo "*** Start of find"
		#find "$tempdir"
		#echo "****"
		#for f in $(find "${tempdir}" -name '*'); 
		#do	
			#result=$(file -b "${f}")
			#echo " File ${f} --> ${result}"
		#done
		#throw_error 1 "Unable to find ShimX64.efi.* into deb output package. Please contact the devlopper with the console output. Thank you!" "${FUNCNAME} - (${LINENO})"
	#fi
}

PATH_GrubNETX64="" # Initialize the path/file with empty string. If found, this variable is populated with path/file.
function search_for_grubnetx64 {
	# This function is intended to search "shimx64.efi.*sign" between all the .deb mess.
	# $1 : Base directory (eg: /opt/foguefi/tools/fogbuilder/temp/linux-image-generic/out)
	############# $2 : Where the linux image is to be copied (eg: /opt/foguefi/tools/fogbuilder/out/linux-kernel)
	# 
	# $1 MUST BE a directory (generally the name of the package)
	############ $2 MUST BE a destination file. If file already exist, it will be destroyed.
	
	file -v > /dev/null 2>&1
	if [ $? -ne "0" ]; then
		throw_error 3 "This patch requires file to be installed. (apt install file)" "${FUNCNAME} - (${LINENO})"
	fi		
	
	local tempdir
	local package
	#local destinationfile
	local f
	local result
	result='0'
	#destinationfile="$2"
	
	
	
	package="$1"
	tempdir="$(get_basedir_temp)/$package/out"
	
	if [[ ! -d "$(get_basedir_temp)" ]]; then
		throw_error 1 "temp folder does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	if [[ ! -d "$tempdir" ]]; then
		throw_error 1 "The temp folder for package $package does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	
	if [ ! -d "$tempdir" ]; then
		throw_error 1 "The searching folder $tempdir does not exist." "${FUNCNAME} - (${LINENO})"
	fi
	#if [ -z "$destinationfile" ]; then
		#throw_error 4 "The destination file variable is empty." "${FUNCNAME} - (${LINENO})"
	#fi
	#if [ -f "$destinationfile" ]; then
		#rm "$destinationfile" || throw_error 5 "Unable to delete file $destinationfile ." "${FUNCNAME} - (${LINENO})"
	#fi
		
	# =-=-=-=-=-= BADLANDS - Hacky stuff =-=-=-=-=-=
	#
	# After extraction, i must find with "file", the file "grubnetx64*,
	#   into the "<OUT Folder>" directory.
	#
	# By default, i assume the linux-image-generic is signed.
	#

	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'grubnetx64.efi.signed'); # Original filename
		do	
			result='1'
			#cp "${f}" "$destinationfile" # TODO : Remove this
			PATH_GrubNETX64="${f}"
			return 0
			break
		done
	fi
	
	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'grubnetx64');  # New filename, signed by Micr0soft, containt Canonical signature
		do	
			result='1'
			#cp "${f}" "$destinationfile" # TODO : Remove this
			PATH_GrubNETX64="${f}"
			return 0
			break
		done
	fi
	
	return 1
	#if [[ "$result" -eq 0 ]]; then
		#echo "*** Start of find"
		#find "$tempdir"
		#echo "****"
		#for f in $(find "${tempdir}" -name '*'); 
		#do	
			#result=$(file -b "${f}")
			#echo " File ${f} --> ${result}"
		#done
		#throw_error 1 "Unable to find Grubnetx64.efi.* into deb output package. Please contact the devlopper with the console output. Thank you!" "${FUNCNAME} - (${LINENO})"
	#fi
}

PATH_LinuxModules="" # Initialize the path/file with empty string. If found, this variable is populated with path/file.
function search_for_linux-modules {
	# This function is intended to search the base linux modules folder between all the .deb mess.
	# $1 : Base directory (eg: /opt/foguefi/tools/fogbuilder/temp/linux-image-generic/out)
	############# $2 : Where the linux image is to be copied (eg: /opt/foguefi/tools/fogbuilder/out/linux-kernel)
	# 
	# $1 MUST BE a directory (generally the name of the package)
	############# $2 MUST BE a destination file. If file already exist, it will be destroyed.
	
	file -v > /dev/null 2>&1
	if [ $? -ne "0" ]; then
		throw_error 3 "This patch requires file to be installed. (apt install file)" "${FUNCNAME} - (${LINENO})"
	fi		
	
	local tempdir
	local package
	#local destinationfile
	local f
	local result
	result='0'
	#destinationfile="$2"
	
	
	
	package="$1"
	tempdir="$(get_basedir_temp)/$package/out"
	
	if [[ ! -d "$(get_basedir_temp)" ]]; then
		throw_error 1 "temp folder does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	if [[ ! -d "$tempdir" ]]; then
		throw_error 1 "The temp folder for package $package does not exist." "${FUNCNAME} - (${LINENO})"
	fi	
	
	
	if [ ! -d "$tempdir" ]; then
		throw_error 1 "The searching folder $tempdir does not exist." "${FUNCNAME} - (${LINENO})"
	fi
	#if [ -z "$destinationfile" ]; then
		#throw_error 4 "The destination file variable is empty." "${FUNCNAME} - (${LINENO})"
	#fi
	#if [ -f "$destinationfile" ]; then
		#rm "$destinationfile" || throw_error 5 "Unable to delete file $destinationfile ." "${FUNCNAME} - (${LINENO})"
	#fi
		
	# =-=-=-=-=-= BADLANDS - Hacky stuff =-=-=-=-=-=
	#
	# After extraction, i must find with "file", the file "grubnetx64*,
	#   into the "<OUT Folder>" directory.
	#
	# By default, i assume the linux-image-generic is signed.
	#

	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'modules.order' -print -quit); # Original filename
		do	
			result='1'
			f=$(echo ${f} | xargs dirname) # Because we want the root folder, not the file itself.
			#cp "${f}" "$destinationfile" # TODO : Remove this
			PATH_LinuxModules="${f}"
			return 0
			break
		done
	fi
	
	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'modules.builtin.modinfo' -print -quit); # Original filename
		do	
			result='1'
			f=$(echo ${f} | xargs dirname) # Because we want the root folder, not the file itself.
			#cp "${f}" "$destinationfile" # TODO ; Remove this
			PATH_LinuxModules="${f}"
			return 0
			break
		done
	fi
	
	if [[ "$result" -eq 0 ]]; then
		for f in $(find "${tempdir}" -name 'modules.builtin' -print -quit); # Original filename
		do	
			result='1'
			f=$(echo ${f} | xargs dirname) # Because we want the root folder, not the file itself.
			#cp "${f}" "$destinationfile" # TODO ; Remove this
			PATH_LinuxModules="${f}"
			return 0
			break
		done
	fi	
	
	return 1
	#if [[ "$result" -eq 0 ]]; then
		#echo "*** Start of find"
		#find "$tempdir"
		#echo "****"
		#for f in $(find "${tempdir}" -name '*'); 
		#do	
			#result=$(file -b "${f}")
			#echo " File ${f} --> ${result}"
		#done
		#throw_error 1 "Unable to find Grubnetx64.efi.* into deb output package. Please contact the devlopper with the console output. Thank you!" "${FUNCNAME} - (${LINENO})"
	#fi
}

function simulateLdconfig {
	# This function simulates ldconfig
	# I don't know how to configure multiples libaries folders without this tool. (03/07/2023)
	
	#chemin="/opt/foguefi/tools/fogbuilder/rootfs/etc/ld.so.conf.d"

	shopt -s nullglob
	for f in "$(get_basedir_rootfs)/etc/ld.so.conf.d/"*
	do
			if [ -f "$f" ]; then
					do_log "simulateLdconfig : Config file found $f"
					# $f est un fichier de config (.conf)
					lefichier=$(cat "$f")
					oldifs="$IFS"
					IFS=$'\n'
					for line in $lefichier; do
							# Nettoie $line des espaces au debut
							line=$(echo "$line" | sed 's/ //g')
							# Extrait le premier caractere dans $lineS
							firstchar="${line:0:1}"
							if [ ! "$firstchar" == "#" ]; then
									# On a une entree qui n'est pas un commentaire.
									# Si le dossier existe, on fait la sauce...
									if [ -d "$(get_basedir_rootfs)/$line" ]; then
											#echo "mv $line --> ROOTFS / lib"
											do_log "simulateLdconfig : Move folder content $(get_basedir_rootfs)/$line to $(get_basedir_rootfs)/lib"
											mv -v "$(get_basedir_rootfs)/${line}"/* "$(get_basedir_rootfs)/lib" >> "$do_logfile" 2>&1
									fi
							fi
					done
					IFS="$oldifs"
			else
					do_log "simulateLdconfig : $f is not a file"
			fi
	done
	# unset it now
	shopt -u nullglob
	return 0
}


function buildUSBBoot {
	# Oh ! Dirty !  ;
	source /opt/fog/.fogsettings
	if [[ -z "${docroot}${webroot}" ]]; then
		throw_error 101 "No FOG installation has been detected on this server." "${FUNCNAME} - (${LINENO})"
	fi

	mkfs.vfat --help > /dev/null 2>&1
	if [ $? -ne "0" ]; then
		throw_error 102 "This patch requires dosfstools to be installed. (apt install dosfstools)" "${FUNCNAME} - (${LINENO})"
	fi

	# Extract initversion from the rootfs folder
	initversion=$(grep "export initversion" $(get_basedir_rootfs)/usr/share/fog/lib/funcs.sh | cut -d'=' -f2)

	if [ -z "$initversion" ]; then initversion="Unknown"; fi

	mkdir -v "$(get_basedir_temp)/usbmntpoint" >> "$do_logfile" 2>&1

	dd if=/dev/zero of="$(get_basedir_temp)/usbboot.img" bs=1M count=256 >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 115 "Error when creating a file with DD. Space: $(df)" "${FUNCNAME} - (${LINENO})"
	fi	
	mkfs.vfat -v -F 32 -n FOGBOOT "$(get_basedir_temp)/usbboot.img" >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 116 "Error when creating a FAT32 filesystem." "${FUNCNAME} - (${LINENO})"
	fi
	
	# Monte-là
	mount -v "$(get_basedir_temp)/usbboot.img" "$(get_basedir_temp)/usbmntpoint" >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 117 "Unable to mount newly created usbboot.img" "${FUNCNAME} - (${LINENO})"
	fi
	
	# Prepare les dossiers
	mkdir -vp "$(get_basedir_temp)/usbmntpoint/EFI/boot" >> "$do_logfile" 2>&1
	mkdir -vp "$(get_basedir_temp)/usbmntpoint/boot/grub" >> "$do_logfile" 2>&1

	# Copie les fichiers d'amorçage
	# Copie shimx64.efi
	if [ ! -f "$PATH_ShimX64" ] # This is a FILE
	then
		throw_error 103 "Unable to find shimX64.efi.* into deb output package." "${FUNCNAME} - (${LINENO})"
	fi
	cp -v "$PATH_ShimX64" "$(get_basedir_temp)/usbmntpoint/EFI/boot/bootx64.efi" >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 104 "Error when copying SHIM loader. (${PATH_GrubNETX64})" "${FUNCNAME} - (${LINENO})"
	fi	
	# Copie grubnetx64.efi
	if [ ! -f "$PATH_GrubNETX64" ] # This is a FILE
	then
		throw_error 105 "Unable to find grubnetx64.efi.* into deb output package." "${FUNCNAME} - (${LINENO})"
	fi	
	cp -v "$PATH_GrubNETX64" "$(get_basedir_temp)/usbmntpoint/EFI/boot/grubx64.efi" >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 106 "Error when copying GRUB bootloader. (${PATH_GrubNETX64})" "${FUNCNAME} - (${LINENO})"
	fi
	
	# MAGIC : ../../src/tftpboot/grub/
	if [ -f "$(get_current_path)/../../src/tftpboot/grub/grub.cfg" ]; then
		# Copie le dossier de la conf de Grub provenant du serveur (si déjà installé)
		#cp -rv "$(get_current_path)/../../src/tftpboot/grub" "$(get_basedir_temp)/usbmntpoint/boot/" >> "$do_logfile" 2>&1
		#if [ $? -ne "0" ]; then
		#	throw_error 107 "Error when copying the GRUB configuration files." "${FUNCNAME} - (${LINENO})"
		#fi
		# Copie le dossier de la conf de Grub (déjà installé)
		cp -rv "$(get_current_path)/../../src/tftpboot/grub" "$(get_basedir_temp)/usbmntpoint/" >> "$do_logfile" 2>&1
		if [ $? -ne "0" ]; then
			throw_error 108 "Error when copying the GRUB configuration files." "${FUNCNAME} - (${LINENO})"
		fi
	else
		throw_error 109 "Unable to find Grub configuration file into projects files." "${FUNCNAME} - (${LINENO})"
	fi
	
	# Copie le kernel Linux
	if [ ! -f "$PATH_LinuxKernel" ] # This is a FILE
	then
		throw_error 110 "Unable to find Linux kernel file into deb output package." "${FUNCNAME} - (${LINENO})"
	fi
	cp -v "$PATH_LinuxKernel" "$(get_basedir_temp)/usbmntpoint/linux_kernel" >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 111 "Error when copying the Linux kernel. ($(get_basedir_release)/${linux_kernel})" "${FUNCNAME} - (${LINENO})"
	fi
	# Copie le cpio
	if [ ! -f "$(get_basedir_release)/${cpio_release_filename}" ] # This is a FILE
	then
		throw_error 112 "Unable to find the freshly created cpio. ($(get_basedir_release)/${cpio_release_filename})" "${FUNCNAME} - (${LINENO})"
	fi
	cp -v "$(get_basedir_release)/${cpio_release_filename}" "$(get_basedir_temp)/usbmntpoint/fog_uefi.cpio.xz" >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 113 "Error when copying the freshly created cpio. ($(get_basedir_release)/${cpio_release_filename})" "${FUNCNAME} - (${LINENO})"
	fi
	
	MonFichier=$(mktemp)
	echo '# ~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~'  > "$MonFichier"
	echo '# This file has been modified by BuildFogUEFI.sh'                                >> "$MonFichier"
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
	cat "${MonFichier}" "$(get_basedir_temp)/usbmntpoint/grub/grub.cfg" > "$(get_basedir_temp)/usbmntpoint/grub/grub_PATCHED.cfg"
	mv -v "$(get_basedir_temp)/usbmntpoint/grub/grub.cfg" "$(get_basedir_temp)/usbmntpoint/grub/grub.cfg_ORIGINAL" >> "$do_logfile" 2>&1
	mv -v "$(get_basedir_temp)/usbmntpoint/grub/grub_PATCHED.cfg" "$(get_basedir_temp)/usbmntpoint/grub/grub.cfg" >> "$do_logfile" 2>&1
	rm -v "$MonFichier" >> "$do_logfile" 2>&1
	umount -v "$(get_basedir_temp)/usbmntpoint/" >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 114 "Error when unmounting the USB Boot image." "${FUNCNAME} - (${LINENO})"
	fi	
	
	# Déplace l'image fraîchement créé
	mv -v "$(get_basedir_temp)/usbboot.img" "$(get_basedir_release)/usbboot.img" >> "$do_logfile" 2>&1
	if [ $? -ne "0" ]; then
		throw_error 115 "Error when moving $(get_basedir_temp)/usbboot.img to $(get_basedir_release)/usbboot.img" "${FUNCNAME} - (${LINENO})"
	fi
}

internal_task=""
dots() {
    local pad=$(printf "%0.1s" "."{1..60})
    printf " * %s%*.*s" "$1" 0 $((60-${#1})) "$pad"
    do_log "MSG : $1"
    internal_task="${1}"
    return 0
}

msg_finished() {
	echo "$1"
	do_log "TASK FINISHED '$1' (Task: ${internal_task})"
	internal_task=''
	return 0
}

do_logfile="$(get_current_path)/installer.log"
do_log() {
	echo "$(date +"%d.%m.%Y %H:%M:%S") $1" >> "$do_logfile"
}

### End function declarations
