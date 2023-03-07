#!/bin/bash
# Nettoie l'environnement de compilation
. ./variables.sh
[ -z "$basedir" ] && $(echo "Il manque variables.sh, je ne peut rien faire !";exit 1)
[ -z "$basedir_temp" ] && $(echo "basedir_temp ne semble pas correctement configurée, j'arrête là !";exit 1)

echo "-------------------------------------------------------"
echo "==============> Je nettoie $basedir_temp . . . "
echo "-------------------------------------------------------"
rm -rf $basedir_temp
