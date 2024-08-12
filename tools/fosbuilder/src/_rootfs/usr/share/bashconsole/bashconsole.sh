#!/bin/bash
# bashconsole - a shell implementation of confconsole (somewhat) 
# Copyright (C) 2024 Alexandre BOTZUNG <alexandre@botzung.fr>
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

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# Need : bash, realpath, tr, sed, dirname, basename
#---help---
# Usage: bashconsole.sh [options]
#
# This script provides a menu "à la confconsole" for bash.
#
# Example:
#   bashconsole.sh -f /usr/share/foguefi/menu -p "1 Reboot"
#
# Options and environment variables:
#   -f sysbasepath            Specify the base folder bashconsole should use.
#                             (Default: dirname "$0")
#
#   -p exec_plugin            If specified, search for the first PLUGIN, and
#                             launches it. Quit after execution and return the 
#                             exitlevel provided by the plugin.
#
#   -s exec_pluginstrictname  (0/1) Force search with the EXACT PLUGIN name. By default, 
#                             the display name is used. (Eg: "01_Welcome" vs. "Welcome")
#                             (ONLY used with option -p) 
#
#   -o exec_pluginforce       (0/1) Force plugin execution (ignore the returnvalue of plugin hook)
#                             (ONLY used with option -p)
#
#   -q                        When the main menu is displayed, allow to quit bashconsole (default: not allowed)
#
#   -h                        Display this help.
#
# Each option can be also provided by environment variable. If both option and
# variable is specified and the option accepts only one argument, then the
# option takes precedence.
#
# This program comes with ABSOLUTELY NO WARRANTY; for details type `show w'.
# This is free software, and you are welcome to redistribute it
# under certain conditions; type `show c' for details.
#---help---
#

usage() {
	sed -En '/^#---help---/,/^#---help---/p' "$0" | sed -E 's/^# ?//; 1d;$d;'
}

while getopts 'f:p:s:o:h:q' OPTION; do
	# shellcheck disable=SC2220
	case "$OPTION" in
		f) sysbasepath="$OPTARG";;
		p) exec_plugin="$OPTARG";;
        s) exec_pluginstrictname="$OPTARG";;
        o) exec_pluginforce="$OPTARG";;
		h) usage; exit 0;;
        q) allow_exit=1;;
	esac
done

: "${sysbasepath:="$(dirname "$0")"}"
: "${exec_plugin:=""}"
: "${allow_exit:=0}"
: "${exec_pluginstrictname:=0}"
: "${exec_pluginforce:=0}"
sysbasepath=$(realpath "$sysbasepath")
menu_dir="${sysbasepath:?}/menu.d"
hook_dir="${sysbasepath:?}/hook.d"

: "${backtitle:=bashconsole menu}"
: "${initialtitle:=Main menu}"
if [ -z "$DIALOG_PARAMS" ]; then
    DIALOG_PARAMS='"--no-collapse" "--ok-label" "Select" "--cancel-label" "Back" "--colors" "--no-mouse" "--backtitle" "'$backtitle'" "--title" "'$initialtitle'"'
fi

CURRENT_FOLDER='' # Dossier virtuel courant

if [ ! -d "$menu_dir" ]; then
    echo "$0 ERROR : The folder $menu_dir does not exist."
    usage
    exit 1
fi

on_quit() {
    # Cette fonction est utilisée quand je quitte ce script (probablement car aucun répertoire n'est disponible)
    exit 0
    # TODO : Implémenter un déclancheur de "quitte confconsole". (Pertinent ?)
}

change_directory() {
    # Cette variable est pour éviter de créer une récursion à chaque itération de dialog
    CURRENT_FOLDER="$1"
}

msgbox () {
    # Affiche un message dialog type yesno
    # $1 -> Le message à afficher
    # retourne le code de retour. (=0)
    DIALOG_SPECIAL_PARAMETERS="\"--ok-label\" \"Ok\" \"--msgbox\" \"$1\" \"20\" \"60\""
    DialogFile=$(mktemp)
    echo "${DIALOG_PARAMS} ${DIALOG_COMMON_PARAMS} ${DIALOG_SPECIAL_PARAMETERS}" > "$DialogFile"
    exec 3>&1
    RetLabel=$(eval dialog --file "$DialogFile" 2>&1 1>&3)
    RetCode=$?
    exec 3>&-
    rm "$DialogFile"  

    if [[ "$RetCode" == 255 ]]; then
        exit 124 # Timeout de dialog ; je quitte bashconsole
    fi

    return $RetCode
}

