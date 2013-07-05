#!/bin/sh

set -e
set -x
export DESTDIR=$HOME/prefix

rm -rf $DESTDIR || exit 1
make clean || exit 1

aclocal || exit 1
libtoolize --force || exit 1
autoheader || exit 1
automake -a || exit 1
autoconf || exit 1
./configure --prefix=/usr || exit 1
make || exit 1
make install  || exit 1
cd perl
sh ./build || exit 1
cd ..

cp -a ../root/* $DESTDIR/

# hacks to get config going
#mkdir $DESTDIR/etc
# cp ../root/etc/libcrange.conf.example $DESTDIR/etc/range.conf 

echo loadmodule $DESTDIR/usr/lib/libcrange/ip >>  $DESTDIR/etc/range.conf 
echo loadmodule $DESTDIR/usr/lib/libcrange/yst-ip-list >>  $DESTDIR/etc/range.conf 
echo loadmodule $DESTDIR/usr/lib/libcrange/nodescf >>  $DESTDIR/etc/range.conf 
echo perlmodule LibrangeUtils >>  $DESTDIR/etc/range.conf
echo perlmodule LibrangeAdminscf >> $DESTDIR/etc/range.conf

