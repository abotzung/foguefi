#!/bin/bash
# Rafraichis les sources utilisés en interne pour régénérer un FOG Stub à jour.


. ./variables.sh
[ -z "$basedir" ] && $(echo "Il manque variables.sh, je ne peut rien faire !";exit 1)
[ -z "$basedir_sources" ] && $(echo "basedir_sources ne semble pas correctement configurée, j'arrête là !";exit 1)
[ -z "$foginit_xz" ] && $(echo "foginit_xz ne semble pas correctement configurée, j'arrête là !";exit 1)
[ -z "$clonezilla_iso" ] && $(echo "clonezilla_iso ne semble pas correctement configurée, j'arrête là !";exit 1)
[ -z "$flag_sourcesok" ] && $(echo "flag_sourcesok ne semble pas correctement configurée, j'arrête là !";exit 1)
[ -z "$foginit_xz_url" ] && $(echo "foginit_xz_url ne semble pas correctement configurée, j'arrête là !";exit 1)
[ -z "$clonezilla_iso_url" ] && $(echo "clonezilla_iso_url ne semble pas correctement configurée, j'arrête là !";exit 1)


echo "Rafraichis l'environnement de compilation par les dernières sources..."
echo "Merci de patienter. . ."
rm $foginit_xz
rm $clonezilla_iso
rm $flag_sourcesok

echo "-------------------------------------------------------"
echo "==============> Je télécharge le dernier STUB Fog. . . "
echo "-------------------------------------------------------"
wget -O $foginit_xz $foginit_xz_url
echo "---------------------------------------------------------------"
echo "==============> Je télécharge le dernier Clonezilla amd64. . . "
echo "---------------------------------------------------------------"
wget -O $clonezilla_iso $clonezilla_iso_url
echo "FINI !"
#Un tag de la date pour dire que les sources sont présentes :)
date > $flag_sourcesok
