#!/bin/bash

# Setup our environment:
source ~/.bash_aliases
[[ -z "${BUILD}" ]] && BUILD=/build
test -d ${BUILD}/libnftnl11 || source build_libnftnl11.sh

#################################################################################
# Compile latest version of nft for armhf if not already done:
#################################################################################
if [[ ! -d cd ${BASE}/nftables/ || "$1" =~ (-f|--force)]]; then  
	cd ${BASE}
	git clone git://git.netfilter.org/nftables
	cd ${BASE}/nftables/
	mkdir -p {install,modded}
	./autogen.sh
	./configure --host=arm-linux-gnueabihf --prefix=$PWD/install --with-mini-gmp --without-cli
	make
	make install
fi

#================================================================================
# Get version and build numbers for these packages:
NFTABLES_BUILD=1
OLD_NFTABLES_VER=$(deb_version nftables)
NEW_NFTABLES_VER=$(git_version nftables ${LIBNFTNL_BUILD})

#================================================================================
# Modify existing deb package for "libnftnl-dev" with our compiled files:
cd ${BASE}/nftables/modded
DIR=nftables_${NEW_NFTABLES_VER}_armhf
apt download nftables=${OLD_NFTABLES_VER}
dpkg-deb -R nftables_${OLD_NFTABLES_VER}_armhf.deb ${DIR}
rm nftables_${OLD_NFTABLES_VER}_armhf.deb
cd ${BASE}/nftables/modded/${DIR}
cp ${BASE}/nftables/install/sbin/nft usr/sbin/
rm usr/share/doc/nftables/{changelog,copyright}*
rm usr/share/doc/nftables/examples/*.nft
cp ${BASE}/nftables/install/share/nftables/*.nft usr/share/doc/nftables/examples/
cp ${BASE}/nftables/install/share/doc/nftables/examples/*.nft usr/share/doc/nftables/examples/
cp ${BASE}/nftables/install/share/man/man8/* usr/share/man/man8/
gzip -f usr/share/man/man8/nft.8
sed -i "s|^Version: .*|Version: ${NEW_NFTABLES_VER}|" DEBIAN/control
sed -i "s|^Installed-Size: .*|Installed-Size: $(( $(du -s . | awk '{print $1}') - $(du -s DEBIAN | awk '{print $1}') ))|" DEBIAN/control
LIBNFTABLES1_VER=$(grep -o "libnftables1 (= [^)]*)" DEBIAN/control)
sed -i "s|${LIBNFTABLES1_VER}|libnftables1 (= ${NEW_NFTABLES_VER})|" DEBIAN/control
find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
cd ..
dpkg-deb --build --root-owner-group ${DIR}

#================================================================================
# Modify existing deb package for "libnftables1" with our compiled files:
cd ${BASE}/nftables/modded
DIR=libnftables1_${NEW_NFTABLES_VER}_armhf
apt download libnftables1=${OLD_NFTABLES_VER}
dpkg-deb -R libnftables1_${OLD_NFTABLES_VER}_armhf.deb ${DIR}
rm libnftables1_${OLD_NFTABLES_VER}_armhf.deb
cd ${BASE}/nftables/modded/${DIR}
rm usr/lib/arm-linux-gnueabihf/*
rm -rf usr/share/doc/libnftables1/*
cp ${BASE}/nftables/COPYING usr/share/doc/libnftables1/ 
cp -a ${BASE}/nftables/install/lib/libnftables.so.1* usr/lib/arm-linux-gnueabihf/
cp ${BASE}/nftables/install/share/man/man3/libnftables.3 usr/share/man/man3/
gzip -f usr/share/man/man3/libnftables.3
cp ${BASE}/nftables/install/share/man/man5/libnftables-json.5 usr/share/man/man5/
gzip -f usr/share/man/man5/libnftables-json.5
rm DEBIAN/{shlibs,triggers}
sed -i "s|^Version: .*|Version: ${NEW_NFTABLES_VER}|" DEBIAN/control
sed -i "s|^Installed-Size: .*|Installed-Size: $(du -s usr | awk '{print $1}')|" DEBIAN/control
sed -i "s|$(grep -o "libmnl0 (>= [^)]*)" DEBIAN/control)|libmnl0 (>= ${NEW_LIBMNL_VER})|" DEBIAN/control
sed -i "s|$(grep -o "libnftnl11 (>= [^)]*)" DEBIAN/control)|libnftnl11 (>= ${NEW_LIBNFTNL_VER})|" DEBIAN/control
find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
cd ..
dpkg-deb --build --root-owner-group ${DIR}

#================================================================================
# Modify existing deb package for "libnftables-dev" with our compiled files:
cd ${BASE}/nftables/modded
DIR=libnftables-dev_${NEW_NFTABLES_VER}_armhf
apt download libnftables-dev=${OLD_NFTABLES_VER}
dpkg-deb -R libnftables-dev_${OLD_NFTABLES_VER}_armhf.deb ${DIR}
rm libnftables-dev_${OLD_NFTABLES_VER}_armhf.deb
cd ${BASE}/nftables/modded/${DIR}
rm -rf usr/share/doc/libnftables-dev/*
cp ${BASE}/nftables/COPYING usr/share/doc/libnftables-dev/
cp ${BASE}/nftables/install/include/nftables/* usr/include/nftables/
cp -a ${BASE}/nftables/install/lib/*.so usr/lib/arm-linux-gnueabihf/
cp ${BASE}/nftables/install/lib/pkgconfig/* usr/lib/arm-linux-gnueabihf/pkgconfig/
sed -i "s|^Version: .*|Version: ${NEW_NFTABLES_VER}|" DEBIAN/control
sed -i "s|^Installed-Size: .*|Installed-Size: $(du -s usr | awk '{print $1}')|" DEBIAN/control
sed -i "s|$(grep -o "libnftables1 (= [^)]*)" DEBIAN/control)|libnftables1 (= ${NEW_NFTABLES_VER})|" DEBIAN/control
find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
cd ..
dpkg-deb --build --root-owner-group ${DIR}
apt install -y ./*.deb
mv *.deb ${BASE}