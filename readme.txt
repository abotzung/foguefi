This patch contains files from :
- The FOG Project <https://fogproject.org/> (FOS, scripts & logos)
- Clonezilla (C) 2003-2024, NCHC, Taiwan <https://clonezilla.org/> (scripts)
- Ubuntu (C) 2024 Canonical Ltd. <https://ubuntu.com/> (GNU/Linux signed kernel, shim-signed, grub-efi-arm64-signed)
- The Alpine Linux Development team <https://www.alpinelinux.org/> (base env)
- Redo Rescue (C) 2010.2020 Zebradots Software <http://redorescue.com/> (GRUB Theme, heavily modified)
- Mcder3 <github.com/KaOSx/midna> (icons)
- Gnome icon pack <https://download.gnome.org/sources/gnome-icon-theme/> (icons) (c) 2002-2008 :

Sorry, this document is only available in French (yet) ! 

============================================================================
                    F O G U E F I    v 1 . 5 . 10 . X
                Unofficial Secure Boot Patch for FOG 'FOS'
  Alexandre BOTZUNG [alexandre.botzung@grandest.fr] && The FOG Project Team
https://github.com/abotzung/foguefi / https://github.com/FOGProject/fogproject
                   VERSION : 20240321 (Licence : GPL-3)
============================================================================

Ces notes résument la liste des fonctionnalités ajoutés dans FOG Project.
(ainsi que les quelques péripéties vu par-ci, par-là)

Procédure d'installation : 
==========================

L'installation du patch est simple à réaliser : 

(les commandes doivent être exécutés en tant que root)
sudo -i
cd /opt
git clone https://github/abotzung/foguefi.git
cd foguefi
./install.sh

Notez que la procédure d'installation à besoin d'une connexion à Internet et de ~2 Go d'espace disque.

A la fin de l'installation, pensez à changer l'option 67 de votre serveur DHCP (PXE Boot file) en "shimx64.efi" 
(iPXE/REfind reste entièrement disponible après installation)

Le "pourquoi" : 
==========================

Ce patch est née de la fainéantise de ne pas à avoir a désactiver Secure Boot sur les 
nouveaux ordinateurs (achetés), pour pouvoir utiliser FOG. 
D'un autre côté, UEFI apporte la possibilitée d'interagir directement avec la liste de démarrage 
des périphériques (bcdedit /enum firmware / efibootmgr) depuis le système d'exploitation, 
permettant de "commander" un démarrage temporaire sur un périphérique particulier. (réseau par exemple)

Le constat est cependant moyen ; l'outil est capable d'utiliser && d'embrasser Secure Boot, 
Hors, il faut pour cela utiliser un générateur de clés matériel + injecter le certificat publique 
à l'aide de MOKUtil. (= chiant)

Ma réponse face à cette problématique à été d'utiliser le cœur Linux de Clonezilla, qui lui est signée
par Canonical(c) (dans la saveur Ubuntu), qui elle même est signée par Microsoft(c) et de coller le package "FOG" afin d'en faire une
solution fonctionnant en Secure Boot. (même si ce n'est pas l'idéal)

Le principal problème est que FOS n'a pas été pensée pour fonctionner avec un chargeur de démarrage différent. (GRUB vs. iPXE)
La création d'un menu à l'intérieur de Linux à été nécessaire pour contourner les fonctionnalités graphiques de iPXE.
(/etc/init.d/S98_*)

Les fonctionnalités de base (du type bootmenu) ont étés directement claqués depuis le bootmenu de iPXE, hors pour éviter
un éventuel conflit avec les paramètres de ce dernier, les entrées ont étés hardcodées directement. (grubbootmenu.class.php)

Quelques modifications ont étés réalisés, afin de pouvoir avoir :

- Visualiser l'état du client à distance à l'aide d'un navigateur ; FOS remonte désormais son statut au travers d'une interface web.

- Contrôler le client FOS à l'aide d'un navigateur ; une console spécifique existe sur le port 81. Pour y accéder, vous devez vous authentifier avec 
  votre compte et mot de passe de FOG.

- La console linux secondaire (CTRL + ALT + F2) vous permets d'accéder à une console système. Après une authentification réussie, vous pouvez redémarrer le poste, relancer
  VNC ou lancer un shell. Le compte à utiliser est le même que celui utilisée pour l'interface web de FOG.

- Un serveur VNC, permettant de visualiser le process de FOS à distance.
  Celui-ci ne possède pas de mot de passe par défaut, et pour des raisons de sécurité n'écoute que sur l'adresse de bouclage "localhost".
  Une série de script (avec socat) renvoie la connexion VNC vers le serveur FOG, qui la renvoie vers la dernière adresse IP connue de la dernière connexion
   sur l'interface web ; FOS crée un port en écoute sur le port 5901, limitée à l'adresse IP du serveur FOG (un pare-feu du pauvre))
  Dès que le serveur VNC est fonctionnel, "enablevnc.php" est appelée qui va exécuter socat afin de créer un tunnel entre le serveur FOS et le client TightVNC (en mode listen).
  La connexion n'est pas ré-ouverte quand l'une des 2 parties (FOS ou TightVNC) voit sa connexion fermée.
  Par défaut, cette opération est activée. Elle peut être désactivée en modifiant le fichier /tftproot/grub/grub.cfg
  
