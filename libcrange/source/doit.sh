#!/bin/sh

set -e
set -x
export DESTDIR=$HOME/prefix

rm -rf $DESTDIR || exit 1
#make clean # this can fail

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


# configure dns zonefile data
DNS_FILE=$DESTDIR/etc/dns_data.tinydns
echo dns_data_file=$DNS_FILE >> $DESTDIR/etc/range.conf
echo "+foo1.example.com:1.2.3.1:0" >> $DNS_FILE
echo "+foo1.example.com:1.2.3.1:0" >> $DNS_FILE
echo "+foo2.example.com:1.2.3.2:0" >> $DNS_FILE
echo "+foo3.example.com:1.2.3.3:0" >> $DNS_FILE
echo "+foo4.example.com:1.2.3.4:0" >> $DNS_FILE

#configure site -> netblocks
YST_IP_LIST_FILE=$DESTDIR/etc/yst-ip-list
echo yst_ip_list=$YST_IP_LIST_FILE >> $DESTDIR/etc/range.conf
echo "foosite 1.2.3.0/24" >> $YST_IP_LIST_FILE

# configure nodes.cf / yamlfile
RANGE_DATADIR=$DESTDIR/rangedata
mkdir -p $RANGE_DATADIR
echo yaml_path=$RANGE_DATADIR >> $DESTDIR/etc/range.conf
# FIXME order matters in this file, yaml_path must be set before yamlfile loads
echo loadmodule $DESTDIR/usr/lib/libcrange/yamlfile >>  $DESTDIR/etc/range.conf 

# load the rest of modules last
echo loadmodule $DESTDIR/usr/lib/libcrange/ip >>  $DESTDIR/etc/range.conf 
echo loadmodule $DESTDIR/usr/lib/libcrange/yst-ip-list >>  $DESTDIR/etc/range.conf 

# Before perlmodules are loaded, set var for @INC
echo perl_inc_path=$DESTDIR/usr/local/lib64/perl5:$DESTDIR/var/libcrange/perl >> $DESTDIR/etc/range.conf
echo perlmodule LibrangeUtils >>  $DESTDIR/etc/range.conf
echo perlmodule LibrangeAdminscf >> $DESTDIR/etc/range.conf



# Create some cluster data

echo "---" >> $RANGE_DATADIR/GROUPS.yaml
echo "bar:" >> $RANGE_DATADIR/GROUPS.yaml
echo "- foo1..2.example.com" >> $RANGE_DATADIR/GROUPS.yaml

