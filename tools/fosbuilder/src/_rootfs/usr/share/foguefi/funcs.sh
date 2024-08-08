#!/bin/bash
#
# @category FOGStubmenu
# @package  FOGUefi
# @author   Alexandre Botzung <alexandre.botzung@grandest.fr>
# @license  http://opensource.org/licenses/gpl-3.0 GPLv3
# @link     https://fogproject.org
#
# S98_menuFogGUI
# Menu de démarrage alternatif pour FOG stub (version 1.5.9+)
#   Permets de démarrer FOG stub avec Secure Boot activée.
# NOTE: Initialement, ce n'était qu'un hack perso.
#
# Nouvelles variables (programmable au bootcmd): 

# Compte de connexion : 
# Nom d'utilisateur : FOG_username=foo
# Mot de passe (en clair...) : FOG_password=bar
#
# Auto multicast : 
# Programmation de la tâche multicast : FOG_multicastSessionName=toto123456
#
# Téléchargement auto d'une image :
# Programmation de la tâche download : FOG_imageID=42



# Exemple : 
# -----> Pour automatiquement joindre un session multicast avec le nom pc_compta : 
#
# Démarrer le kernel avec les paramètres suivants : 
#  root=/dev/ram0 rw ramdisk_size=275000 consoleblank=0 nvme_core.default_ps_max_latency_us=0 \
#    nomodeset keymap=fr
#    web=http://<IP DE VOTRE SERVEUR FOG>/fog storage=<IP DE VOTRE SERVEUR FOG/STORAGE>:/images/ \
#    storageip=<IP DE VOTRE SERVEUR FOG/STORAGE> \
#    menutype=askmc FOG_username=<COMPTE EXISTANT SUR LE SERVEUR FOG> FOG_password=<Mot de passe> \
#    FOG_multicastSessionName=pc_compta
#
# -----> Pour automatiquement télécharger l'image ID 42 : 
#
# Démarrer le kernel avec les paramètres suivants : 
#  root=/dev/ram0 rw ramdisk_size=275000 consoleblank=0 nvme_core.default_ps_max_latency_us=0 \
#    nomodeset keymap=fr
#    web=http://<IP DE VOTRE SERVEUR FOG>/fog storage=<IP DE VOTRE SERVEUR FOG/STORAGE>:/images/ \
#    storageip=<IP DE VOTRE SERVEUR FOG/STORAGE> \
#    menutype=down dologin=yes \
#    FOG_username=<COMPTE EXISTANT SUR LE SERVEUR FOG> FOG_password=<Mot de passe> \
#    FOG_imageID=42

# Source les fonctions internes de FOG
. /usr/share/fog/lib/funcs.sh

# Constante : Nom de l'ordinateur si inconnu
C_UNKNOWN_COMPUTER='***Unknown***'
# Constante : Version de l'API de FOGUefi
C_FOGUEFI_APIver='20240806'

# By default, override by login_fog
[[ -z $FOG_islogged ]] && FOG_islogged=0

# By default, FOG isnt relauched (after manreg for example)
[[ -z $relaunchFog ]] && relaunchFog=0

# Configure a menu timeout delay (in seconds) (default : 900 seconds / 15 minutes)
[[ -z $FOG_DialogTimeout ]] && FOG_DialogTimeout=900

sysuuid=$(dmidecode -s system-uuid)
sysuuid=${sysuuid,,}
mac=$(getMACAddresses)

getIPAddresses() {
    read ipaddr <<< $(/sbin/ip -4 -o addr | awk -F'([ /])+' '/global/ {print $4}' | tr '[:space:]' '|' | sed -e 's/^[|]//g' -e 's/[|]$//g')
    echo $ipaddr
}

init_backtitle() {
    # Initialise la backtitle par défaut
    if [[ -z "$defautboottype" ]]; then
        defautboottype='Legacy'
        [[ -n $(dmesg | grep "Secure boot disabled") ]] && defautboottype='UEFI'
        [[ -n $(dmesg | grep "Secure boot enabled") ]] && defautboottype='UEFI Secure boot'
    fi
        
    if [[ -z $(cat /proc/cmdline | grep 'FOG_rebranding_banner=') ]]; then
        # La bannière n'a PAS été forcée depuis la CMD ? On remets la 'legacy' en place !
        FOG_rebranding_banner='Alex BOTZUNG && The FOG Project community'
    fi
    if [[ -z $(cat /proc/cmdline | grep 'FOG_rebranding_software=') ]]; then
        # La bannière n'a PAS été forcée depuis la CMD ? On remets la 'legacy' en place !
        IPClient=$(getIPAddresses)
        FOG_rebranding_software="FOGUefi Stub $initversion - $FOG_rebranding_banner [$(hostname -s) - $IPClient]"
    fi
}

