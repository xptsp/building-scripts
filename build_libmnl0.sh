#!/bin/bash

#================================================================================
# Function to compile latest version of "libmnl" from the netfilter project:
function libmnl_compile() {
	cd ${BUILD}
	git clone https://git.netfilter.org/libmnl
	cd ${BUILD}/libmnl
	mkdir -p install
	./autogen.sh
	./configure --host=arm-linux-gnueabihf --prefix=$PWD/install
	make clean
	make
	make install
}

#================================================================================
# Function to get version and build numbers for these packages:
function libmnl_version()
{
	LIBMNL_BUILD=1
	OLD_LIBMNL_VER=$(deb_version libmnl0)
	NEW_LIBMNL_VER=$(git_version libmnl ${LIBMNL_BUILD})
}
 
#================================================================================
# Function to modify existing packages with our compiled code:
function libmnl_package() {
	#================================================================================
	# Modify existing deb package for "libmnl0" with our compiled files:
	test -d ${BUILD}/libmnl/modded && rm -rf ${BUILD}/libmnl/modded
	mkdir -p ${BUILD}/libmnl/modded
	cd ${BUILD}/libmnl/modded
	DIR=libmnl0_${NEW_LIBMNL_VER}_armhf
	apt download libmnl0=${OLD_LIBMNL_VER}
	dpkg-deb -R libmnl0_${OLD_LIBMNL_VER}_armhf.deb ${DIR}
	rm libmnl0_${OLD_LIBMNL_VER}_armhf.deb
	cd ${BUILD}/libmnl/modded/${DIR}
	rm -rf usr/share/doc/libmnl0/*
	cp ${BUILD}/libmnl/{README,COPYING} usr/share/doc/libmnl0/
	cp -a ${BUILD}/libmnl/install/lib/libmnl.*.0 usr/lib/arm-linux-gnueabihf/
	sed -i "s|^Version: .*|Version: ${NEW_LIBMNL_VER}|" DEBIAN/control
	sed -i "s|^Installed-Size: .*|Installed-Size: $(du -s usr | awk '{print $2}')|" DEBIAN/control
	find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
	rm DEBIAN/{shlibs,symbols,triggers}
	cd ..
	dpkg-deb --build --root-owner-group ${DIR}
	apt install -y ./${DIR}.deb
	rm ${PPA:-"${BUILD}"}/libmnl*.deb
	mv ${DIR}.deb ${PPA:-"${BUILD}"}

	#================================================================================
	# Modify existing deb package for "libmnl-dev" with our compiled files:
	cd ${BUILD}/libmnl/modded
	DIR=libmnl-dev_${NEW_LIBMNL_VER}_armhf
	apt download libmnl-dev=${OLD_LIBMNL_VER}
	dpkg-deb -R libmnl-dev_${OLD_LIBMNL_VER}_armhf.deb ${DIR}
	rm libmnl-dev_${OLD_LIBMNL_VER}_armhf.deb
	cd ${BUILD}/libmnl/modded/${DIR}
	rm -rf usr/share/doc/libmnl-dev/*
	cp ${BUILD}/libmnl/{README,COPYING} usr/share/doc/libmnl-dev/
	cp ${BUILD}/libmnl/install/include/libmnl/libmnl.h usr/include/libmnl/
	rm usr/lib/arm-linux-gnueabihf//libmnl.so
	cp -a ${BUILD}/libmnl/install/lib/libmnl.so usr/lib/arm-linux-gnueabihf/
	cp ${BUILD}/libmnl/install/lib/pkgconfig/libmnl.pc usr/lib/arm-linux-gnueabihf/pkgconfig/
	sed -i "s|^Version: .*|Version: ${NEW_LIBMNL_VER}|" DEBIAN/control
	sed -i "s|^Installed-Size: .*|Installed-Size: $(du -s usr | awk '{print $1}')|" DEBIAN/control
	sed -i "s|^Depends: .*|Depends: libmnl0 (= ${NEW_LIBMNL_VER})|" DEBIAN/control
	find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
	cd ..
	dpkg-deb --build --root-owner-group ${DIR}
	apt install -y ./${DIR}.deb
	mv ${DIR}.deb ${PPA:-"${BUILD}"}
}

#================================================================================
# Setup our environment and run our functions:
source ~/.bash_aliases
[[ -z "${BUILD}" ]] && BUILD=/build
[[ ! -d ${BUILD}/libmnl || "$1" =~ (-f|--force) ]] && libmnl_compile
libmnl_version
libmnl_package
