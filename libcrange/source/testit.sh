#!/usr/bin/perl -w

use warnings;
use strict;

use Test::More;

$ENV{DESTDIR} = "$ENV{HOME}/prefix";
$ENV{PATH} = "$ENV{DESTDIR}/usr/bin:$ENV{PATH}";
$ENV{LD_LIBRARY_PATH} = "$ENV{DESTDIR}/usr/lib"; #FIXME should be lib64 for a 64bit build

system "find $ENV{DESTDIR}

# just md5sum outputs for now to make sure we're returning consistent data
is( `crange -e foo100..10|md5sum`,
    "4364b988cf558c91d49786b83da444e4  -\n",
    "foo100..10 # noconfig");

is(
   `crange  -c $ENV{DESTDIR}/etc/range.conf foo100..1 -e 2>&1`,
   qq{foo100\nfoo101\n},
   "foo100..1 # using range.conf",
  );

is(
  `crange  -c /home/eam/prefix/etc/range.conf -e  'vlan(foo1.example.com)'`,
  qq{"1.2.3.0/24"\n},
  "vlan(foo1.example.com)",
  );


is(
  `crange  -c /home/eam/prefix/etc/range.conf -e  '\@bar'`,
  qq{foo1.example.com\nfoo2.example.com\n},
  '@bar',
  );

is(
  `crange  -c /home/eam/prefix/etc/range.conf -e  'has(bar;foo1.example.com)'`,
  qq{GROUPS\n},
  'has(bar;foo1.example.com) # should work',
  );

my @arg_needing_funcs = qw(
  mem cluster clusters group get_cluster get_groups has 
  vlan dc hosts_v hosts_dc vlans_dc ip group
);

my @no_arg_funcs = qw(
  allclusters 
);

for my $func (@arg_needing_funcs) {
  is(
    `crange  -c /home/eam/prefix/etc/range.conf -e '$func()'`,
    qq{},
    "$func() # should return empty",
    );
}

done_testing();
