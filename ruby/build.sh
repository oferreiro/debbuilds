#!/bin/bash
SRCFILE=`ls ruby-1.9*.tar.bz2`
NAME=`echo ${SRCFILE}|sed 's/-.*\.tar\.bz2'//`
VERSION=`echo ${SRCFILE}|sed "s/${NAME}-//"|sed 's/\.tar\.bz2//'`
COMPILE=`echo ${SRCFILE}|sed 's/\.tar\.bz2//'`
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
	if [ -x ./${COMPILE} ]; then 
		rm -rf ./${COMPILE}
	fi
	tar -xjvf ruby-1.9*.tar.bz2 -C .
	cd $COMPILE
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
	cat > ${DEBDIR}/control << EOF
Package: ${NAME}
Version: ${VERSION}
Section: custom
Priority: optional
Architecture: ${ARCH}
Essential: no
Installed-Size: 80
Maintainer: oferreiro.info
Description: Last version of ruby
EOF
	cd /tmp
	dpkg-deb --build ${NAME}
	mv ${NAME}.deb ${NAME}-${VERSION}_${ARCH}.deb
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
	apt-get install libc6-dev libssl-dev libreadline5-dev zlib1g-dev
	;;
	*)
	echo "$0 (compile | pkg | clean | deps)"
	;;
esac
