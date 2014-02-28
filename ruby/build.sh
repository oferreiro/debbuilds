#!/bin/bash
CURR=`pwd`
BUILD="${CURR}/build"
SRCFILE=$(ls ruby-*.tar.bz2|sort -r|head -n1)
COMPILE="${BUILD}/$(echo ${SRCFILE}|sed 's/\.tar\.bz2//')"
FIRSTNAME=$(echo ${SRCFILE}|sed 's/-.*\.tar\.bz2'//)
VERSION=$(echo ${SRCFILE}|sed "s/${FIRSTNAME}-//"|sed 's/\.tar\.bz2//')
SUBNAME=$(echo ${VERSION}|sed 's/\-.*$//')
NAME=${FIRSTNAME}${SUBNAME}
TMPDIR=/tmp/${NAME}
DEBDIR=${TMPDIR}/DEBIAN

if [ -z "$ARCH" ]; then
  case "$( uname -m )" in
    i?86) ARCH=i486 ;;
    arm*) ARCH=arm ;;
    x86_64) ARCH=amd64;;	
       *) ARCH=$( uname -m ) ;;
  esac
fi

comp_prg(){
	
	if ! ls ${SRCFILE} >/dev/null; then
		echo "source file ${SRCFILE} not found"
		exit
	fi
	if [ -x ${COMPILE} ]; then 
		rm -rf ${COMPILE}
	fi
	
	if [ ! -x ${BUILD} ]; then
		mkdir -p ${BUILD} 
	fi 

	tar -xjvf ${SRCFILE} -C ${BUILD}
	cd ${COMPILE}
	./configure --enable-shared
	make
}

make_pack(){
	if [ -x ${TMPDIR} ]; then
		rm -rf ${TMPDIR}
	fi
	cd ${COMPILE}
	make install DESTDIR=${TMPDIR}
	mkdir $DEBDIR
	SIZE=`du -sx --exclude DEBIAN  ${TMPDIR}|tr '\t' ' '|sed 's/ .*//'`
	
	# package label
	cat > ${DEBDIR}/control << EOF
Package: ${NAME}
Version: ${VERSION}
Section: custom
Priority: optional
Architecture: ${ARCH}
Essential: no
Installed-Size: ${SIZE}
Maintainer: oseias@oferreiro.info
Description: Last version of ruby compiled for my personal use
EOF
	
	cd "${TMPDIR}/../"
	dpkg-deb --build ${NAME}
	mv ${NAME}.deb "${CURR}/${NAME}-${VERSION}_${ARCH}.deb"
	rm -rf ${TMPDIR}
}


case "$1" in
	compile)
	comp_prg
	;;
	pkg)
	make_pack
	;;
	clean)
	rm -rf ./${COMPILE}
	;;
	deps)
	case $(lsb_release -rs) in
		6.*)
			apt-get install libc6-dev libssl-dev libreadline5-dev zlib1g-dev
		;;
		7.*)
			apt-get install libc6-dev libssl-dev libreadline-dev zlib1g-dev
		;;
	esac	
	;;
	*)
	echo "$0 (compile | pkg | clean | deps)"
	;;
esac
