# Folder _patch / Patch file patch-FOS-for-AlpineLinux.patch
------------------------------------------

 The purpose of this file is to concatenate all patches needed for 
running FOS under Alpine Linux.
This patch is generated with the command: 

root@bar:/foo/bar/FOG-ORIG$ `diff -ruN . ../FOS-PATCHED > ../patch-FOS-for-AlpineLinux.patch`
Where : 
 * `.` is the current folder (FOS, whitout modification)
 * `../FOS-PATCHED` is the modified copy of FOS (with patches)

No others patches added to this folder is supported at this moment.

# Folder _rootfs / File added to final rootfs 
----------------------------------------------

 The content of this folder is copied to the Alpine Linux rootfs before creating the CPIO.
No file mode or groups are changed

# Folder fogmbrfix, framebuffer-vncserver, partclone, partclone-utils, partimage
--------------------------------------------------------------------------------

 Theses folders are the recipe for :

 * fogmbrfix : A program to patch MBR (used for Windows vista)
 * framebuffer-vncserver : A VNC Server, patched to only listen in local
 * parclone : The recipe for compiling partclone with the FOG Project patch 
 * partimage : The recipe for compiling partimage with the FOG Project patch
 * partclone-utils : A collection of tools 
