#!/bin/bash

# Setup our environment:
source ~/.bash_aliases
[[ -z "${BUILD}" ]] && BUILD=/build
test -d ${BUILD}/libmnl || source build_libmnl0.sh

#################################################################################
# Compile lastest version of libnftnl for armhf if not already done:
#################################################################################
if [[ ! -d ${BASE}/libnftnl || "$1" =~ (-f|--force)]]; then
	cd ${BASE}
	git clone git://git.netfilter.org/libnftnl
	cd ${BASE}/libnftnl
	mkdir -p {install,modded}
	./autogen.sh
	./configure --host=arm-linux-gnueabihf --prefix=$PWD/install
	make clean
	make
	make install
fi

#================================================================================
# Get version and build numbers for these packages.  Exit if packages are build:
LIBNFTNL_BUILD=1
OLD_LIBNFTNL_VER=$(deb_version libnftnl11)
NEW_LIBNFTNL_VER=$(git_version libnftnl ${LIBNFTNL_BUILD})
test -d libnftnl11_${NEW_LIBNFTNL_VER}_armhf && exit 0 

#================================================================================
# Modify existing deb package for "libnftnl11" with our compiled files:
cd ${BASE}/libnftnl/modded
DIR=libnftnl11_${NEW_LIBNFTNL_VER}_armhf
apt download libnftnl11=${OLD_LIBNFTNL_VER}
dpkg-deb -R libnftnl11_${OLD_LIBNFTNL_VER}_armhf.deb ${DIR}
rm libnftnl11_${OLD_LIBNFTNL_VER}_armhf.deb
cd ${BASE}/libnftnl/modded/${DIR}
rm -rf usr/share/doc/libnftnl11/*
cp ${BASE}/libmnl/{README,COPYING} usr/share/doc/libnftnl11/
rm usr/lib/arm-linux-gnueabihf/*
cp -a ${BASE}/libnftnl/install/lib/*.11* usr/lib/arm-linux-gnueabihf/ 
rm DEBIAN/{shlibs,symbols,triggers}
sed -i "s|^Version: .*|Version: ${NEW_LIBNFTNL_VER}|" DEBIAN/control
sed -i "s|^Installed-Size: .*|Installed-Size: $(du -s usr | awk '{print $1}')|" DEBIAN/control
OLD_DEPENDS=($(grep Depends DEBIAN/control))
sed -i "s|${OLD_DEPENDS[-1]}|${NEW_LIBMNL_VER}\)|" DEBIAN/control
find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
cd ..
dpkg-deb --build --root-owner-group ${DIR}
apt install -y ./${DIR}.deb
mv ${DIR}.deb ${BASE}

#================================================================================
# Modify existing deb package for "libnftnl-dev" with our compiled files:
DIR=libnftnl-dev_${NEW_LIBNFTNL_VER}_armhf
apt download libnftnl-dev=${OLD_LIBNFTNL_VER}
dpkg-deb -R libnftnl-dev_${OLD_LIBNFTNL_VER}_armhf.deb ${DIR}
rm libnftnl-dev_${OLD_LIBNFTNL_VER}_armhf.deb
cd ${BASE}/libnftnl/modded/${DIR}
rm usr/share/doc/libnftnl-dev/*
cp ${BASE}/libnftnl/install/include/libnftnl/* usr/include/libnftnl/
rm usr/lib/arm-linux-gnueabihf/{lib*,*.a}
cp -a ${BASE}/libnftnl/install/lib/libnftnl.so usr/lib/arm-linux-gnueabihf/
cp -a ${BASE}/libnftnl/install/lib/pkgconfig/* usr/lib/arm-linux-gnueabihf/pkgconfig/
sed -i "s|^Version: .*|Version: ${NEW_LIBNFTNL_VER}|" DEBIAN/control
sed -i "s|^Installed-Size: .*|Installed-Size: $(du -s usr | awk '{print $1}')|" DEBIAN/control
sed -i "s|$(grep -o "libnftnl11 (= [^)]*)" DEBIAN/control)|libnftnl11 (= ${NEW_LIBNFTNL_VER})|" DEBIAN/control
find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
cd ..
dpkg-deb --build --root-owner-group ${DIR}
apt install -y ./${DIR}.deb
mv ${DIR}.deb ${BASE}
