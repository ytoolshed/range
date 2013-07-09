#!/usr/bin/perl -w

use warnings;
use strict;

use Test::More;
use FindBin;
use File::Temp;

my $config_base = "$FindBin::Bin/test_configs/crange1";
my $build_root = $ENV{DESTDIR} || "$ENV{HOME}/prefix";
my ($range_conf_fh, $range_conf) = File::Temp::tempfile();

#FIXME should probably sort outputs for stable tests

#FIXME allow setting of lr->funcdir in range.conf
# to let me funcdir=$build_root/usr/lib/libcrange
# and remove other refs to $build_root
my $range_conf_data = qq{
dns_data_file=$config_base/etc/dns_data.tinydns
yst_ip_list=$config_base/etc/yst-ip-list
yaml_path=$config_base/rangedata
loadmodule $build_root/usr/lib/libcrange/yamlfile
loadmodule $build_root/usr/lib/libcrange/ip
loadmodule $build_root/usr/lib/libcrange/yst-ip-list
};

print $range_conf_fh $range_conf_data;


$ENV{DESTDIR} = "$ENV{HOME}/prefix";
$ENV{PATH} = "$ENV{DESTDIR}/usr/bin:$ENV{PATH}";
$ENV{LD_LIBRARY_PATH} = "$ENV{DESTDIR}/usr/lib"; #FIXME should be lib64 for a 64bit build

# just md5sum outputs for now to make sure we're returning consistent data
is( `crange -e 'foo - foo'`,
    qq{},
    "foo - foo",
    );

is( `crange -e 'foo - bar'`,
    qq{foo\n},
    "foo - bar",
    );

is( `crange -e 'foo & foo'`,
    qq{foo\n},
    "foo & foo",
    );

is( `crange -e 'foo & bar'`,
    qq{},
    "foo & bar",
    );

is( `crange -e 'foo,bar'`,
    qq{foo\nbar\n},
    "foo,bar",
    );

is( `crange -e 'foo & /foo/'`,
    qq{foo\n},
    "foo & /foo/",
    );

is( `crange -e 'foo,bar,baz - /^b/'`,
    qq{foo\n},
    "foo,bar,baz - /^b/",
    );

is( `crange -e '(foo,bar,baz - /^b/), baz'`,
    qq{foo\nbaz\n},
    "(foo,bar,baz - /^b/), baz",
    );

is( `crange -e '{foo,bar,baz}.example.com - /^b/'`,
    qq{foo.example.com\n},
    "{foo,bar,baz}.example.com - /^b/",
    );

done_testing();