yesno () {
    # Affiche un message dialog type yesno
    # $1 -> Le message à afficher
    # retourne le code de retour. (1="Back" / 0="YES")
    DIALOG_SPECIAL_PARAMETERS="\"--no-label\" \"No\" \"--yes-label\" \"Yes\" \"--defaultno\" \"--yesno\" \"$1\" \"20\" \"60\""

    DialogFile=$(mktemp)
    echo "${DIALOG_PARAMS} ${DIALOG_COMMON_PARAMS} ${DIALOG_SPECIAL_PARAMETERS}" > "$DialogFile"
    exec 3>&1
    RetLabel=$(eval dialog --file "$DialogFile" 2>&1 1>&3)
    RetCode=$?
    exec 3>&-
    rm "$DialogFile"  

    if [[ "$RetCode" == 255 ]]; then
        exit 124 # Timeout de dialog ; je quitte bashconsole
    fi

    return $RetCode
}

affiche_menu() {
    # Analyse le dossier en cours ($1)
    #
    # 1. Liste les répertoires (comme SubMenu)

    local CurFldr="$menu_dir/$1"

    local subMenu_fldr_name=() # "Advanced menu"              ; Nom du dossier (nettoyé)
    local subMenu_fldr_path=() # "/foo/Advanced_menu"         ; Chemin complet du dossier
    local subMenu_fldr_desc=() # "This is the Advanced menu"  ; Description du dossier ($subMenu_fldr_path/description)

    local subMenu_prgs_name=() # "Advanced menu"              ; Nom du programme (nettoyé)
    local subMenu_prgs_path=() # "/foo/Advanced_menu"         ; Chemin complet du programme
    local subMenu_prgs_desc=() # "This is the Advanced menu"  ; Description du programme ($subMenu_fldr_path/description)

    local menu_desc=''
    local name=''
    local _prg_desc=''
    local messagecontent=''
    local DIALOG_SPECIAL_PARAMETERS=''
    local label2_name=''
    local label2_path=''
    local no_folder=1
    local no_files=1


    if [ -f "$CurFldr/message" ] && [ -r "$CurFldr/message" ]; then
        # Si j'ai un message dans le dossier, j'affiche ce message.
        # Je vais devoit déterminer si je suis dans le dossier "racine" ou dans un sous dossier.
        #
        # Dans le cas du dossier "racine":
        #   Je récupère le nom du 1er dossier (si existant), sinon "QUIT"
        # Dans le cas d'un sous dossier:
        #   Je récupère le nom du 1er dossier (si existant) et je créé 2 labels : "<- Back" et ("NOM_DU_DOSSIER", si celui-ci existe)
        #
        #
        # Dans tous le cas, je récupère le nom du 1er dossier dans $CurFldr
        # Si $CurFldr(nettoyé)=="" alors label1 : "QUIT" sinon label1 : "<-Back"
        # Si NomDossierTrouve != "" alors label2="$NOM_DU_DOSSIER" sinon PAS_DE_LABEL2
        #
        #
        # 1. Récupère le nom du 1er dossier trouvé


        for x in "$CurFldr/"*; do
            if [ -d "$x" ] && [ -z "$label2_name" ]; then
                label2_path=${x//"$menu_dir/"/}
                label2_path=${label2_path#/}

                label2_name="$x"
                label2_name=${label2_name//"$menu_dir/"/}
                label2_name="$(basename "$label2_name")"
                label2_name=${label2_name#/}
                if [[ $(echo "$label2_name" | cut -b 3) == '_' ]]; then             # Nettoie le nom si celui-ci commence sous la forme ??_FOOBAR
                    label2_name=$(echo "$label2_name" | cut -b 4-)
                fi
                label2_name=$(echo "$label2_name" | tr -c '[:space:][:alnum:]\n\r-' ' ')    # Garde QUE les lettre/chiffres/espaces dans le nom

            fi
        done

        _temp=${CurFldr//"$menu_dir/"/}
        _temp="$hook_dir/$_temp"
        messagecontent=''

        # Recherche dans hook.d tous les PRE_message* et les exécutes/lis le contenu
        for x in "$_temp/PRE_message"*; do
            if [ -x "$x" ]; then
                # Si "message" est exécutable, lance le script et récupères sa sortie.
                messagecontent+="$("$x")"$'\n' >> "/dev/null" 2>&1
            else
                # Sinon, cat le contenu dans une variable
                messagecontent+="$(cat "$x")"$'\n'
            fi
        done

        # Exécute/affiche le message
        if [ -x "$CurFldr/message" ]; then
            # Si "message" est exécutable, lance le script et récupères sa sortie.
            messagecontent+="$("$CurFldr/message")"$'\n' >> "/dev/null" 2>&1
        else
            # Sinon, cat le contenu dans une variable
            messagecontent+="$(cat "$CurFldr/message")"$'\n'
        fi

        # Recherche dans hook.d tous les POST_message* et les exécutes/lis le contenu
        for x in "$_temp/POST_message"*; do
            if [ -x "$x" ]; then
                # Si "message" est exécutable, lance le script et récupères sa sortie.
                messagecontent+="$("$x")"$'\n' >> "/dev/null" 2>&1
            else
                # Sinon, cat le contenu dans une variable
                messagecontent+="$(cat "$x")"$'\n'
            fi
        done

        messagecontent="${messagecontent//'"'/'\"'}" # Explose les quotes dans le message

        if [ -z "${CurFldr//"$menu_dir/"/}" ]; then
            # On est à la racine
            if [ -z "$label2_path" ]; then             # Dans le cas où l'on a pas de sous-dossier dans le menu principal (bah on quitte, tout simplement)
                # RetCode : 0 (Back/Quit)
                DIALOG_SPECIAL_PARAMETERS="\"--ok-label\" \"Quit\" \"--msgbox\" \"$messagecontent\" \"20\" \"60\""
            else                                       # Sinon, on jump dans le dossier
                # RetCode : 0 (NOM_DU_DOSSIER)
                DIALOG_SPECIAL_PARAMETERS="\"--ok-label\" \"$label2_name\" \"--msgbox\" \"$messagecontent\" \"20\" \"60\""
            fi
        else
            # On est dans un sous-dossier, je change le type par un yesno (msgbox ne le supportant pas)
            if [ -z "$label2_path" ]; then 
                # RetCode : 0 (Back)
                DIALOG_SPECIAL_PARAMETERS="\"--ok-label\" \"Back\" \"--msgbox\" \"$messagecontent\" \"20\" \"60\""
            else
                # !! Notez ici que les étiquettes de labels changent... !!!
                # RetCode : 0 (Back) / 1 (NOM_DU_DOSSIER)
                DIALOG_SPECIAL_PARAMETERS="\"--yes-label\" \"Back\" \"--no-label\" \"$label2_name\" \"--defaultno\" \"--yesno\" \"$messagecontent\" \"20\" \"60\""
            fi
        fi

        DialogFile=$(mktemp)
        echo "${DIALOG_PARAMS} ${DIALOG_COMMON_PARAMS} ${DIALOG_SPECIAL_PARAMETERS}" > "$DialogFile"
        exec 3>&1
        RetLabel=$(eval dialog --file "$DialogFile" 2>&1 1>&3)
        RetCode=$?
        exec 3>&-
        rm "$DialogFile"

        if [[ "$RetCode" == 255 ]]; then
            exit 124 # Timeout de dialog ; je quitte bashconsole
        fi

        # ICI, je détermine la logique de réponse pour "message"
        if [ -z "${CurFldr//"$menu_dir/"/}" ]; then
            # On est à la racine
            if [ -z "$label2_path" ]; then 
                # RetCode : 0 (Quit)
                on_quit
            else                                       # Sinon, on jump dans le dossier
                # RetCode : 0 (NOM_DU_DOSSIER)
                change_directory "$label2_path" # DANGER !! Processus récursif.. !!
            fi
        else
            # On est dans un sous-dossier, je change le type par un yesno (msgbox ne le supportant pas)
            if [ -z "$label2_path" ]; then 
                # RetCode : 0 (Back)
                # ICI, je n'utilise plus label2_name. J'emprunte la variable pour nettoyer mon dossier courant.
                label2_name="${CurFldr//"$menu_dir/"/}"
                label2_name="$(dirname "$label2_name")"
                if [ "$label2_name" == "." ]; then
                    label2_name=''
                fi
                change_directory "$label2_name" # DANGER !! Processus récursif.. !!
FLAG_rootfolderls changent... !!!
                # RetCode : 0 (Back) / 1 (NOM_DU_DOSSIER)
                if [ "$RetCode" == 0 ]; then
                    label2_name="${CurFldr//"$menu_dir/"/}"
                    label2_name="$(dirname "$label2_name")"
                    if [ "$label2_name" == "." ]; then
                        label2_name=''
                    fi
                    change_directory "$label2_name"
                else              
                    change_directory "$label2_path"
                fi
            fi
        fi


        # ----------------- FIN DE LA LOGIQUE

    else
        _temp=${CurFldr//"$menu_dir/"/}
        _temp="$hook_dir/$_temp"
        for f in "$CurFldr/"*; do
            if [ -d "$f" ]; then
                no_folder=0
                subMenu_fldr_path+=("$f") # Ajoute le chemin complet du dossier au tableau
                name=$f
                name=${name//"$menu_dir/"/}
                name="$(basename "$name")"
                name=${name#/}
                if [[ $(echo "$name" | cut -b 3) == '_' ]]; then             # Nettoie le nom si celui-ci commence sous la forme ??_FOOBAR
                    name=$(echo "$name" | cut -b 4-)
                fi
                name=$(echo "$name" | tr -c '[:space:][:alnum:]\n\r-' ' ')    # Garde QUE les lettre/chiffres/espaces dans le nom
                subMenu_fldr_name+=("$name") # Ajoute le nom de l'item au tableau
                if [ -r "$f"/description ]; then
                    subMenu_fldr_desc+=("$(cat "$f"/description)")
                else
                    subMenu_fldr_desc+=("$name")
                fi
            fi
        done
        for f in "$CurFldr/"*; do
            if [ -f "$f" ] && [ -r "$f" ] && [ -x "$f" ]; then # (f)ichier, en lectu(r)e/lisible et e(x)ecutable
                name=$f
                name=${name//"$menu_dir/"/}
                name="$(basename "$name")"
                name=${name#/}
                flag_show_item=1

                # ICI, je vérifie si il existe un/des HOOK_<nomFichier>* (Détermine si j'affiche l'item ou pas)
                for x in "$_temp/HOOK_${name}"*; do
                    if [ -x "$x" ]; then
                        # Si un HOOK_<nomFichier>* est présent, exécutes-le
                        messagecontent="$("$x")" >> "/dev/null" 2>&1
                        #if [ ! "$($x)" ]; then
                        if [ $? != 0 ]; then
                            flag_show_item=0
                        fi
                    fi
                done
                if [ "$flag_show_item" == 0 ]; then continue; fi            # On a une erreur sur un HOOK_ ? J'affiche pas l'ITEM !


                no_files=0
                #name=$f
                #name=${name//"$menu_dir/"/}
                #name="$(basename "$name")"
                #name=${name#/}

                if [ "$name" == "description" ]; then continue; fi          # "description" est un fichier caché ; je ne l'affiche pas.

                subMenu_prgs_path+=("$f") # Ajoute le chemin complet du dossier au tableau

                if [[ $(echo "$name" | cut -b 3) == '_' ]]; then             # Nettoie le nom si celui-ci commence sous la forme ??_FOOBAR
                    name=$(echo "$name" | cut -b 4-)
                fi
                name=$(echo "$name" | tr -c '[:space:][:alnum:]\n\r-' ' ')    # Garde QUE les lettre/chiffres/espaces dans le nom
                subMenu_prgs_name+=("$name") # Ajoute le nom de l'item au tableau
                
                _prg_desc=$(sed -n -e '2{p;q}' "$f")
                _prg_desc=${_prg_desc//"DESCRIPTION="?/}    # Si une variable DESCRIPTION="... est peuplée en 2nd ligne 
                # TOOD : Ajouter ici les commentaires python
                _prg_desc=${_prg_desc//"#"?/}               # Si c'est un commentaire # ... qui est peuplée
                _prg_desc=${_prg_desc//";"?/}               # Si c'est un commentaire ; ... qui est peuplée
                _prg_desc=${_prg_desc//"'"?/}               # Si c'est un commentaire ' ... qui est peuplée
                _prg_desc=$(echo "$_prg_desc" | tr -c '[:space:][:alnum:]\n\r-' ' ')    # Garde QUE les lettre/chiffres/espaces dans le nom
                subMenu_prgs_desc+=("$_prg_desc")
                if [ -z "$f" ]; then # Condition très improbable
                    subMenu_prgs_desc+=("$name")
                fi
            fi
        done

        # Pas de fichiers ni de dossiers ? NO SOUP FOR U!
        if [ "$no_folder" == 1 ] && [ "$no_files" == 1 ]; then
            DialogFile=$(mktemp)
            DIALOG_SPECIAL_PARAMETERS="\"--ok-label\" \"Back\" \"--msgbox\" \"(no content)\" \"20\" \"60\""
            echo "${DIALOG_PARAMS} ${DIALOG_COMMON_PARAMS} ${DIALOG_SPECIAL_PARAMETERS}" > "$DialogFile"
            exec 3>&1
            RetLabel=$(eval dialog --file "$DialogFile" 2>&1 1>&3)
            RetCode=$?
            exec 3>&-
            rm "$DialogFile"
            if [[ "$RetCode" == 255 ]]; then
                exit 124 # Timeout de dialog ; je quitte bashconsole
            fi
            label2_name="${CurFldr//"$menu_dir/"/}"
            label2_name="$(dirname "$label2_name")"
            if [ "$label2_name" == "." ]; then
                label2_name=''
            fi
            change_directory "$label2_name" 
            return 0
        fi

        if [ -r "$CurFldr"/description ]; then
            menu_desc="$(cat "$CurFldr"/description)"
        else
            menu_desc=$(basename "$CurFldr")  #"$name"
        fi

        DialogFile=$(mktemp)


        # ICI, je teste si je suis dans le dossier racine et dans le cas où le drapeau --
        _tmpvar1="$CurFldr"
        _tmpvar1=${_tmpvar1%/} # Retire les slash a la fin de la variable
        _tmpvar2="$menu_dir"
        _tmpvar2=${_tmpvar2%/} # Retire les slash a la fin de la variable      

        FLAG_rootfolder=0
        [[ "$_tmpvar1" == "$_tmpvar2" ]] && FLAG_rootfolder=1
        
        if [[ "$allow_exit" -eq 1 ]]; then 
            if [[ "$FLAG_rootfolder" -eq 1 ]]; then
                DIALOG_COMMON_PARAMS="${DIALOG_COMMON_PARAMS} \"--cancel-label\" \"Exit\""
            fi
        fi
        echo "${DIALOG_PARAMS} ${DIALOG_COMMON_PARAMS} --menu \"${menu_desc}\" \"20\" \"60\" \"11\"" > "$DialogFile"

        # Pour la boîte de dialogue
        #echo "\"--ok-label\" \"Advanced Menu\" \"--msgbox\" \"$LE_MESSAGE\" \"20\" \"60\"" > "$DialogFile"

        for ((i = 0; i < ${#subMenu_fldr_name[@]}; i++)); do
            #echo "n° $i : ${subMenu_fldr_name[$i]} -> ${subMenu_fldr_desc[$i]}"
            #LeTas="${LeTas}\"${subMenu_fldr_name[$i]}\" \"${subMenu_fldr_desc[$i]}\" "
            #LeTas="${LeTas}'${subMenu_fldr_name[$i]}' '${subMenu_fldr_desc[$i]}' "
            echo "\"${subMenu_fldr_name[$i]}\" \"${subMenu_fldr_desc[$i]}\"" >> "$DialogFile"
        done
        for ((i = 0; i < ${#subMenu_prgs_name[@]}; i++)); do
            echo "\"${subMenu_prgs_name[$i]}\" \"${subMenu_prgs_desc[$i]}\"" >> "$DialogFile"
        done

        exec 3>&1
        RetLabel=$(eval dialog --file "$DialogFile" 2>&1 1>&3)
        RetCode=$?
        exec 3>&-
        rm "$DialogFile"
        
        if [[ "$RetCode" == 255 ]]; then
            exit 124 # Timeout de dialog ; je quitte bashconsole
        fi

        label2_name=""
        if [ "$RetCode" == 1 ]; then
            # "Back" pressé, on reviens en arrière...
            # PATCH - Si $allow_exit = 1 ET QUE $FLAG_rootfolder = 1, quitte bashconsole
            if [[ "$allow_exit" -eq 1 ]]; then 
                if [[ "$FLAG_rootfolder" -eq 1 ]]; then
                    exit 123
                fi
            fi

            label2_name="${CurFldr//"$menu_dir/"/}"
            label2_name="$(dirname "$label2_name")"
            if [ "$label2_name" == "." ]; then
                label2_name=''
            fi
            change_directory "$label2_name"
        else
            # "Select" pressé, on cherches l'item dans les 2 tableaux, et agis en conséquence...
            for ((i = 0; i < ${#subMenu_fldr_name[@]}; i++)); do
                #echo "\"${subMenu_fldr_name[$i]}\" \"${subMenu_fldr_desc[$i]}\"" >> "$DialogFile"
                # ICI, je recherches dans les dossiers
                if [ "$RetLabel" == "${subMenu_fldr_name[$i]}" ] && [ -z "$label2_name" ]; then # Nom trouvé dans les répertoires. Je fait un peu de nettoyage et on jump dedans
                    label2_name="${subMenu_fldr_path[$i]}"
                    label2_name="${label2_name//"$menu_dir/"/}"
                    
                    label2_name=${label2_name#/} # Retire les slash au début de la variable
                    label2_name=${label2_name%/} # Retire les slash a la fin de la variable
                    
                    change_directory "$label2_name"
                fi
            done

            for ((i = 0; i < ${#subMenu_prgs_name[@]}; i++)); do
                #echo "\"${subMenu_prgs_name[$i]}\" \"${subMenu_prgs_desc[$i]}\"" >> "$DialogFile"
                # ICI, je recherche dans les fichiers
                if [ "$RetLabel" == "${subMenu_prgs_name[$i]}" ] && [ -z "$label2_name" ]; then # Nom trouvé dans les répertoires. Je fait un peu de nettoyage et on jump dedans
                    label2_name="${subMenu_prgs_path[$i]}"
                    #echo "J'exécute le programme suivant : $label2_name"
                    eval "\"$label2_name\""
                    # Code de sortie spécifique pour quitter le menu.
                    if [ $? == 123 ]; then
                        exit 123
                    fi
                fi  
            done
        fi
      
    fi


}

if [ -n "$exec_plugin" ]; then
    plugins_list=()
    #find "$menu_dir" -type f -print0 | 
    #    while IFS= read -r -d '' plugin; do 
    #        plugins_list+=("$plugin")
    #    done
        
    while IFS=  read -r -d $'\0'; do
    plugins_list+=("$REPLY")
    done < <(find "$menu_dir" -type f -print0)

    for plugin in "${plugins_list[@]}"; do
        plugin="$(realpath "$plugin")"
        if [ -f "$plugin" ] && [ -r "$plugin" ] && [ -x "$plugin" ]; then # (f)ichier, en lectu(r)e/lisible et e(x)ecutable
            name=$plugin
            name=${name//"$menu_dir/"/}
            name="$(basename "$name")"
            name=${name#/}
            if [ "$exec_pluginstrictname" == 0 ]; then
                if [[ $(echo "$name" | cut -b 3) == '_' ]]; then             # Nettoie le nom si celui-ci commence sous la forme ??_FOOBAR
                    name=$(echo "$name" | cut -b 4-)
                fi
                name=$(echo "$name" | tr -c '[:space:][:alnum:]\n\r-' ' ')    # Garde QUE les lettre/chiffres/espaces dans le nom
            fi
            
            if [ "$name" == "$exec_plugin" ]; then
                _temp=${plugin//"$menu_dir/"/} # Retire du chemin absolu de $plugin, le dossier $menu_dir
                _temp="$hook_dir/$_temp"       # ... et le remplace par le dossier $hook_dir
                # ICI, je vérifie si il existe un/des HOOK_<nomFichier>* (Détermine si j'affiche l'item ou pas)
                for x in "$_temp/HOOK_${name}"*; do
                    if [ -x "$x" ]; then
                        # Si un HOOK_<nomFichier>* est présent, exécutes-le
                        messagecontent="$("$x")" >> "/dev/null" 2>&1
                        if [ $? != 0 ]; then
                            if [ "$exec_pluginforce" == 0 ]; then
                                echo "Plugin error : hook \"$x\" returned non zero value"
                                exit 1
                            fi
                        fi
                    fi
                done
                #echo "Found! : $name != $exec_plugin"
                eval "\"$plugin\""
                exit $?
            fi
        fi
    done
    # Not found ? Show error ! 
    echo "Plugin not found : \"$exec_plugin\" in $menu_dir (StrictName=$exec_pluginstrictname)"
    exit 1
fi

while true; do 
    if [ -r "${sysbasepath}/common.sh" ] && [ -x "${sysbasepath}/common.sh" ]; then
        source "${sysbasepath}/common.sh"
    fi
    
    affiche_menu "$CURRENT_FOLDER"
done
