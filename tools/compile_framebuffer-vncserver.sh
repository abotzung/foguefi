#!/bin/bash

cmake --version > /dev/null 2>&1
if [ $? -ne "0" ]; then
	echo "ERROR ! framebuffer-vncserver requires cmake AND libvncserver-dev to be compiled. (apt install cmake libvncserver-dev)"
	exit 1
fi
[ ! -d "framebuffer-vncserver" ] && eval "echo 'ERROR : framebuffer-vncserver does not exist.';exit 1"
cd "framebuffer-vncserver" || exit
[ -d "build" ] && rm -rf "./build"
mkdir "build"
cd "./build" || exit
cmake .. || echo "ERROR, compilation failed ! framebuffer-vncserver requires libvncserver-dev to be compiled. (apt install libvncserver-dev)"
make

[ ! -d "../../fogbuilder/project/bin" ] && mkdir ../../fogbuilder/project/bin
cp -fv "framebuffer-vncserver" ../../fogbuilder/project/bin
chmod +x ../../fogbuilder/project/bin
cd ".." || exit
[ -d "build" ] && rm -rf "./build"

echo "Done !"
