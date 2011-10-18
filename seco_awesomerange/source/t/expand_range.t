#!/usr/local/bin/perl -w
# vim:set ft=perl: -*- perl -*-

use FindBin qw/$Bin/;
use Test::More tests => 48 ;
BEGIN { use_ok('Seco::AwesomeRange', qw/expand_range range_set_altpath/) }

my $altpath="$Bin";
print "altpath=$altpath\n";
range_set_altpath($altpath);

ok_range("Parens 1", "(5,9)", qw/5 9/);
ok_range("Parens 2", "1-10,-(5,9)", qw/1 2 3 4 6 7 8 10/);

ok_range("Numeric range no prefix",
    "1-5", qw/1 2 3 4 5/);
ok_range("Numeric range commas",
    "1,5", qw/1 5/);
ok_range("Simple commas",
    "a1,5", qw/5 a1/);
ok_range("Implicit prefix",
    "foo1-4", qw/foo1 foo2 foo3 foo4/);
ok_range("Explicit prefix",
    "foo1-foo4", qw/foo1 foo2 foo3 foo4/);
ok_range("complex name ranges",
    "foo1r01-foo1r04", qw/foo1r01 foo1r02 foo1r03 foo1r04/);
ok_range("Simple commas 2",
    "foo,bar,baz", qw/bar baz foo/);
ok_range("Parsing commas",
    "foo{1,3},bar,baz{1-3}", qw/bar baz1 baz2 baz3 foo1 foo3/);
ok_range("Multiple braces",
    "foo{1,3}a{2,3}", qw/foo1a2 foo1a3 foo3a2 foo3a3/);
ok_range("Brackets and braces",
    "foo{1-3}a{2,3}", qw/foo1a2 foo1a3 foo2a2 foo2a3 foo3a2 foo3a3/);
ok_range("Leading 0s",
    "foo{01-03}", qw/foo01 foo02 foo03/);
ok_range("Malformed leading 0s",
    "foo{01-3}", qw/foo01 foo02 foo03/);
ok_range("Simple exclude",
    "foo1-4,-foo2", qw/foo1 foo3 foo4/);
ok_range("Range excludes",
    "foo1-9,-foo2-8", qw/foo1 foo9/);
ok_range("Intersection",
    "foo1-5,&foo3-7", qw/foo3 foo4 foo5/);
ok_range("Domains (implicit)",
    "foo1-3.search", qw/foo1.search foo2.search foo3.search/);
ok_range("Domains (explicit)",
    "foo1.search-foo3.search", qw/foo1.search foo2.search foo3.search/);
ok_range("Padding end",
    "ks301000-3", qw/ks301000 ks301001 ks301002 ks301003/);
ok_range("Automatic dequoting",
    '"ks301000-3"', qw/ks301000 ks301001 ks301002 ks301003/);
ok_range("Ignoring whitespace", ' ks301000-1 , ks30-2, foo ,bar ',
    qw/bar foo ks301000 ks301001 ks30 ks31 ks32/);
ok_range("IP Ranges", '66.196.100.10-66.196.100.12',
    qw/66.196.100.10 66.196.100.11 66.196.100.12/);
ok_range("IP Ranges (common prefix)", '66.196.100.10-12',
    qw/66.196.100.10 66.196.100.11 66.196.100.12/);
ok_range("Regex against left side", "foo10-21,&/2/",
    qw/foo12 foo20 foo21/);
ok_range("Regex against left side (set difference)", "foo10-21,-/foo.0/",
    qw/foo11 foo12 foo13 foo14 foo15 foo16 foo17 foo18 foo19 foo21/);

# Parsing clusters
ok_range("Simple cluster", '%test_cluster2', qw/kp2000 vsp2021/);
ok_range("Cluster:PART", '%test_cluster1:ADMIN',
    qw/cocytus haides inferno ka1001 limbo styx/);
ok_range('Cluster:PART with $PART', '%test_cluster1:ALL',
    qw/bar1 bar2 cocytus haides inferno ka1001 kp2000 limbo styx/);
ok_range('Cluster:PART with only $PART', '%test_cluster1:SMARTPOSTFIX',
    qw/cocytus haides inferno ka1001 limbo styx/);
ok_range('Cluster:PART with EXCLUDE $PART', '%test_cluster1:DUMBPOSTFIX',
    qw/bar1 bar2 kp2000/);
ok_range('Cluster:KEYS', '%test_cluster1:KEYS',
    qw/ADMIN ALL DUMBPOSTFIX SMARTPOSTFIX STABLE CLUSTER/);
ok_range('Multiple clusters', '%test_cluster1-2',
    qw/bar1 bar2 cocytus haides inferno ka1001 kp2000 limbo styx vsp2021/);
ok_range('Multiple clusters using braces', '%test_cluster{1,2}',
    qw/bar1 bar2 cocytus haides inferno ka1001 kp2000 limbo styx vsp2021/);
ok_range('Cluster and intersection', '%test_cluster1,&%test_cluster2',
    qw/kp2000/);
ok_range('Cluster and differences', '%test_cluster1,-%test_cluster2',
    qw/bar1 bar2 cocytus haides inferno ka1001 limbo styx/);

ok_range('Cluster:UP','%test_cluster3:UP',
    qw/xy1000 xy1001 xy1002 xy1003 xy1004 xy1006 xy1007 xy1008 xy1009/);
ok_range('Cluster:DOWN','%test_cluster3:DOWN',
    qw/xy1005/);
ok_range('Cluster:VIPS','%test_cluster3:VIPS',
    qw/ 10.1.2.3 10.1.2.4 10.1.2.5 /);

#ok_range('Simple Regex', '/kp/', qw/kp2000/);

range_set_altpath(undef);

# Test get admin function
ok_range("Simple get admin", '^@stress',  qw/stress/);
ok_range("Complex get admin", '^{@stress,@hate}', qw/hate stress/);

# just to verify that @ == %GROUPS:
eq_range('%GROUPS:AC2', '@AC2');
eq_range('%GROUPS:AC2,-%GROUPS:ADMIN', '@AC2,-@ADMIN');
eq_range('%GROUPS:AC2,&%GROUPS:ADMIN', '@AC2,&@ADMIN');
eq_range('%HOSTS:stress', '@stress');
eq_range('%HOSTS:stress,-stress', '@stress,-stress');
eq_range('%HOSTS:stress,&stress', '@stress,&stress');

sub eq_range {
    my ($range1, $range2) = @_;
    ok(eq_array([sort(expand_range($range1))], [sort(expand_range($range2))]),
	"$range1 == $range2");
}

sub ok_range {
    my ($descr, $range, @result) = @_;
    ok(eq_array([sort(expand_range($range))], [sort(@result)]), $descr) or
	diag(join(",", sort(expand_range($range))), "==",
	    join(",", @result));
}
