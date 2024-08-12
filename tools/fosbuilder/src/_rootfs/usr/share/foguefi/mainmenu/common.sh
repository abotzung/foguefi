#!/bin/bash
# common.sh - Fichier commun pour bashconsole.sh
#  Ce fichier est utilisée par bashconsole.sh à chaque rafraîchissement de l'écran (affichage du menu/exécution de programme)
#  Il me permets de changer la bannière du menu de manière dynamique (enregistrement du PC dans FOG, affichage de l'adresse IP, ...)
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
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.
#
# NOTE : foguefi "source" automatiquement fog/lib/funcs.sh
. /usr/share/foguefi/funcs.sh

msgbox () {
    # Affiche un message dialog type yesno
    # $1 -> Le message à afficher
    # retourne le code de retour. (=0)
    if [ -z "$DIALOG_COMMON_PARAMS" ]; then
        DIALOG_COMMON_PARAMS='"--no-collapse" "--ok-label" "Select" "--cancel-label" "Back" "--colors" "--no-mouse" "--backtitle" "'$backtitle'" "--title" "'$initialtitle'"'
    fi
    DIALOG_SPECIAL_PARAMETERS="\"--ok-label\" \"Ok\" \"--msgbox\" \"$1\" \"20\" \"60\""
    DialogFile=$(mktemp)
    echo "${DIALOG_COMMON_PARAMS} ${DIALOG_SPECIAL_PARAMETERS}" > "$DialogFile"
    exec 3>&1
    RetLabel=$(eval dialog --file "$DialogFile" 2>&1 1>&3)
    RetCode=$?
    exec 3>&-
    rm "$DialogFile"  

    return $RetCode
}

yesno () {
    # Affiche un message dialog type yesno
    # $1 -> Le message à afficher
    # retourne le code de retour. (1="No" / 0="Yes")
    if [ -z "$DIALOG_COMMON_PARAMS" ]; then
        DIALOG_COMMON_PARAMS='"--no-collapse" "--ok-label" "Select" "--cancel-label" "Back" "--colors" "--no-mouse" "--backtitle" "'$backtitle'" "--title" "'$initialtitle'"'
    fi
    DIALOG_SPECIAL_PARAMETERS="\"--no-label\" \"No\" \"--yes-label\" \"Yes\" \"--defaultno\" \"--yesno\" \"$1\" \"20\" \"60\""

    DialogFile=$(mktemp)
    echo "${DIALOG_COMMON_PARAMS} ${DIALOG_SPECIAL_PARAMETERS}" > "$DialogFile"
    exec 3>&1
    RetLabel=$(eval dialog --file "$DialogFile" 2>&1 1>&3)
    RetCode=$?
    exec 3>&-
    rm "$DialogFile"  

    return $RetCode
}

# NOTE à moi même : La partie affichage du nom de l'ordinateur est désormais dans foguefi/funcs.sh (+ lent mais )
ConfigCompName

# ---- Initialise les messages pour DIALOG ("backtitle")
#       et les configures pour bashconsole.sh
init_backtitle
DIALOGRC=''
DIALOG_COMMON_PARAMS='"--default-item" "1 Reboot" "--timeout" "'$FOG_DialogTimeout'" "--backtitle" "'$FOG_rebranding_software'" "--title" "FOS Main menu"'