login_fog () {
    # La procédure renvoie 0 si la connexion est réussie, 1 sinon.
    #
    # $FOG_username et $FOG_password sont peuplés si le code de retour = 0, les variables sont vidés sinon.
    # Le drapeau $FOG_islogged est peuplée en fonction de la connexion (=1 si REUSSI, sinon 0)
    # $FOG_rebranding_banner peut être utilisée pour changer la bannière de connexion.
    #
    # Utilise "checkcredentials.php" de FOG.
    # /!\ Heres be Dragons /!\
    #
    # Alex 03072022 : Un timeout a été ajoutée au popups de connexion, permettant une execution non bloquante en cas de remastérisation "inattendue"
    # Alex 25072024 : Ajout d'un process pour limiter le nombre de tentatives de connexion (par défaut : illimitée)
    
    clear

    [[ -z "$FOG_login_maxRetries" ]] && FOG_login_maxRetries=0
    [[ -z "$FOG_DialogTimeout" ]] && FOG_DialogTimeout=20
	regex_number='^[0-9]+$'
	if ! [[ "$FOG_login_maxRetries" =~ $regex_number ]] ; then
	   FOG_login_maxRetries=0
	fi
	
	weblogin=''
    webpass=''
    _internal_maxretries=0
	
    if [[ "$FOG_islogged" == "1" ]]; then # Est-on déjà connecté ? Si oui, pas la peine de refaire une demande d'auth.
        return 0
	fi
	
    weblogin="$FOG_username"
    webpass="$FOG_password"
    _internal_maxretries="$FOG_login_maxRetries"
    FOG_islogged=0 # Drapeau indiquant si l'on est correctement connecté au serveur FOG
    
    uuid=$(dmidecode -s system-uuid)
    uuid=${uuid,,}
    mac=$(getMACAddresses)
    
    while true; do
        if [[ -n "$weblogin" && -n "$webpass" ]]; then
            # Si on a déjà le login et le mot de passe, j'essaye une authentification
            # Cela permettera d'automatiser des connexions via le boot par clé usb ("FOG Self-Service")
	
			_tempmac=$(echo "$mac" | tr -d '\012' | base64)
            _templogin=$(echo "$weblogin" | tr -d '\012' | base64)
            _temppass=$(echo "$webpass" | tr -d '\012' | base64)
            DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=${mac}&username=${_templogin}&password=${_temppass}" "${web}service/checkcredentials.php?op=FOGUEFI_login_fog&mac=${_tempmac}" -A '')
            _templogin=''
            _temppass=''

            if [[ $DoCurl == *"#!ok"* ]]; then
				### Username/password valid -- Authentication succeed.
                FOG_username=$weblogin
                FOG_password=$webpass
                weblogin=''
			    webpass=''
                FOG_islogged=1
                clear
                return 0
            else
				# Incorrect Username/Password, destroy variables
				FOG_username=''
				FOG_password=''
				FOG_islogged=0
				old_DIALOGRC="$DIALOGRC"
				export DIALOGRC="/root/dialog_rouge"
				dialog \
					--backtitle "$FOG_rebranding_software" \
					--title "ERROR" \
					--timeout "$FOG_DialogTimeout" \
					--ok-label "OK" \
					--msgbox "The username or password is incorrect." 6 47
				export DIALOGRC="$old_DIALOGRC"
				[[ "$_internal_maxretries" -gt 0 ]] && _internal_maxretries=$(( _internal_maxretries - 1 ))
            fi
        fi

		if [[ "$_internal_maxretries" -eq 0 ]] && [[ "$FOG_login_maxRetries" -ne 0 ]]; then
			# Max retries triggered, quit now.
            clear
			return 1
		fi

		if [[ "$_internal_maxretries" -ne 0 ]]; then
			_internal_title="Login to FOG ($_internal_maxretries tries left)"
		else
			_internal_title="Login to FOG"
		fi

        exec 3>&1
        BoiteDeDialogue=$(timeout --foreground "$FOG_DialogTimeout" dialog \
        --backtitle "$FOG_rebranding_software" \
        --title "$_internal_title" \
        --insecure \
        --timeout "$FOG_DialogTimeout" \
        --cancel-label "Cancel" \
        --mixedform \
        "Enter your FOG credential :" 10 53 0 \
        "Username: " 1 1 "" 1 20 27 64 0 \
        "Password:"  2 1 "" 2 20 27 64 1 \
        2>&1 1>&3)
		exit_status=$?
		exec 3>&-

        if [[ $exit_status != "0" ]]; then
            # Here, "Cancel" *or* timeout has been selected
            weblogin=''
            webpass=''
            FOG_username=''
            FOG_password=''
            FOG_islogged=0
            clear
            return 1
        fi

        IFS=$'\n'
        mapfile -t COMPTE <<< "$BoiteDeDialogue"

        weblogin="${COMPTE[0]}"
        webpass="${COMPTE[1]}"

        if [[ -z "$webpass" ]]; then
			exec 3>&1
			BoiteDeDialogue=$(timeout --foreground "$FOG_DialogTimeout" dialog \
				--backtitle "$FOG_rebranding_software" \
				--title "$_internal_title" \
				--insecure \
				--timeout "$FOG_DialogTimeout" \
				--cancel-label "Cancel" \
				--mixedform \
				"Enter your password :" 10 53 0 \
				"Password:"  1 1 "" 1 20 27 64 1 \
			2>&1 1>&3)
			exit_status=$?
			exec 3>&-
            if [[ $exit_status != "0" ]]; then
                # Here, "Cancel" *or* timeout has been selected
                weblogin=''
                webpass=''
                FOG_username=''
                FOG_password=''
                FOG_islogged=0
                clear
                return 1
            fi

            IFS=$'\n'
            mapfile -t COMPTE <<< "$BoiteDeDialogue"
            webpass="${COMPTE[0]}"
        fi
    done
}

login_or_reboot () {
    # On doit être loguée, force une connexion . . .
    fog_compName            # Récupère le nom enregistrée de la machine
    login_fog                # Tente une connexion. Si FOG_username && FOG_password sont déjà peuplés, tente une connexion silencieuse.
    retval=$?
    verifTaches                # Vérifie que le serveur FOG nous a pas donnés une tâche . . .
    verifTachesFLAG=$?
    if [[ $verifTachesFLAG == 1 ]]; then
        do_fog                # Une tâche est programmée -> je l'exécute.
    fi
    if [[ $retval == 1 ]]; then
        do_exit
    fi
}

verifTaches () {
    # Vérifie toujours les tâches en cours, sauf si la variable osid est déjà peuplée.
    #if [[ $boottype == usb && ! -z $web ]]; then
    if [[ -z $osid ]]; then


        base64mac=$(echo $mac | base64)
        token=$(curl -Lks --data "mac=$base64mac" "${web}status/hostgetkey.php")
        curl -Lks -o /tmp/hinfo.txt --data "sysuuid=${sysuuid}&mac=$mac&hosttoken=${token}" "${web}service/hostinfo.php" -A ''

        # Validates hinfo.txt
        if [[ -f /tmp/hinfo.txt ]]; then
            dummy=$(cat /tmp/hinfo.txt | grep export)
            # Not a export ? Delete the file
            [[ "$dummy" != *"export"* ]] && rm /tmp/hinfo.txt
        fi

        # Valide le fichier krnl
        if [[ -f /tmp/hinfo_foguefi.txt ]]; then
            dummy=$(cat /tmp/hinfo_foguefi.txt | grep export)
            if [[ "$dummy" != *"export"* ]]; then
                rm /tmp/hinfo_foguefi.txt
            fi    
        fi
        [[ -f /tmp/hinfo.txt ]] && . /tmp/hinfo.txt
        [[ -f /tmp/hinfo_foguefi.txt ]] && . /tmp/hinfo_foguefi.txt
    fi

    # TABLE DE VERITEE :
    # $type        $mode        $osid            $FLAG
    #
    #  xxx       -               -              non 
    #   -         xxx          -               OUI (tache locale) 
    #   -        -           xxx             non
    #  xxx       -           xxx              OUI (tache serveur ou programmée)
    #  xxx       xxx         xxx              OUI (tache serveur ou programmée spéciale)
    #

    if [[ -n $type && -n $osid ]]; then
        # Si $type est définie {up/down} && que $osid est définie (peut importe $mode), il y a quelque-chose à faire
        #echo "Tache programmée (SERVEUR/PROGRAMMEE)"
        FLAG_scheduledTask=1
        return 1 # 1 = Tache programmée
    fi
    
    if [[ -z $type && -n $mode ]]; then
        # Si $mode est définie {clamav, manreg...} && que $type n'est pas définie, il y a un mode à traîter
        #echo "Tache programmée (MODE)"
        FLAG_scheduledTask=2
        return 1 # 1 = Tache programmée
    fi
    
    return 0
}

