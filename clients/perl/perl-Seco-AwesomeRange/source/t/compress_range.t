#!/usr/local/bin/perl -w
# vim:set ft=perl: -*- perl -*-

use Test::More tests => 6;
BEGIN { use_ok('Seco::AwesomeRange',':common')};

ok_cmp_range('ks301000');
ok_cmp_range('%idpproxy_yahoo1');
ok_cmp_range('/nyn/');
ok_cmp_range('/./');
ok_cmp_range('1.2.3.1-1.2.3.255');

sub ok_cmp_range {
    my $what = shift;

    my @what = expand_range($what);
    my $compressed = compress_range(\@what);
    my @expanded = expand_range($compressed);
    #print STDERR scalar @expanded, "\n";
    ok(eq_array([sort @what], [sort @expanded]), 
        "expand(compress(expand($what)))==expand($what)");
}

