#!/bin/bash

cmake --version > /dev/null 2>&1
if [ $? -ne "0" ]; then
	echo "ERROR ! framebuffer-vncserver requires cmake to be compiled. (apt install cmake)"
	exit 1
fi
[ ! -d "framebuffer-vncserver" ] && eval "echo 'ERROR : framebuffer-vncserver does not exist.';exit 1"
cd "framebuffer-vncserver"
[ -d "build" ] && rm -rf "./build"
[ ! -d "build" ] && mkdir "build"
cd "./build"
cmake .. || echo "ERROR, compilation failed ! framebuffer-vncserver requires libvncserver-dev to be compiled. (apt install libvncserver-dev)"
make

echo "Done !"
