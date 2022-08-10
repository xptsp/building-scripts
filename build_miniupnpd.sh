#!/bin/bash
if ! ischroot; then echo "ERROR: Not in a chroot environment!  Aborting!"; exit 1; fi

#================================================================================
# Function to build the "iptables" package, needed to compile "miniupnpd-iptables" package:
function iptables_compile() {
	[[ "$(find ${BUILD}/miniupnp/miniupnpd/modded -maxdepth 1 -name iptables* -type d | wc -l)" -gt 0 ]] && return
	mkdir -p ${BUILD}/iptables 
	pushd ${BUILD}/
	apt source iptables
	IPTABLES_DIR=$(find ${BUILD}/miniupnp/miniupnpd/modded -maxdepth 1 -name iptables* -type d)
	cd ${IPTABLES_DIR}
	./configure --enable-static
	make
	popd
}

#================================================================================
# Compile latest version of "miniupnpd-nftables" and "miniupnpd-iptables":
function miniupnp_compile() {
	# Pull the repo from GitHub:
	cd ${BUILD}
	git clone git://github.com/miniupnp/miniupnp
	cd ${BUILD}/miniupnp/miniupnpd
	DEB_VERSION=$(grep -m 1 "^VERSION" Changelog.txt | awk '{print $2}')
	DEB_RELEASE=$(git_version miniupnp/miniupnpd ${MINIUPNPD_BUILD})
	DEB_RELEASE=${DEB_RELEASE/-/}

	# Compile the code for "miniupnpd-nftables":
	./configure  --firewall=nftables
	make clean
	make
	checkinstall -y -install=no --pkgname=miniupnpd-nftables --pkgversion=${DEB_VERSION} --pkgrelease=${DEB_RELEASE} --requires='"libc6 (>= 2.28), libmnl0 (>= '${NEW_LIBMNL_VER}'), libnftnl11 (>= '${NEW_LIBNFTNL_VER}')"' --conflicts=miniupnpd-iptables
	DIR=miniupnpd-nftables_${DEB_VERSION}-${DEB_RELEASE}_armhf
	dpkg-deb -R ${DIR}.deb install-nftables

	# Compile the code for "miniupnpd-iptables":
	IPTABLES_DIR=$(find ${BUILD}/miniupnp/miniupnpd/modded -maxdepth 1 -name iptables* -type d)
	[[ -z "${IPTABLES_DIR}" ]] && iptables_compile
	./configure --iptablespath=${IPTABLES_DIR} --firewall=iptables
	make clean
	make
	checkinstall -y -install=no --pkgname=miniupnpd-iptables --pkgversion=${DEB_VERSION} --pkgrelease=${DEB_RELEASE} --requires='"iptables, libc6 (>= 2.28), libip4tc2 (>= 1.8.3), libip6tc2 (>= 1.8.3)"' --conflicts=miniupnpd-nftables
	DIR=miniupnpd-iptables_${DEB_VERSION}-${DEB_RELEASE}_armhf
	test -d install && rm -rf install
	dpkg-deb -R ${DIR}.deb install-iptables
}

#================================================================================
# Get version and build numbers for these packages:
function miniupnp_version() {
	MINIUPNPD_BUILD=1
	OLD_MINIUPNPD_VER=$(deb_version miniupnpd-nftables)
	NEW_MINIUPNPD_VER=$(cat ${BUILD}/miniupnp/miniupnpd/install/DEBIAN/control | grep "^Version:" | awk '{print $2}')
}

