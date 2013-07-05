#!/usr/bin/perl -w

use warnings;
use strict;

use Test::More;

$ENV{DESTDIR} = "$ENV{HOME}/prefix";
$ENV{PATH} = "$ENV{DESTDIR}/usr/bin:$ENV{PATH}";
$ENV{LD_LIBRARY_PATH} = "$ENV{DESTDIR}/usr/lib"; #FIXME should be lib64 for a 64bit build

# just md5sum outputs for now to make sure we're returning consistent data
is( `crange -e foo100..10|md5sum`, "4364b988cf558c91d49786b83da444e4  -\n", "foo100..10");

# what a hack, need to be able to set perl paths properly
# this is sooo ugly and temporary
is(`PERL5LIB=$ENV{DESTDIR}/usr/local/lib64/perl5 PERLLIB=$ENV{DESTDIR}/var/libcrange/perl crange  -c $ENV{DESTDIR}/etc/range.conf foo100..1 -e 2>&1 |md5sum`, "6b26490a3dbd47f5fda3a7e6f21a8584  -\n", "perl module loading w/o errors");

done_testing();