fog_compName () {
    ######## Donne le nom du pc à l'aide du serveur FOG ####
    # Renvoie $C_UNKNOWN_COMPUTER si l'ordinateur n'existe pas, "REGPENDING:<NomClient>" si le client n'est pas encore approuvée.
    uuid=$(dmidecode -s system-uuid)
    uuid=${sysuuid,,}
    mac=$(getMACAddresses)
    DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&getFOGClientName=1" "${web}service/grub/grub.php" -A '')

    result=$(echo -e "$DoCurl" | cut -f1 -d'|')
    FOGcomputerName=$(echo -e "$DoCurl" | cut -f2 -d'|')

    if [[ "$result" == "#!ok" ]]; then
        FOGcomputerName="$(echo -e "$DoCurl" | cut -f2 -d'|')"
    elif [[ "$result" == "#!ok" ]]; then
        FOGcomputerName="REGPENDING:$(echo -e "$DoCurl" | cut -f2 -d'|')"
    else
        FOGcomputerName="$C_UNKNOWN_COMPUTER"
    fi
    result=""; DoCurl=""
}

check_APIversion () {
    # Test if grubbootmenu.class.php API is okay to use.
    uuid=$(dmidecode -s system-uuid)
    uuid=${sysuuid,,}
    mac=$(getMACAddresses)
    DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&getFOGUefiAPIVersion=1" "${web}service/grub/grub.php" -A '')

    result=$(echo -e "$DoCurl" | cut -f1 -d'|')
    SYST_FOGUEFI_APIver='19700101'

    if [[ "$result" == "#!ok" ]]; then
        SYST_FOGUEFI_APIver="$(echo -e "$DoCurl" | cut -f2 -d'|')"
    fi
    result=""; DoCurl=""
    if [[ "$SYST_FOGUEFI_APIver" == "$C_FOGUEFI_APIver" ]]; then
        return 0
    fi
    
    [[ -r "/tmp/trigger.foguefi_api_error" ]] && . /tmp/trigger.foguefi_api_error

    clear
    displayBanner
    _colBG=41;_colFG=97
    echo -e "\033[${_colFG};${_colBG}m██████████████████████████████████████████████████████████████████████████████\033[0m"
    echo -e "\033[${_colFG};${_colBG}m█                                                                            █\033[0m"
    echo -e "\033[${_colFG};${_colBG}m█     FATAL ERROR : The FOGUefi FOG API is incompatible with this client.    █\033[0m"
    echo -e "\033[${_colFG};${_colBG}m█             (FOGUefi API version:${SYST_FOGUEFI_APIver} Client API:${C_FOGUEFI_APIver})             █\033[0m"
    echo -e "\033[${_colFG};${_colBG}m█                 You must update your FOGUefi installation.                 █\033[0m"
    echo -e "\033[${_colFG};${_colBG}m█                                                                            █\033[0m"
    echo -e "\033[${_colFG};${_colBG}m█                      Computer will reboot in 1 minute                      █\033[0m"
    echo -e "\033[${_colFG};${_colBG}m█                                                                            █\033[0m"
    echo -e "\033[${_colFG};${_colBG}m██████████████████████████████████████████████████████████████████████████████\033[0m"
    echo ""
    sleep 60
    reboot -f # Reboot car impossible de continuer correctement
}

do_fog () {
    # Ce process simule l'opération de FOG, pour une tâche détecté (programmée alors que le STUB était déjà lancée.)
    # Comme les variable sont normalement définies au moment du boot, je ne peut pas laisser le script se dérouler 
    #    (à cause du contexte des exports, détruit si l'on quitte l'exécution de ce fichier.)
    # ICI, je récupère les variables (hinfo + hinfo_foguefi) et je lance FOG.
    # On ne quitte (normalement) jamais cette routine.
    
    # Destruction des modes / types (sachant qu'on va de toute façon les récupérer)
    export -n mode
    export -n type
    
    # Je vérifie si j'ai une tâche en attente. Je charge hinfo.txt && hinfo_foguefi.txt
    verifTaches    
    verifTachesFLAG=$?
    if [[ $verifTachesFLAG == 0 ]]; then
        # Etrange ; on a pas de tâche programmée. Je quitte la routine. 
        return 1
    fi
    # Il existe une tâche FOG, détruit les creds par mesure de sécurité.
    FOG_islogged=0
    FOG_username=''
    FOG_password=''
    weblogin=''
    webpass=''
    
    if [[ -n "$mode" || -n "$type" ]]; then
        # Une tâche "sur le pouce est programmée. Je prend le rôle de FOG (pour le passage des exports)
        
        if [[ $relaunchFog == 2 ]]; then #Si l'on relance FOG
            if [[ "$mode" == *"reg"* ]]; then # Et que la tâche actuelle est toujours *reg*
                return 0 # C'est que l'on a rien d'autre à faire.
            fi
        fi

        # Il y a peut-être une tâche type "down" ochestrée par le serveur. Je relance do_fog après fog() pour 
        if [[ -n "$mode" ]]; then
            if [[ "$mode" == *"reg"* ]]; then
                relaunchFog=$((relaunchFog=relaunchFog+1))
            fi
        fi
        # ---------------------
        
        
        [[ ! -h /dev/fd ]] && ln -s /proc/self/fd /dev/fd
        [[ ! -h /dev/stdin ]] && ln -s /proc/self/fd/0 /dev/stdin
        [[ ! -h /dev/stdout ]] && ln -s /proc/self/fd/1 /dev/stdout
        [[ ! -h /dev/stderr ]] && ln -s /proc/self/fd/2 /dev/stderr
        if [[ $mdraid == true ]]; then
            mdadm --auto-detect
            mdadm --assemble --scan
            mdadm --incremental --run --scan
        fi    
        case $isdebug in
            [Yy][Ee][Ss]|[Yy])
                fog.debug
                ;;
            *)
                fog
                if [[ $relaunchFog == 1 ]]; then
                    # Tâche manreg/autoreg détectée, je relance do_fog. hinfo.txt sera peuplée du down. (si présent)
                    relaunchFog=2
                    # Détruit la tâche actuelle pour accueillir la nouvelle tâche
                    mode=''
                    export -n mode
                    type=''
                    export -n type
                    do_fog
                fi
                do_exit
                ;;
        esac
    fi
}

do_exit() {
    # Quitte le FOG Stub / debug
    
    # FIXME : Fonction encore utilisée ? 

    exit 123
}

