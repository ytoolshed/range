#!/usr/bin/perl -w

use warnings;
use strict;

use Test::More;

$ENV{DESTDIR} = "$ENV{HOME}/prefix";
$ENV{PATH} = "$ENV{DESTDIR}/usr/bin:$ENV{PATH}";
$ENV{LD_LIBRARY_PATH} = "$ENV{DESTDIR}/usr/lib"; #FIXME should be lib64 for a 64bit build

# just md5sum outputs for now to make sure we're returning consistent data
is( `crange -e foo100..10|md5sum`, "4364b988cf558c91d49786b83da444e4  -\n", "foo100..10");



done_testing();
