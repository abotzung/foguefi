FOG GRUB uEFI patch installer - Alexandre BOTZUNG <alexandre.botzung@grandest.fr> 20220820

This patch extends the FOG PXE boot possibility to Secure Boot enabled computers via GRUB and SHIM.
   It consists of 3 parts : 
   - Files required for PXE (shim/GRUB), and FOG Stub patched
   - PHP Files for handling newer menus for GRUB
   - An optionnal tool : X Server for FOG Stub, allowing to surfing/remote desktop while FOG is working

=-=-=-=-=-=-=- INSTALLATION PROCESS -=-=-=-=-=-=-=-=-=-=-=
For installing this patch:
-> copy all files into a folder (eg : /root/uefipatch)
-> cd /root/uefipatch      # Change directory, where the patch is extracted
-> chmod +x ./install.sh   # Change the permission for installer.sh 
-> ./install.sh            # Launch the installer
...and it's done !

=-=-=-=-=-=-=- NOTES -=-=-=-=-=-=-=-=-=-=-=

Remember to change your PXE Boot file $bootfilename to shimx64.efi in your DHCP Server (option 67)

NOTE : Files from the 'legacy' FOG Stub has been replaced with theses new files. 
       Old files has been is automatically renamed (<FOG Folder> (usually /var/www/html/fog) /service/ipxe/bzImage_BAK && init.xz_BAK
	   
Some options, and neat tricks lies in /tftproot/grub/grub.cfg file ; 
   - Automatically download images for "special" mac addresses.
   - Enable VNC Server
   - Customize (rebrand) the FOG Stub
   - Customize your FOG Stub process 
   - ...
   
Other options lies into a special images folder /images/!xserver
   - Customize X Server startup.
   - Changing wallpaper dynamically.   
   - Add software to your desktop
   (X Server environment is based on Alpine Linux <https://www.alpinelinux.org/> © Copyright 2022 Alpine Linux Development Team)
   
In addition, this FOG Stub can now work fully from a USB key ; a menu has been implemented to circumvent this issue.
Also, when you do a "Full inventory" or "Quick registration", now the deploy action starts right away ! (if asked)

Some bugfixes has been patched into the boot process ;
 - Leaking AD username & password when a task is scheduled. (None now)
 - Host deletion, update product key and host approval permitted for an unauthenticated user (Must be authenticated now)
 
Also, a caveat exists: GRUB cannot load files from https only server.
(It switchs automatically to TFTP if it cannot load the main menu)

And finally, GRUB, by default, load automatically any UEFI Operating system present on the first hard drive.

Thanks for using my patch! -Alex 
===========================================================================================================


 This patch contains files from :
 - The FOG Project <https://fogproject.org/> (init.xz & scripts & logos)
 - Clonezilla (C) 2003-2022, NCHC, Taiwan <https://clonezilla.org/> (GNU/Linux signed kernel & scripts)
 - Ubuntu (C) 2022 Canonical Ltd. <https://ubuntu.com/> (shim-signed, grub-efi-arm64-signed)
 - Redo Rescue (C) 2010.2020 Zebradots Software <http://redorescue.com/> (GRUB Theme)
 - Alpine Linux © Copyright 2022 Alpine Linux Development Team <https://www.alpinelinux.org/> (X Server chroot)
 - Mcder3 <github.com/KaOSx/midna> (icons)
 - Gnome icon pack <https://download.gnome.org/sources/gnome-icon-theme/> (icons)
   Copyright . 2002-2008:
      Ulisse Perusin <uli.peru@gmail.com>
      Riccardo Buzzotta <raozuzu@yahoo.it>
      Josef Vybíral <cornelius@vybiral.info>
      Hylke Bons <h.bons@student.rug.nl>
      Ricardo González <rick@jinlabs.com>
      Lapo Calamandrei <calamandrei@gmail.com>
      Rodney Dawes <dobey@novell.com>
      Luca Ferretti <elle.uca@libero.it>
      Tuomas Kuosmanen <tigert@gimp.org>
      Andreas Nilsson <nisses.mail@home.se>
      Jakub Steiner <jimmac@novell.com>
	  
 - My work is published under the Creative Common Licence CC-BY-SA

The programs and files included with this patch are free software; the exact distribution terms for each program are described in the individual files.
This patch <FOG GRUB uEFI> comes with ABSOLUTELY NO WARRANTY, to the extent permitted by applicable law.