PROCESS_SelectDownloadImage() {
    # Cette partie propose de choisir une image à remastériser. Elle crée elle-même la fausse tâche "false tasking".
    
    # Vérifie que le serveur FOG nous a pas donnés une tâche . . .
    #verifTaches                
    #verifTachesFLAG=$?
    #if [[ $verifTachesFLAG == 1 ]]; then
    #    do_fog                # Une tâche est programmée -> je l'exécute.
    #fi

    # Est-on connecté à FOG ? Si non, -> LOGIN
    if [[ $FOG_islogged != 1 ]]; then
        login_fog
        retval=$?
        if [[ $retval == 1 ]]; then
            # Login échouée ? AU REVOIR ! 
            return 0
        fi
    fi
    
    image_id=0
    if [[ -n "$FOG_imageID" ]]; then
        #echo "FOG_imageID présent, je fait la vérif..."
        
        # On a déjà une image dans la ligne de commande. 
        #  je vérifie qu'elle est valide. Si non, j'efface la variable.
        DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&qihost=1&username=${FOG_username}&password=${FOG_password}" "${web}service/grub/grub.php" -A '')
        
        i=0
        export DIALOGRC=
        if [[ "$DoCurl" != *'***!IMAGE-HEADER!***'* ]]; then # Problème générale
            export DIALOGRC="/root/dialog_rouge"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "ERROR" \
                --timeout $FOG_DialogTimeout \
                --msgbox "Host is not valid, host has no image assigned, or there are no images defined on the server. (1)" 10 45
            export DIALOGRC=
            return 1
        fi
        if [[ "$DoCurl" != *"imgitem"* ]]; then # Aucune image trouvée
            export DIALOGRC="/root/dialog_rouge"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "ERROR" \
                --timeout $FOG_DialogTimeout \
                --msgbox "There are no images defined on the server.", 6 45
            export DIALOGRC=
            return 1
        fi        
        
        # 2. Je découpe les lignes en tableau pour le script
        # https://stackoverflow.com/questions/7103531/how-to-get-the-part-of-a-file-after-the-first-line-that-matches-a-regular-expres
        # https://stackoverflow.com/questions/37173774/how-to-read-columns-from-csv-file-into-array-in-bash
        IFS=''
        imageItem=()
        imagePath=()
        imageName=()
        imageID=()
        array=()
        
        while IFS=',' read -ra array; do
            imageItem+=("${array[0]}")
            imagePath+=("${array[1]}")
            imageName+=("${array[2]}")
            imageID+=("ID# ${array[3]}")
        done <<< "$(echo $DoCurl | sed -e '1d')"

        # imageItem = {imgitem / imgdefault}
        imageParDefault_ID='0'
        for arrayIndex in "${!imageID[@]}"; do
            FOG_imageID_temp=$(echo "${imageID[$arrayIndex]}" | sed -r 's/[^0-9]*//g')
            if [[ "$FOG_imageID_temp" == "$FOG_imageID" ]]; then
                # On a une correspondance d'image ? Cool ! 
                image_id="$FOG_imageID"
                image_id=$(echo "$image_id" | sed -r 's/[^0-9]*//g')
            fi
        done
        if [[ "$image_id" == 0 ]]; then
            # On a pas trouvé l'image dansFOGcomputerName la BDD FOG, on efface le terme pour afficher le menu
            unset image_id
            unset FOG_imageID
        fi
    fi

    if [[ -z "$FOG_imageID" ]]; then
        # ~~~~~~~~~~~~~~~~~~ LISTING DES IMAGES DU SERVEUR ~~~~~~~~~~~~~~~~
        # 1. Je récupère la liste des images du serveurs (via grub.php)
        
        DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&qihost=1&username=${FOG_username}&password=${FOG_password}" "${web}service/grub/grub.php" -A '')
        
        i=0
        if [[ "$DoCurl" != *'***!IMAGE-HEADER!***'* ]]; then
            export DIALOGRC="/root/dialog_rouge"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "ERROR" \
                --timeout $FOG_DialogTimeout \
                --msgbox "Host is not valid, host has no image assigned, or there are no images defined on the server. (2)" 10 45
            export DIALOGRC=
            return 1
        fi

        if [[ "$DoCurl" != *"imgitem"* ]]; then # Aucune image trouvée
            export DIALOGRC="/root/dialog_rouge"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "ERROR" \
                --timeout $FOG_DialogTimeout \
                --msgbox "There are no images defined on the server.'," 6 45
            export DIALOGRC=
            return 1
        fi        

        # 2. Je découpe les lignes en tableau pour le script
        # https://stackoverflow.com/questions/7103531/how-to-get-the-part-of-a-file-after-the-first-line-that-matches-a-regular-expres
        # https://stackoverflow.com/questions/37173774/how-to-read-columns-from-csv-file-into-array-in-bash
        IFS=''
        imageItem=()
        imagePath=()
        imageName=()
        imageID=()
        array=()
        
        while IFS=',' read -ra array; do
            imageItem+=("${array[0]}")
            imagePath+=("${array[1]}")
            imageName+=("${array[2]}")
            imageID+=("ID# ${array[3]}")
        done <<< "$(echo $DoCurl | sed -e '1d')"

        # imageItem = {imgitem / imgdefault}
        imageParDefault_ID='0'
        for arrayIndex in "${!imageItem[@]}"; do
            if [[ "${imageItem[$arrayIndex]}" == "imgdefault" ]]; then
                # On a une image par défaut ? COOL!
                imageParDefault_ID="${imageID[$arrayIndex]}"
                imageParDefault_NOM="${imageName[$arrayIndex]}"
            fi
        done

        LeTas=''
        if [[ "$imageParDefault_ID" == '0' ]]; then
            # Pas d'image par défaut, je fait le listing de base
            
            for arrayIndex in "${!imageItem[@]}"; do                                                # Scanne le tableau....
                if [[ "${imageItem[$arrayIndex]}" == "imgitem" ]]; then                            # à la recherche de "imgitem"....
                    LeTas="${LeTas}\"${imageID[$arrayIndex]}\" \"${imageName[$arrayIndex]}\" "  # On trouve des trucs ? Ajoute les sur le tas !
                fi
            done
        else
            # Une image est par défaut, je l'ajoute en priorité sur le tas
            LeTas="${LeTas}\"${imageParDefault_ID}\" \"* ${imageParDefault_NOM}\" "                    # Définis l'image par défaut
            for arrayIndex in "${!imageItem[@]}"; do                                                    # Scanne le tableau....
                if [[ "${imageItem[$arrayIndex]}" == "imgitem" ]]; then                                # à la recherche de "imgitem"....
                    if [[ "${imageID[$arrayIndex]}" != "$imageParDefault_ID" ]]; then                # AYANT un autre ID que l'image par défaut.
                        LeTas="${LeTas}\"${imageID[$arrayIndex]}\" \"${imageName[$arrayIndex]}\" "    # On trouve des trucs ? Ajoute les sur le tas !
                    fi
                fi
            done        
        fi

        IFS=''
        BoiteDeDialogue="dialog \
        --backtitle \"$FOG_rebranding_software\" \
        --title \"List of available images :\" \
        --clear \
        --timeout $FOG_DialogTimeout \
        --menu \"\" 15 53 9 \
        $LeTas"
        exec 3>&1
        selection=$(eval $BoiteDeDialogue 2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        if [[ $exit_status != "0" ]]; then
            return 0 
        fi
        image_id=$(echo "$selection" | sed -r 's/[^0-9]*//g')
    fi

    # ICI, on est censé avoir l'ID de l'image que l'on va remastériser. On lance une programmation pour avoir une "false-tasking".
    # Phase 3 ; programmation de l'image

    DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&qihost=1&imageID=$image_id&username=${FOG_username}&password=${FOG_password}" "${web}service/grub/grub.php" -A '')

    verifTaches
    verifTachesFLAG=$?

    # OLD: param menuAccess 1 (si PC enregistrée)

    if [[ "$(hostname -s)" != "$C_UNKNOWN_COMPUTER" && $verifTachesFLAG == "0" ]]; then
        export DIALOGRC="/root/dialog_rouge"
        dialog \
            --backtitle "$FOG_rebranding_software" \
            --title "!!! FATAL INTERNAL ERROR !!!" \
            --ok-label "Ok" \
            --timeout $FOG_DialogTimeout \
            --msgbox "An error occurred during the programming of the image deployment. I can't continue. (CompName=$(hostname -s)) -> $DoCurl" 12 47
        export DIALOGRC=
        return 0
    fi
    if [[ $(hostname -s) == "$C_UNKNOWN_COMPUTER" ]]; then
        # PC *PAS PRESENT* dans Fog, je dois parser les lignes pour les refiler à FOG
        
        # PASSE 1 : Récupère les infos du kernel (linux ...)
        IFS=$'\n'
        for line in $DoCurl; do
            if [[ $line == "linux "* ]]; then
                ligneKRNL=$line
            fi
        done
        if [[ $ligneKRNL != "linux "* ]]; then
            export DIALOGRC="/root/dialog_rouge"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "!!! FATAL INTERNAL ERROR !!!" \
                --ok-label "Oh no !" \
                --timeout $FOG_DialogTimeout \
                --msgbox "I cant find the string 'linux' ; I can't go on. [PROCESS_SelectDownloadImage -> PCUnknown -> $DoCurl ]" 7 47
            export DIALOGRC=
            return 0
        fi
        
        # PASSE 2 : Découpe les args du kernel en infos pertinentes pour FOG
        IFS=" "
        [[ -f /tmp/hinfo_foguefi.txt ]] && rm /tmp/hinfo_foguefi.txt
        for line in $ligneKRNL; do
            if [[ $line == *"="* ]]; then
                cle=$(awk -F'='  '{print $1}' <<< $line)
                valeur=$(awk -F'='  '{print $2}' <<< $line)
                echo "[[ -z \$$cle ]] && export $cle='$valeur'" >> /tmp/hinfo_foguefi.txt
            fi
        done    
        
        # Patch ridicule pour sortir les variables en EXPORT.
        # Mais cela ne fonctionne pas, car ce script (enfant) de S98MenuFog (parent) ne peut pas modifier l'environnement des parents. 
        # Donc les parents DOIVENT CHARGER les exports et si ils sont peuplés, la seulement lancer fog. (selon debug/NotDebug)
        [[ -f /tmp/hinfo_foguefi.txt ]] && . /tmp/hinfo_foguefi.txt >/dev/null 2>&1

    fi
    
    #do_fog # Part du principe qu'une tâche est attendue. Dans le cas contraire, on quitte la routine.
}

PROCESS_Memtest() {
    [[ -z "$(hostname -s)" ]] && fog_compName
    #Malheuresement, Memtest86+ (5.0+) est désormais dans une licence propriétaire.
    # Il existe une solution de repli à l'aide de l'utilitaire memtester (présent aussi dans Clonezilla).

    # Une partie du code ci-dessous à été réalisée par Steven Shiau <steven _at_ clonezilla org>
    # License: GPL 

    displayBanner
    
    if [[ -z "${memtest_testrounds}" ]]; then
        #Par défaut, fait 10 tests de la mémoire vive.
        memtest_testrounds=10
    fi
    
    echo "Free and used memory in the system (Mbytes):"
    echo "***********"
    free -m
    echo "***********"
    if [ -n "$mem_size" ]; then
      avail_mem_MB="$mem_size"
    else
      avail_mem_MB="$(LC_ALL=C free -m | grep -i "^Mem:" | awk -F" " '{print $NF}')"
      avail_mem_MB=$(( avail_mem_MB - 16 )) # Keep 16 MiB for Linux kernel
    fi
    run_cmd="memtester ${avail_mem_MB}M $memtest_testrounds"
    # P A T C H - Diable OOM_KILLER (!!DANGER!!)
    echo 2 > /proc/sys/vm/overcommit_memory
    echo "Run: $run_cmd"
    eval "$run_cmd"
    rc=$?
    if [ "$rc" -eq 1 ]; then
      echo "Everything works properly about the memory in this system."
      # Un délai est ajoutée pour rebooter en cas de réussite.
      read -t "$FOG_DialogTimeout" -p "Press [enter] to reboot . . . "
      return 0
    fi
    displayBanner
    echo -e "\033[97;41m████████████████████████████████████████████████████████\033[0m"
    echo -e "\033[97;41m█████████ A MEMORY FAILURE HAS BEEN DETECTED ! █████████\033[0m"
    echo -e "\033[97;41m████████████████████████████████████████████████████████\033[0m"
    # Pas de délai pour une mémoire défaillante.
    echo -e "Press [\033[97enter\033[0m] to reboot . . . "
    read -p "Press [enter] to reboot . . . "
    return 1
}

PROCESS_XOrg() {
    # Passe en mode graphique ICI
    # - Ne reviens JAMAIS de cette routine. -
    # Car : flemme de gérer un orchestrateur de tâches lançant soit Xorg+Xterm avec dtach / soit dtach seul.
    #       && surtout qu'il n'est pas possible de quitter une session dtach simplement.
    #
    #
    # Petit rappel pour unionfs : 
    #
    # lowerdir ; C'est le dossier contenant les fichiers "maitre" / qui ne changent jamais. ("Golden disc")
    # upperdir ; C'est le dossier qui va contenir toutes les modifications réalisés (ajout/modification/supression)
    # workdir  ; C'est le dossier tampon nécessaire à unionfs.
    # NOTE : Il peut exister plusieurs lowerdir. En cas de conflit, c'est le dernier "lowerdir" qui "gagne".

    clear

    # Passe la main à un script externe, détruit les creds par mesure de sécurité.
    FOG_islogged=0
    FOG_username=''
    FOG_password=''
    weblogin=''
    webpass=''


    # Récupère la mémoire vive disponible
    avail_mem_MB="$(LC_ALL=C free -m | grep -i "^Mem:" | awk -F" " '{print $NF}')"

    # 2 Gio de RAM ? C'est MORT. On va OOM à coup sûr !
    if (( avail_mem_MB < 2048 )); then
        export DIALOGRC="/root/dialog_rouge"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "ERROR - OOM" \
                --timeout $FOG_DialogTimeout \
                --ok-label "OK" \
                --msgbox "Insufficient available memory to run GUI. (${avail_mem_MB} < 2 Gb)" 6 47
        export DIALOGRC=
        return 0
    fi

    # NOTE : fog.mount est hotpatchée au début de l'execution de ce script
    /bin/fog.mount 'xserver'

    # Si tout est ok, le partage est mappée (handleError sinon).
    if [[ -f '/images/!xserver/fog.xserver' ]]; then 
        # -> Le script est présent, je fait quelques calculs de sécurité...

        # Récupère la taille totale du dossier
        Xfoldersize_MB=$(du -m '/images/!xserver/' | awk '{print $1}')
        # Mémoire nécessaire = 
        #                       Taille dossier SQUASHFS                   (Car on copie le fichier en RAM)
        #                       + (Taille dossier SQUASHFS * 2)           (Espace "cache" pour l'unionFS ; squashfs décompressé ; environ 2x-4x)
        #                       + 512                                     (+ 512 Mio pour laisser un peu de place pour le système)

        RequiredMem=$((Xfoldersize_MB + (Xfoldersize_MB*2) + 512))
        FinalFreeMem=$((avail_mem_MB - RequiredMem))
        if (( FinalFreeMem > 0 )); then
            echo "Free memory ........ $FinalFreeMem M"
        else
            umount /images
            MissingMem=$((FinalFreeMem * -1))
            export DIALOGRC="/root/dialog_rouge"
                dialog \
                    --backtitle "$FOG_rebranding_software" \
                    --title "ERROR - OOM" \
                    --timeout $FOG_DialogTimeout \
                    --ok-label "OK" \
                    --msgbox "Insufficient available memory to run GUI.\n\nRequired : $RequiredMem M\nAvailable: $avail_mem_MB M\nMissing : $MissingMem M" 9 47
            export DIALOGRC=
            return 0
        fi
        # Bon, ici on devrait être plutôt bon pour lancer le script d'init.

        # Crée un flag pour empécher une réexecution du script.
        echo "CHROOT READY" > /tmp/chroot_started
        mkdir /run/dtach >/dev/null 2>&1
        # Détruis un autre flag (recréé dans le chroot XOrg) indiquant si XOrg est prêt ou pas.
        rm /run/dtach/terminal_ready
        # Prépare le nouveau terminal à la session X
        SCRIPT=$(readlink -f $0)
        # Respawn ce script. (il patientra que /run/dtach/terminal_ready soit présent)
        dtach -n /run/dtach/fogterminal -Ez "$SCRIPT"
        
        if [[ -d '/images/!xserver' ]]; then
            # Le dossier de destination existe ? Supprime-le ! 
            rm -rf '/tmp/!xserver'
        fi
        # Copie les fichiers avec rsync
        rsync -avz --progress '/images/!xserver' '/tmp'

        # On a fini avec le répertoire source, démonte le point de montage
        umount /images

        # Prépare le script d'initialisation
        chmod +x '/tmp/!xserver/fog.xserver'

        oldpwd=$(pwd)
        . '/tmp/!xserver/fog.xserver'
        cd $oldpwd
        
        # Fin de l'exécution du script "Xorg". Je récupère la main, et si cela échoue, reviens sur un message d'erreur "panic"
        if [[ -d '/images/!xserver' ]]; then
            # Le dossier existe ? Supprime-le ! 
            rm -rf '/tmp/!xserver'
        fi        
        # Signale qu'on récupère l'exécution de FOG
        rm /tmp/chroot_started
        touch /run/dtach/terminal_ready

        dtach -a /run/dtach/fogterminal -Ez

        # Panic sync & reboot
        cd /
        sync 
        for n in /dev/sd* ; do umount $n ; done
        for n in /dev/mmc* ; do umount $n ; done

        reboot -f
    else
        export DIALOGRC="/root/dialog_jaune"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "WARNING" \
                --timeout $FOG_DialogTimeout \
                --ok-label "OK" \
                --msgbox 'File "/images/!xserver/fog.xserver" not found. Unable to start GUI' 6 47
        export DIALOGRC=
    fi
}

PROCESS_JointMulticast() {
    # Cette partie nous propose de nous connecter à une tâche multicast.
    # Varariables globales : FOG_multicastSessionName (nom de la session multicast)
    
    # Est-on connecté à FOG ? Si non, -> LOGIN
    if [[ $FOG_islogged != 1 ]]; then
        login_fog
        retval=$?
        if [[ $retval == 1 ]]; then
            # Login échouée ? AU REVOIR ! 
            return 0
        fi
    fi

    while true; do    
        # Vérifie que le serveur FOG nous a pas donnés une tâche . . .
        verifTaches                
        verifTachesFLAG=$?
        if [[ $verifTachesFLAG == 1 ]]; then
            #do_fog                # Une tâche est programmée -> je l'exécute.
            exit 123 # Une tâche est programmée ; je quitte le menu :)
        fi

        if [[ -z "$FOG_multicastSessionName" ]]; then
            # La variable n'existe pas ? Je demande le nom de la tâche multicast !
            
            BoiteDeDialogue="timeout --foreground "$FOG_DialogTimeout" dialog \
            --backtitle \"$FOG_rebranding_software\" \
            --title \"Join multicast session\" 
            --insecure \
            --timeout \"$FOG_DialogTimeout\" \
            --cancel-label \"Cancel\" \
            --mixedform \
            \"Enter multicast session name :\" 10 53 0 \
            \"Session name:\"  1 1 \"\" 1 20 27 64 0"

            exec 3>&1
            selection=$(eval $BoiteDeDialogue 2>&1 1>&3)
            exit_status=$?
            exec 3>&-
            if [[ $exit_status != "0" ]]; then
                FOG_multicastSessionName='' # On quitte ? PAS DE NOM !
                return 1
            fi

            IFS=$'\n'
            DUMMY=($selection)
            FOG_multicastSessionName="${DUMMY[0]}"
        fi
    
        # Réalise la query. Le fonctionnement est similaire à la programmation d'une image.
        # Dans le cas d'un PC non enregistrée ; on reçoit la tâche sous la forme d'une entrée de démarrage GRUB.
        # Dans le cas d'un PC enregistrée, la fonction verifTaches le verra (type && osid peuplée).
        DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&sessname=${FOG_multicastSessionName}&username=${FOG_username}&password=${FOG_password}" "${web}service/grub/grub.php" -A '')    
        
        verifTaches
        verifTachesFLAG=$?

        # OLD: param menuAccess 1 (si PC enregistrée)
        if [[ "$DoCurl" != *"ERRNOFOUND"* ]]; then
            if [[ "$(hostname -s)" != "$C_UNKNOWN_COMPUTER" && $verifTachesFLAG == "0" ]]; then
                export DIALOGRC="/root/dialog_rouge"
                dialog \
                    --backtitle "$FOG_rebranding_software" \
                    --title "!!! FATAL INTERNAL ERROR !!!" \
                    --ok-label "Ok" \
                    --timeout $FOG_DialogTimeout \
                    --msgbox "An error occurred during the programming of the image deployment. FOGUefi cannot continue. -> $DoCurl" 7 47
                export DIALOGRC=
                return 0
            fi
            if [[ "$(hostname -s)" == "$C_UNKNOWN_COMPUTER" ]]; then
                # PC *PAS PRESENT* dans Fog, je dois parser les lignes pour les refiler à FOG
                
                # PASSE 1 : Récupère les infos du kernel (linux ...)
                IFS=$'\n'
                for line in $DoCurl; do
                    if [[ $line == "linux "* ]]; then
                        ligneKRNL=$line
                    fi
                done
                if [[ $ligneKRNL != "linux "* ]]; then
                    export DIALOGRC="/root/dialog_rouge"
                    dialog \
                        --backtitle "$FOG_rebranding_software" \
                        --title "!!! FATAL INTERNAL ERROR !!!" \
                        --ok-label "Oh no !" \
                        --timeout $FOG_DialogTimeout \
                        --msgbox "I cant find the string 'linux' ; I can't go on. [PROCESS_JointMulticast -> PCUnknown -> $DoCurl ]" 7 47
                    export DIALOGRC=
                    return 0
                fi
                
                # PASSE 2 : Découpe les args du kernel en infos pertinentes pour FOG
                IFS=" "
                [[ -f /tmp/hinfo_foguefi.txt ]] && rm /tmp/hinfo_foguefi.txt
                for line in $ligneKRNL; do
                    if [[ $line == *"="* ]]; then
                        cle=$(awk -F'='  '{print $1}' <<< $line)
                        valeur=$(awk -F'='  '{print $2}' <<< $line)
                        echo "[[ -z \$$cle ]] && export $cle='$valeur'" >> /tmp/hinfo_foguefi.txt
                    fi
                done    
                
                # Patch ridicule pour sortir les variables en EXPORT.
                # Mais cela ne fonctionne pas, car ce script (enfant) de S98MenuFog (parent) ne peut pas modifier l'environnement des parents. 
                # Donc les parents DOIVENT CHARGER les exports et si ils sont peuplés, la seulement lancer fog. (selon debug/NotDebug)
                [[ -f /tmp/hinfo_foguefi.txt ]] && . /tmp/hinfo_foguefi.txt >/dev/null 2>&1

            fi
        else
            FOG_multicastSessionName='' # Mauvais nom ; je l'efface
            export DIALOGRC="/root/dialog_rouge"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "ERROR - Multicast session not found" \
                --ok-label "Ok" \
                --timeout $FOG_DialogTimeout \
                --msgbox "ERROR ; No session found with that name." 7 47
            export DIALOGRC=
        fi
            
    done
}

PROCESS_DeleteCurrentHost() {
    # Fonction pour supprimer l'hote actuel du serveur FOG.
    # Renvoie 1 si l'hote à été supprimée, 0 sinon.
    
    # Est-on connecté à FOG ? Si non, -> LOGIN
    if [[ $FOG_islogged != 1 ]]; then
        login_fog
        retval=$?
        if [[ $retval == 1 ]]; then
            # Login échouée ? AU REVOIR ! 
            return 0
        fi
    fi

    # Query le nom actuel du pc
    #fog_compName
    
    # Vérifie que le serveur FOG nous a pas donnés une tâche . . .
    #verifTaches                
    #verifTachesFLAG=$?
    #if [[ $verifTachesFLAG == 1 ]]; then
    #    do_fog                # Une tâche est programmée -> je l'exécute.
    #fi
    
    if [[ "$(hostname -s)" != "$C_UNKNOWN_COMPUTER" ]]; then
        exec 3>&1
        export DIALOGRC="/root/dialog_jaune"
        selection=$(dialog \
            --backtitle "$FOG_rebranding_software" \
            --title "WARNING" \
            --defaultno \
            --timeout $FOG_DialogTimeout \
            --yesno "Would you like to delete this host ? [$(hostname -s)]" 6 47 \
            2>&1 1>&3)
        exit_status=$?
        export DIALOGRC=
        exec 3>&-

        if [[ "$exit_status" == "0" ]]; then
            # Je supprime la machine
            # TODO FIXME : Faille de sécuritée : Il est possible de crafter une requête dans le navigateur web pour 
            #              détruire une machine du serveur FOG /!\. Confirmée avec la version DEV du 01082022

            DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&delconf=1&username=${FOG_username}&password=${FOG_password}" "${web}service/grub/grub.php" -A '')    
        
            if [[ "$DoCurl" == *"OKSUCCESS"* ]]; then
                init_backtitle        # Le nom du poste à changée. La backtitle possiblement possible. Je mets à jout tout ça.
                dialog \
                    --backtitle "$FOG_rebranding_software" \
                    --title "Success" \
                    --ok-label "Ok" \
                    --timeout $FOG_DialogTimeout \
                    --msgbox "Host deleted successfully" 7 47
                    
                return 1
            else
                export DIALOGRC="/root/dialog_rouge"
                dialog \
                    --backtitle "$FOG_rebranding_software" \
                    --title "ERROR" \
                    --ok-label "Ok" \
                    --timeout $FOG_DialogTimeout \
                    --msgbox "Failed to destroy Host !" 7 47
                export DIALOGRC=
                return 0
            fi
        fi
        return 0
    else
        export DIALOGRC="/root/dialog_rouge"
        dialog \
            --backtitle "$FOG_rebranding_software" \
            --title "ERROR" \
            --ok-label "Ok" \
            --timeout $FOG_DialogTimeout \
            --msgbox "This computer doesn't exist in FOG database." 7 47
        export DIALOGRC=
        return 0
    fi
}

PROCESS_ApproveCurrentHost() {
    # Fonction pour approuver l'hote dans FOG
    # Renvoie 1 si l'hote à été approuvée, 0 sinon.
    
    # Est-on connecté à FOG ? Si non, -> LOGIN
    if [[ $FOG_islogged != 1 ]]; then
        login_fog
        retval=$?
        if [[ $retval == 1 ]]; then
            # Login échouée ? AU REVOIR ! 
            return 0
        fi
    fi

    # Query le nom actuel du pc
    fog_compName
    
    # Vérifie que le serveur FOG nous a pas donnés une tâche . . .
    #verifTaches                
    #verifTachesFLAG=$?
    #if [[ $verifTachesFLAG == 1 ]]; then
    #    do_fog                # Une tâche est programmée -> je l'exécute.
    #fi
    
    if [[ "$(hostname -s)" == "$C_UNKNOWN_COMPUTER" ]]; then
        exec 3>&1
        export DIALOGRC="/root/dialog_jaune"
        selection=$(dialog \
            --backtitle "$FOG_rebranding_software" \
            --title "WARNING" \
            --defaultno \
            --timeout $FOG_DialogTimeout \
            --yesno "Would you like to approve this host ?" 6 47 \
            2>&1 1>&3)
        exit_status=$?
        export DIALOGRC=
        exec 3>&-

        if [[ "$exit_status" == "0" ]]; then
            # J'approuve la machine

            DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&aprvconf=1&username=${FOG_username}&password=${FOG_password}" "${web}service/grub/grub.php" -A '')    
        
            if [[ "$DoCurl" == *"OKSUCCESS"* ]]; then
                init_backtitle        # Le nom du poste à changée. La backtitle possiblement possible. Je mets à jout tout ça.
                dialog \
                    --backtitle "$FOG_rebranding_software" \
                    --title "Success" \
                    --ok-label "Ok" \
                    --timeout $FOG_DialogTimeout \
                    --msgbox "Host approved successfully" 7 47
                    
                return 1
            else
                export DIALOGRC="/root/dialog_rouge"
                dialog \
                    --backtitle "$FOG_rebranding_software" \
                    --title "ERROR" \
                    --ok-label "Ok" \
                    --timeout $FOG_DialogTimeout \
                    --msgbox "Host approval failed !" 7 47
                export DIALOGRC=
                return 0
            fi
        fi
        return 0
    else
        export DIALOGRC="/root/dialog_rouge"
        dialog \
            --backtitle "$FOG_rebranding_software" \
            --title "ERROR" \
            --ok-label "Ok" \
            --timeout $FOG_DialogTimeout \
            --msgbox "This computer exist in FOG database." 7 47
        export DIALOGRC=
        return 0
    fi   
}

PROCESS_UpdateKey() {
    [[ -z "$(hostname -s)" ]] && fog_compName
    # Cette partie met à jour la clé produit
    # Varariables globales : FOG_multicastSessionName (nom de la session multicast)
      
    # Est-on connecté à FOG ? Si non, -> LOGIN
    if [[ $FOG_islogged != 1 ]]; then
        login_fog
        retval=$?
        if [[ $retval == 1 ]]; then
            # Login échouée ? AU REVOIR ! 
            return 0
        fi
    fi

    # Vérifie que le serveur FOG nous a pas donnés une tâche . . .
    #verifTaches                
    #verifTachesFLAG=$?
    #if [[ $verifTachesFLAG == 1 ]]; then
    #    do_fog                # Une tâche est programmée -> je l'exécute.
    #fi

    if [[ $(hostname -s) != "$C_UNKNOWN_COMPUTER" ]]; then

        BoiteDeDialogue="dialog \
        --backtitle \"$FOG_rebranding_software\" \
        --title \"Update Product Key\" 
        --insecure \
        --timeout $FOG_DialogTimeout \
        --cancel-label \"Cancel\" \
        --mixedform \
        \"Please enter the product key :\" 10 53 0 \
        \"Key:\"  1 1 \"\" 1 10 37 64 0"

        exec 3>&1
        selection=$(eval $BoiteDeDialogue 2>&1 1>&3)
        exit_status=$?
        exec 3>&-
        if [[ $exit_status != "0" ]]; then
            FOG_prodkey='' # On quitte ? PAS DE NOM !
            return 1
        fi

        IFS=$'\n'
        DUMMY=($selection)
        FOG_prodkey="${DUMMY[0]}"
    
        # Réalise la query. Le fonctionnement est similaire à la programmation d'une image.
        # Dans le cas d'un PC non enregistrée ; on reçoit la tâche sous la forme d'une entrée de démarrage GRUB.
        # Dans le cas d'un PC enregistrée, la fonction verifTaches le verra (type && osid peuplée).

        DoCurl=$(curl -Lks --data "sysuuid=${sysuuid}&mac=$mac&key=${FOG_prodkey}&username=${FOG_username}&password=${FOG_password}" "${web}service/grub/grub.php" -A '')    
        
        #verifTaches
        #verifTachesFLAG=$?

        if [[ "$DoCurl" == *"OKSUCCESS"* ]]; then
                dialog \
                    --backtitle "$FOG_rebranding_software" \
                    --title "Success" \
                    --ok-label "Ok" \
                    --timeout $FOG_DialogTimeout \
                    --msgbox "Successfully changed key" 7 47
        else
            FOG_prodkey='' # Mauvaise clé, je l'efface
            export DIALOGRC="/root/dialog_rouge"
            dialog \
                --backtitle "$FOG_rebranding_software" \
                --title "ERROR" \
                --ok-label "Ok" \
                --timeout $FOG_DialogTimeout \
                --msgbox "ERROR ; Unable to change key !" 7 47
            export DIALOGRC=
        fi  
    else
        FOG_prodkey=''
        export DIALOGRC="/root/dialog_rouge"
        dialog \
            --backtitle "$FOG_rebranding_software" \
            --title "ERROR" \
            --ok-label "Ok" \
            --timeout $FOG_DialogTimeout \
            --msgbox "This computer doesn't exist in FOG database." 7 47
        export DIALOGRC=
    fi
}

ConfigCompName() {
    # ---- Récupère le nom de l'ordinateur si celui-ci est présent dans FOG.
    #       et changes la description du menu en conséquence.
    fog_compName
    if [ "$FOGcomputerName" == "$C_UNKNOWN_COMPUTER" ]; then
        echo "Host is NOT registered !" > /usr/share/foguefi/mainmenu/menu.d/description
    else
        echo "Host is registered as $FOGcomputerName" > /usr/share/foguefi/mainmenu/menu.d/description
    fi
    # ---- Change le hostname du Linux par le nom fourni par FOG
    #       Si celui-ci n'existe pas, cela deviendra "***Unknown***"
    hostname "$FOGcomputerName"
    echo "$FOGcomputerName" > /etc/hostname

    # ---- Crée un fichier /tmp/menu.sh, utilisée par les hooks du menu 
    #       afin de déterminer les éléments à afficher.
    echo "FOGcomputerName=\"${FOGcomputerName}\"" > /tmp/menu.sh
    echo "FOGclientIPaddr=\"$(getIPAddresses)\"" >> /tmp/menu.sh
    chmod +x /tmp/menu.sh
}

# init backtitle
init_backtitle