#================================================================================
# Function to repackage "miniupnpd" package to contain the new files:
function miniupnp_package() {
	cd ${BUILD}/miniupnp/miniupnpd/modded
	DIR=miniupnpd_${NEW_MINIUPNPD_VER}_all
	apt download miniupnpd=${OLD_MINIUPNPD_VER}
	dpkg-deb -R miniupnpd_${OLD_MINIUPNPD_VER}_all.deb ${DIR}
	rm miniupnpd_${OLD_MINIUPNPD_VER}_all.deb
	cd ${BUILD}/miniupnp/miniupnpd/modded/${DIR}
	cp ${BUILD}/miniupnp/miniupnpd/install-nftables/etc/init.d/* etc/init.d/
	cp ${BUILD}/miniupnp/miniupnpd/install-nftables/etc/miniupnpd/miniupnpd_functions.sh etc/miniupnpd/
	rm usr/share/doc/miniupnpd/*
	cp ${BUILD}/miniupnp/miniupnpd/install-nftables/usr/share/doc/miniupnpd-nftables/* usr/share/doc/miniupnpd/
	cp ${BUILD}/miniupnp/miniupnpd/install-nftables/etc/miniupnpd/miniupnpd.conf usr/share/miniupnpd/miniupnpd.conf
	cp ${BUILD}/miniupnp/miniupnpd/install-nftables/etc/miniupnpd/miniupnpd.conf usr/share/miniupnpd/miniupnpd.default
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
# Function to repackage "miniupnpd-nftables" to contain our compiled code:
function miniupnp_nftables_package() {
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
	cp ${BUILD}/miniupnp/miniupnpd/install-nftables/etc/miniupnpd/nft_*.sh etc/miniupnpd/
	cp ${BUILD}/miniupnp/miniupnpd/install-nftables/usr/sbin/* usr/sbin/
	rm usr/share/doc/miniupnpd-nftables/*
	cp ${BUILD}/miniupnp/miniupnpd/install-nftables/usr/share/doc/miniupnpd-nftables/* usr/share/doc/miniupnpd-nftables/
	sed -i "s|^Version: .*|Version: ${NEW_MINIUPNPD_VER}|" DEBIAN/control
	sed -i "s|^Installed-Size: .*|Installed-Size: $(( $(du -s . | awk '{print $1}') - $(du -s DEBIAN | awk '{print $1}') ))|" DEBIAN/control
	LINE="$(cat ${BUILD}/miniupnp/miniupnpd/install-nftables/DEBIAN/control | grep "Depends:")"
	sed -i "s|^Depends: .*|${LINE}|" DEBIAN/control
	find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
	cd ..
	dpkg-deb --build --root-owner-group ${DIR}
}

#================================================================================
# Function to repackage "miniupnpd-iptables" to contain our compiled code:
function miniupnp_iptables_package() {
	cd ${BUILD}/miniupnp/miniupnpd/modded
	DIR=miniupnpd-iptables_${NEW_MINIUPNPD_VER}_armhf
	apt download miniupnpd-iptables=${OLD_MINIUPNPD_VER}
	dpkg-deb -R miniupnpd-iptables_${OLD_MINIUPNPD_VER}_armhf.deb ${DIR}
	rm miniupnpd-iptables_${OLD_MINIUPNPD_VER}_armhf.deb
	cd ${BUILD}/miniupnp/miniupnpd/modded/${DIR}
	cp ${BUILD}/miniupnp/miniupnpd/install-iptables/etc/miniupnpd/ip*.sh etc/miniupnpd/
	cp ${BUILD}/miniupnp/miniupnpd/install-iptables/usr/sbin/* usr/sbin/
	rm usr/share/doc/miniupnpd-iptables/*
	cp ${BUILD}/miniupnp/miniupnpd/install-iptables/usr/share/doc/miniupnpd-iptables/* usr/share/doc/miniupnpd-iptables/
	sed -i "s|^Version: .*|Version: ${NEW_MINIUPNPD_VER}|" DEBIAN/control
	sed -i "s|^Installed-Size: .*|Installed-Size: $(( $(du -s . | awk '{print $1}') - $(du -s DEBIAN | awk '{print $1}') ))|" DEBIAN/control
	LINE="$(cat ${BUILD}/miniupnp/miniupnpd/install-iptables/DEBIAN/control | grep "Depends:")"
	sed -i "s|^Depends: .*|${LINE}|" DEBIAN/control
	find usr -type f -exec md5sum {} \; > DEBIAN/md5sums
	cd ..
	dpkg-deb --build --root-owner-group ${DIR}
}

# Setup our environment:
source ~/.bash_aliases
[[ -z "${BUILD}" ]] && BUILD=/build
source ./build_libnftnl11.sh
iptables_compile
miniupnp_compile
miniupnp_version
miniupnp_package
miniupnp_nftables_package
miniupnp_iptables_package
