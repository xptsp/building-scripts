#!/bin/bash

#================================================================================
# Compile latest version of "miniupnpd-nftables" for armhf:
function miniupnp_compile() {
	cd ${BUILD}
	git clone git://github.com/miniupnp/miniupnp
	cd ${BUILD}/miniupnp/miniupnpd
	./configure  --firewall=nftables
	make clean
	make
	miniupnp_version
	DEB_VERSION=$(grep -m 1 "^VERSION" Changelog.txt | awk '{print $2}')
	DEB_RELEASE=$(git_version miniupnp/miniupnpd ${MINIUPNPD_BUILD})
	DEB_RELEASE=${DEB_RELEASE/-/}
	checkinstall -y -install=no --pkgname=miniupnpd-nftables --pkgversion=${DEB_VERSION} --pkgrelease=${DEB_RELEASE} --requires='"libc6 (>= 2.28), libmnl0 (>= '${NEW_LIBMNL_VER}'), libnftnl11 (>= '${NEW_LIBNFTNL_VER}')"' --conflicts=miniupnpd-iptables
	DIR=miniupnpd-nftables_${DEB_VERSION}-${DEB_RELEASE}_armhf
	dpkg-deb -R ${DIR}.deb install
}

#================================================================================
# Get version and build numbers for these packages:
function miniupnp_version() {
	MINIUPNPD_BUILD=1
	OLD_MINIUPNPD_VER=$(deb_version miniupnpd-nftables)
	NEW_MINIUPNPD_VER=$(cat ${BUILD}/miniupnp/miniupnpd/install/DEBIAN/control | grep "^Version:" | awk '{print $2}')
}

#================================================================================
# Function to repackage existing packages to contain our compiled code:
function miniupnp_package() {
	#================================================================================
	# Modify created deb package for "miniupnpd-nftables" so they install correctly:
	test -d ${BUILD}/miniupnp/miniupnpd/modded && rm -rf ${BUILD}/miniupnp/miniupnpd/modded
	mkdir -p ${BUILD}/miniupnp/miniupnpd/modded
	cd ${BUILD}/miniupnp/miniupnpd/modded
	DIR=miniupnpd-nftables_${NEW_MINIUPNPD_VER}_armhf
	apt download miniupnpd-nftables=${OLD_MINIUPNPD_VER}
	dpkg-deb -R miniupnpd-nftables_${OLD_MINIUPNPD_VER}_armhf.deb ${DIR}
	rm miniupnpd-nftables_${OLD_MINIUPNPD_VER}_armhf.deb
	cd ${BUILD}/miniupnp/miniupnpd/modded/${DIR}
	cp ${BUILD}/miniupnp/miniupnpd/install/etc/miniupnpd/nft_*.sh etc/miniupnpd/
	cp ${BUILD}/miniupnp/miniupnpd/install/usr/sbin/* usr/sbin/
	rm usr/share/doc/miniupnpd-nftables/*
	cp ${BUILD}/miniupnp/miniupnpd/install/usr/share/doc/miniupnpd-nftables/* usr/share/doc/miniupnpd-nftables/
	sed -i "s|^Version: .*|Version: ${NEW_MINIUPNPD_VER}|" DEBIAN/control
	sed -i "s|^Installed-Size: .*|Installed-Size: $(( $(du -s . | awk '{print $1}') - $(du -s DEBIAN | awk '{print $1}') ))|" DEBIAN/control
	LINE="$(cat ${BUILD}/miniupnp/miniupnpd/install/DEBIAN/control | grep "Depends:")"
	sed -i "s|^Depends: .*|${LINE}|" DEBIAN/control
	find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
	cd ..
	dpkg-deb --build --root-owner-group ${DIR}

	#================================================================================
	# Modify created deb package for "miniupnpd" so they install correctly:
	cd ${BUILD}/miniupnp/miniupnpd/modded
	DIR=miniupnpd_${NEW_MINIUPNPD_VER}_all
	apt download miniupnpd=${OLD_MINIUPNPD_VER}
	dpkg-deb -R miniupnpd_${OLD_MINIUPNPD_VER}_all.deb ${DIR}
	rm miniupnpd_${OLD_MINIUPNPD_VER}_all.deb
	cd ${BUILD}/miniupnp/miniupnpd/modded/${DIR}
	cp ${BUILD}/miniupnp/miniupnpd/install/etc/init.d/* etc/init.d/
	cp ${BUILD}/miniupnp/miniupnpd/install/etc/miniupnpd/miniupnpd_functions.sh etc/miniupnpd/
	rm usr/share/doc/miniupnpd/*
	cp ${BUILD}/miniupnp/miniupnpd/install/usr/share/doc/miniupnpd-nftables/* usr/share/doc/miniupnpd/
	cp ${BUILD}/miniupnp/miniupnpd/install/etc/miniupnpd/miniupnpd.conf usr/share/miniupnpd/miniupnpd.conf
	cp ${BUILD}/miniupnp/miniupnpd/install/etc/miniupnpd/miniupnpd.conf usr/share/miniupnpd/miniupnpd.default
	cp ${BUILD}/miniupnp/miniupnpd/linux/miniupnpd.init.d.script etc/init.d/miniupnpd
	cp ${BUILD}/miniupnp/miniupnpd/linux/miniupnpd.service lib/systemd/system/
	rm -rf usr/share/man
	sed -i "s|^Version: .*|Version: ${NEW_MINIUPNPD_VER}|" DEBIAN/control
	sed -i "s|^Installed-Size: .*|Installed-Size: $(( $(du -s . | awk '{print $1}') - $(du -s DEBIAN | awk '{print $1}') ))|" DEBIAN/control
	find . -type f -exec md5sum {} \; | grep -v DEBIAN > DEBIAN/md5sums
	cd ..
	dpkg-deb --build --root-owner-group ${DIR}
}

#================================================================================
# Function to compile latest version of "miniupnpd-iptables":
function iptables_compile() {
	#================================================================================
	# Build the "iptables" package.  Needs to in order to compile the "miniupnpd-iptables" package:
	mkdir -p ${BUILD}/iptables 
	cd ${BUILD}/miniupnp/miniupnpd/modded
	apt source iptables
	IPTABLES_DIR=${BUILD}/miniupnp/miniupnpd/modded/iptables-$(deb_version iptables | cut -d- -f 1)
	cd iptables-${IPTABLES_DIR}
	./configure --enable-static
	make

	#================================================================================
	# Compile latest version of "miniupnpd-iptables":
	cd ${BUILD}/miniupnp/miniupnpd
	./configure --iptablespath=${IPTABLES_DIR}
	make clean
	make
}

# Setup our environment:
source ~/.bash_aliases
[[ -z "${BUILD}" ]] && BUILD=/build
source ./build_libnftnl11.sh
miniupnp_compile
miniupnp_version
miniupnp_package
[[ ! -d ${BUILD}/iptables || "$1" =~ (-f|--force) ]] && iptables_compile
miniupnp_iptables_compile