- Un serveur SSH, permettant de prendre la main pendant une opération de remastérisation.
  Opération toute simple, le mot de passe du compte root de FOS est changée en l'adresse MAC de l'ordinateur.
  A noter que cela peut, dans certains cas, entraîner un potentiel risque de sécurité pour FOS.
  Par défaut, cette opération est désactivée. Elle peut être réactivée en modifiant le fichier /tftproot/grub/grub.cfg
  
- L'exécution de FOS depuis une clé USB, de manière "autonome".
  En l'état, FOS (classique/vanille) est capable de fonctionner depuis une clé USB. Cependant, il nécessite qu'une tâche ait été programmée depuis le serveur.
  Cette version permets d'avoir un menu textuel, et d'exécuter la plupart des opérations traditionnellement fourni avec iPXE.
   
- Le paramétrage du comportement "sans surveillance" (.
  Il est désormais possible de paramétrer FOS afin de lui fournir un comportement type "sans surveillance":
  Démarrer FOS avec les paramètres en ligne de commande suivantes : 
   menutype=down FOG_imageID=42 FOG_username=usr-fog FOG_password=Acme2012
  permets de déployer l'image ayant comme ID 42, et le compte usr-fog / Acme2012 est utilisée pour s'autoriser sur le serveur.
  (tout cela sans à devoir valider quelque-chose dans un menu)
  Notez que dans le cas où l'identifiant/mot de passe/ID de l'image sont faux, il sera demandé à l'utilisateur de corriger ces informations.
  Il existe d'autres paramètres décris dans le fichier /tftpboot/grub/grub.cfg

- Des détails en vrac: 
  * Lors d'un "Perform full registration and inventory", si vous sélectionnez "voulez-vous télécharger l'image maintenant ?", le système ne redémarre pas 
     et exécute immédiatement le téléchargement.

  * Un délai d'inactivité à été ajoutée, permettant de quitter et de redémarrer FOS dans le cas d'un démarrage inopiné.
    Le paramètre (en ligne de commande) suivant contrôle ce paramètre : FOG_DialogTimeout (par défaut 15 minutes sans paramètres / 30 sec. dans GRUB)

  * Il est possible de changer la bannière à l'arrière des fenêtres dans FOS : 
     Les paramètres (en ligne de commande) suivants permettent ces opérations :
     * FOG_rebranding_banner=... permet de changer la description/l'auteur du logiciel
      Cela donnera "FOG Stub ... - (contenu de FOG_rebranding_banner)" à l'écran
     * FOG_rebranding_software=... permet de remplacer toute la ligne à l'écran par son contenu.
      (cachant aussi le nom de l'ordinateur)

  * Memtester est utilisée à la place de Memtest86. (dont une partie du code à été écris par Steven Shiau <steven _at_ clonezilla org>)

Il existe tout de même quelques bogues, encore pas corrigées : 

- Dans le cas où l'hôte à été ajoutée dans le serveur FOG via le client FOG, et que celui-ci n'a pas été approuvée, il sera impossible de lui télécharger une image.
    Solution : Approuver l'hôte.

- [(Windows(c)] Il peut arriver que FOS n'arrive pas à capturer un disque NTFS, car il contient des métadonnées non écrites. Cela peut provenir de 2 éléments : 
  Passez la clé "ControlSet001\Control\Session Manager\Power\HiberbootEnabled" à "0" (Veille hybride)
  Passez la clé "Microsoft\Windows\CurrentVersion\Policies\System\DisableAutomaticRestartSignOn" à "1" (Ferme la session lors d'un arrêt/redémarrage)
    Essayez la commande "chkdsk c: /F" dans votre système avant de capturer l'image

- Il arrive que le protocole HTTP ne fonctionne pas correctement dans GRUB ; les transferts ne se réalisent pas.
    Plusieurs solutions de contournement ont étés mis en place dans GRUB : 
    - ligne 89 : "set bootpath=$tftp_bootpath"
                 Cela permets de forcer le chargement de Linux (+ cpio) depuis le protocole TFTP. Si vous souhaitez tout de même 
                 télécharger vos fichiers en mode HTTP, commentez cette ligne.
    - ligne 136-228 : Ce bloc teste si la connexion HTTP est fonctionnelle. Dans le cas contraire, GRUB retourne dans mode "de secours", où le client 
                 est chargée, et seule les options textuels dans FOS sont disponibles. (VNC et autres restent disponibles)
    - ligne 258-275 : Le menu de démarrage de secours. A noter que comme la communication avec le serveur n'arrive pas à être établie, la disposition du clavier est "hardcodée" dans 
                      la langue de backup_keymap (ligne 21 du fichier grub.cfg)

    Si le problème persiste, tentez de redémarrer apache (systemctl restart apache2) et de réinitialiser l'ordinateur posant problème.

- Mon patch n'a été pensée que pour être préparée/fonctionnel sur une Debian, ayant une connexion à Internet. (ou à un proxy)

- Les scripts utilisés dans ce patch sont au mieux, moyennement fonctionnels. Il est possible que des choses se passent mal.
  Je ne suis pas responsable en cas de panne, ou de perte de données. Ce patch est fourni "dans l'état", en espérant que cela puisse servir à d'autres, mais
   surtout sans AUCUNE GARANTIE. Il a été conçu sur mon temps libre, n'hésitez-pas à me faire un retour si vous trouvez des coquilles ou bien des éléments à améliorer.
  Ah, et surtout : FAITES DES SAUVEGARDES (AVANT L'INSTALLATION)! Merci! :)

Merci d'utiliser mon patch ! ~Alexandre

PS : Aucun ordinateur ou serveur FOG n'a été maltraité durant la conception de ce patch. :)



