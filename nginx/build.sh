#!/bin/sh
PREFIX='/usr/local'
CONFDIR='/etc/nginx'
SRCFILE=`ls nginx-1*.tar.gz`
NAME=`echo ${SRCFILE}|sed 's/-.*\.tar\.gz'//`
VERSION=`echo ${SRCFILE}|sed "s/${NAME}-//"|sed 's/\.tar\.gz//'`
CURR=`pwd`
BUILD="${CURR}/build"
COMPILE="${BUILD}/`echo ${SRCFILE}|sed 's/\.tar\.gz//'`"
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
	if [ -x ${COMPILE} ]; then 
		rm -rf ${COMPILE}
	fi
	
	if ! ls ${SRCFILE} >/dev/null; then
		echo "Source file ${SRCFILE} not found"
		exit
	fi

	if [ ! -x ${BUILD} ]; then
		mkdir -p ${BUILD}
	fi
 
	tar -xzvf ${SRCFILE} -C ${BUILD}
	cd ${COMPILE}

	if ! which passenger-config >/dev/null; then  
		echo "passenger-config not found. Install passenger first (#gem install passenger)"
		exit 
	fi

	PASSENGER_EXT=`passenger-config --root`/ext/nginx

	./configure \
	  --prefix="${PREFIX}" \
	  --sbin-path="${PREFIX}/sbin/nginx" \
	  --conf-path=${CONFDIR}/nginx.conf \
	  --pid-path=/var/run/nginx.pid \
	  --lock-path=/var/lock/nginx \
	  --user=nobody \
	  --group=nogroup \
	  --error-log-path=/var/log/nginx/error.log \
	  --http-log-path=/var/log/nginx/access.log \
	  --with-ipv6 \
	  --with-rtsig_module \
	  --with-select_module \
	  --with-poll_module \
	  --with-http_ssl_module \
	  --with-http_realip_module \
	  --with-http_addition_module \
	  --with-http_xslt_module \
	  --with-http_sub_module \
	  --with-http_dav_module \
	  --with-http_flv_module \
	  --with-http_gzip_static_module \
	  --with-http_random_index_module \
	  --with-http_secure_link_module \
	  --with-http_stub_status_module \
	  --with-http_perl_module \
	  --with-perl_modules_path=$installvendorlib \
	  --http-client-body-temp-path=/var/tmp/nginx_client_body_temp \
	  --http-proxy-temp-path=/var/tmp/nginx_proxy_temp \
	  --http-fastcgi-temp-path=/dev/shm \
	  --without-mail_pop3_module \
	  --without-mail_imap_module \
	  --without-mail_smtp_module \
	  --add-module=$PASSENGER_EXT
	make
}

make_pack(){
	if [ -x ${TMPDIR} ]; then
		rm -rf ${TMPDIR}
	fi
	cd ${COMPILE}
	make install DESTDIR=${TMPDIR}
	
	mkdir ${DEBDIR}
	mkdir ${TMPDIR}/etc/init.d
	cp "${CURR}/inst-scripts/nginx" "${TMPDIR}/etc/init.d/"
	cp "${CURR}/inst-scripts/postinst" ${DEBDIR}
	cp "${CURR}/inst-scripts/prerm" ${DEBDIR}
	chmod 755 ${DEBDIR}/postinst
	chmod 755 ${DEBDIR}/prerm
	chmod 755 ${TMPDIR}/etc/init.d/nginx
	
	
	SIZE=`du -sx --exclude DEBIAN  ${TMPDIR}|tr '\t' ' '|sed 's/ .*//'`
	cat > ${DEBDIR}/control << EOF
Package: ${NAME}
Version: ${VERSION}
Section: custom
Priority: optional
Architecture: ${ARCH}
Essential: no
Installed-Size: ${SIZE}
Maintainer: oferreiro.info
Description: nginx http server with passenger module support
EOF
	for i in `ls ${TMPDIR}${CONFDIR}/|grep -v default`; do
		echo ${CONFDIR}/$i >> ${DEBDIR}/conffiles
	done
	echo '/etc/init.d/nginx' >>  ${DEBDIR}/conffiles
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
	apt-get install build-essential zlib1g-dev libssl-dev libpq-dev subversion libcurl4-openssl-dev libmysqlclient-dev libpcre3-dev libxslt1-dev libperl-dev libgcrypt11-dev libcrypto++-dev
	;;
	*)
	echo "$0 (compile | pkg | clean | deps)"
	;;
esac
