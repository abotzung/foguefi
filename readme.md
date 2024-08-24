# FOGUefi 
Run FOG on Secure Boot enabled computers

The goal of FOGUefi is to be able to use the FOG server on computers with Secure Boot enabled (using GRUB), while retaining the original operating principle of FOG.

FOGUefi is a fork of [FOS](https://github.com/fogProject/fos), modified to run on [Alpine Linux](https://alpinelinux.org/), shipped with the Ubuntu Noble kernel, shim and signed Grub2.

![GRUB Boot menu](https://github.com/user-attachments/assets/c74af7bd-1e17-4e9f-87db-0f1d2788a04d)

## Features

- [GRUB](https://www.gnu.org/software/grub/manual/grub/grub.html) boot menu driven by [FOG Server](https://github.com/FOGProject/fogproject/).
  (separated from [iPXE](https://ipxe.org/))
- Remote control (using a web browser)
- Ability to automate image deployment/capture (touchless)
- Configurable through the installation of third-party [APK packages](https://pkgs.alpinelinux.org/packages?name=&branch=edge&repo=&arch=x86_64&maintainer=)
- Grace period before a task is executed (default 10 seconds)
- Highly customizable configuration (by scripts).

## Installation

- Standard installation (recommended) : 
```bash
cd /opt
git clone https://github.com/abotzung/foguefi
cd foguefi
./install.sh
```

- Installing FOGUefi from latest sources ("edge") : 
```bash
cd /opt
git clone https://github.com/abotzung/foguefi
cd foguefi
./install.sh -b
```
### Command-line Options :
```
 Usage :
   ./install.sh

 Options :
	-a				Skip Apache2 configuration
	-b				Build files from the latest sources, rather than downloading it from Github
	-f				Force (re)installation of FOGUefi
	-h				Show this help
	-u				Unattended installation.
	-n				No internet flag ; This forces the installer to NOT use internet. (useful for air-gapped networks)
					NOTE : You need to download theses files into the root directory of this script :
					https://github.com/abotzung/FOGUefi/releases/latest/download/fog_uefi.cpio.xz
					https://github.com/abotzung/FOGUefi/releases/latest/download/fog_uefi.cpio.xz.sha256
					https://github.com/abotzung/FOGUefi/releases/latest/download/grubx64.efi
					https://github.com/abotzung/FOGUefi/releases/latest/download/grubx64.efi.sha256
					https://github.com/abotzung/FOGUefi/releases/latest/download/linux_kernel
					https://github.com/abotzung/FOGUefi/releases/latest/download/linux_kernel.sha256
					https://github.com/abotzung/FOGUefi/releases/latest/download/release
					https://github.com/abotzung/FOGUefi/releases/latest/download/shimx64.efi
					https://github.com/abotzung/FOGUefi/releases/latest/download/shimx64.efi.sha256
```


## FAQ

- [[#Why use Linux kernel, GRUB and SHIM from Ubuntu Noble repositories?]]
- [[#Why FOGUefi ?]]
- [[#What are the features of FOGUefi?]] 
- [[#I want to modify the GRUB boot menu; what should I modify?]]

### Why use Linux kernel, GRUB and SHIM from Ubuntu Noble repositories?

Using the Ubuntu kernel, grub-signed and shim-signed are required because these are signed by Microsoft(C), and can allow booting without having to use [mokutil](https://www.linux.org/docs/man1/mokutil.html) on every computer running FOG.

This is the fastest and easiest solution to be able to use FOG.

Note: A Shim is currently being signed to be able to use iPXE, with Secure Boot: https://github.com/rhboot/shim-review/issues/319

### Why FOGUefi ?

FOGUefi was born in december 2019, because I couldn't quickly and easily use FOG with computers that had Secure Boot. I also added various features that I think are relevant for "everyday" use.

### What are the features of FOGUefi?

[➡️ Link to documentation](https://github.com/abotzung/foguefi/blob/main/documentation.md)

### I want to modify the GRUB boot menu; what should I modify?

The `/tftpboot/grub/custom.cfg` file can be edited to configure the GRUB boot menu. More information can be found in the [documentation](https://github.com/abotzung/foguefi/blob/main/documentation.md).

### Credits

FOGUefi is build with the help of : 
- **Baobabrom** : For your countless hours of debugging.

- [The FOG Project](https://fogproject.org/) : For this superb tool
  (Parts used in FOS, scripts and logos)

- [Clonezilla©/Steven Shiau](<steven _at_ clonezilla org>) (C) 2003-2024, NCHC, Taiwan
  (The boot-local-efi.cfg file)

- [Ubuntu©](https://ubuntu.com/) (C) 2024 Canonical Ltd. 
  (GNU/Linux signed kernel, shim-signed, grub-efi-arm64-signed)

- [The Alpine Linux Development team](https://www.alpinelinux.org/) 
  (for Alpine Linux)

- [Redo Rescue©](http://redorescue.com/) (C) 2010.2020 Zebradots Software 
  (GRUB Theme, heavily modified)

- [Mcder3](https://github.com/KaOSx/midna)
  (Icons)

- [Font Awesome](https://fontawesome.com/) (Licence : SIL OFL 1.1) : Icons

- [La Région Grand-Est](https://www.grandest.fr/)
