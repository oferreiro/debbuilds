#!/bin/bash
SRCURL="ftp://ftp.ruby-lang.org/pub/ruby/1.9/ruby-1.9.2-p290.tar.bz2"
SRCFILE='ruby-1.9*.tar.bz2'
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

download_src(){
    while true
    do
        echo "Source file not found. Download? (Y/n)."
        read -s  answer

        if [[ $answer = "" ]]; then
            answer=y;
        fi

        case  "$answer" in
            Y|y)
            wget ${SRCURL} | return -1             
            SRCFILE=`ls ${SRCFILE}`
            return 0
            break
            ;;
            N|n)
            echo "Is not possible continue without source file. Download it manualy on http://www.ruby-lang.org"
            return -1
            break
            ;;
            *)
            echo "\"$answer\" is not an answer. Please answer y(yes) or n(no)." 
            ;;
        esac
done


}

comp_prg(){
	while true
    do
	    if ! ls ${SRCFILE} >/dev/null; then
            if download_src; then 
                break
            else
                echo "Is not possible download srcfile."
                exit
                break
            fi
        else
            break
    	fi
    done

	if [ -x ./${COMPILE} ]; then 
		rm -rf ./${COMPILE}
	fi
	
    tar -xjvf ${SRCFILE} -C .

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
