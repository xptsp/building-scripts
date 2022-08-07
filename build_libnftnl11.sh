#!/bin/bash

#################################################################################
# Compile lastest version of libnftnl for armhf if not already done:
#################################################################################
function libnftnl_compile() {
	cd ${BUILD}
	git clone git://git.netfilter.org/libnftnl
	cd ${BUILD}/libnftnl
	mkdir -p install
	./autogen.sh
	./configure --host=arm-linux-gnueabihf --prefix=$PWD/install
	make clean
	make
	make install
}

#================================================================================
# Function to get version and build numbers for these packages:
function libnftnl_version() {
	LIBNFTNL_BUILD=1
	OLD_LIBNFTNL_VER=$(deb_version libnftnl11)
	NEW_LIBNFTNL_VER=$(git_version libnftnl ${LIBNFTNL_BUILD})
}

#================================================================================
# Function to modify existing packages to contain our compiled code: 
function libnftnl_package() {
	#================================================================================
	# Modify existing deb package for "libnftnl11" with our compiled files:
	test -d ${BUILD}/libnftnl/modded && rm -rf ${BUILD}/libnftnl/modded
	mkdir -p ${BUILD}/libnftnl/modded
	cd ${BUILD}/libnftnl/modded
	DIR=libnftnl11_${NEW_LIBNFTNL_VER}_armhf
	apt download libnftnl11=${OLD_LIBNFTNL_VER}
	dpkg-deb -R libnftnl11_${OLD_LIBNFTNL_VER}_armhf.deb ${DIR}
	rm libnftnl11_${OLD_LIBNFTNL_VER}_armhf.deb
	cd ${BUILD}/libnftnl/modded/${DIR}
	rm -rf usr/share/doc/libnftnl11/*
	cp ${BUILD}/libmnl/{README,COPYING} usr/share/doc/libnftnl11/
	rm usr/lib/arm-linux-gnueabihf/*
	cp -a ${BUILD}/libnftnl/install/lib/*.11* usr/lib/arm-linux-gnueabihf/ 
	rm DEBIAN/{shlibs,symbols,triggers}
	sed -i "s|^Version: .*|Version: ${NEW_LIBNFTNL_VER}|" DEBIAN/control
	sed -i "s|^Installed-Size: .*|Installed-Size: $(du -s usr | awk '{print $1}')|" DEBIAN/control
	OLD_DEPENDS=($(grep Depends DEBIAN/control))
	sed -i "s|${OLD_DEPENDS[-1]}|${NEW_LIBMNL_VER}\)|" DEBIAN/control
	find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
	cd ..
	dpkg-deb --build --root-owner-group ${DIR}
	apt install -y ./${DIR}.deb
	rm ${PPA:-"${BUILD}"}/libnftnl*.deb
	mv ${DIR}.deb ${PPA:-"${BUILD}"}

	#================================================================================
	# Modify existing deb package for "libnftnl-dev" with our compiled files:
	DIR=libnftnl-dev_${NEW_LIBNFTNL_VER}_armhf
	apt download libnftnl-dev=${OLD_LIBNFTNL_VER}
	dpkg-deb -R libnftnl-dev_${OLD_LIBNFTNL_VER}_armhf.deb ${DIR}
	rm libnftnl-dev_${OLD_LIBNFTNL_VER}_armhf.deb
	cd ${BUILD}/libnftnl/modded/${DIR}
	rm usr/share/doc/libnftnl-dev/*
	cp ${BUILD}/libnftnl/install/include/libnftnl/* usr/include/libnftnl/
	rm usr/lib/arm-linux-gnueabihf/{lib*,*.a}
	cp -a ${BUILD}/libnftnl/install/lib/libnftnl.so usr/lib/arm-linux-gnueabihf/
	cp -a ${BUILD}/libnftnl/install/lib/pkgconfig/* usr/lib/arm-linux-gnueabihf/pkgconfig/
	sed -i "s|^Version: .*|Version: ${NEW_LIBNFTNL_VER}|" DEBIAN/control
	sed -i "s|^Installed-Size: .*|Installed-Size: $(du -s usr | awk '{print $1}')|" DEBIAN/control
	sed -i "s|$(grep -o "libnftnl11 (= [^)]*)" DEBIAN/control)|libnftnl11 (= ${NEW_LIBNFTNL_VER})|" DEBIAN/control
	find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
	cd ..
	dpkg-deb --build --root-owner-group ${DIR}
	apt install -y ./${DIR}.deb
	mv ${DIR}.deb ${PPA:-"${BUILD}"}
}

# Setup our environment and run our functions:
source ~/.bash_aliases
[[ -z "${BUILD}" ]] && BUILD=/build
source ./build_libmnl0.sh
[[ ! -d ${BUILD}/libnftnl || "$1" =~ (-f|--force) ]] && libnftnl_compile
libnftnl_version
libnftnl_package
