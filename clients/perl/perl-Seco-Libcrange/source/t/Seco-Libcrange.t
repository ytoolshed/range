# Before `make install' is performed this script should be runnable with
# `make test'. After `make install' it should work as `perl Seco-Libcrange.t'

#########################

# change 'tests => 13' to 'tests => last_test_to_print';

use Test::More tests => 13;
BEGIN { use_ok('Seco::Libcrange') };

#########################

# Insert your test code below, the Test::More module is use()ed here so read
# its man page ( perldoc Test::More ) for help writing this test script.

my $r = Seco::Libcrange::->new('/etc/libcrange.conf');

ok (compare_arrays([$r->expand('1-2')], ['1','2']), '$r->expand'); 
ok ($r->compress(['1','2']) eq '1-2', '$r->compress(\@)');
ok ($r->compress(('1','2')) eq '1-2', '$r->compress(@)');
ok ($r->compress(('"1.com"','"2.com"')) eq '"1.com","2.com"', '$r->compress(literals)');
ok( !(defined $r->compress(undef)), '$r->compress(undef) returns undef'); 
ok( !(defined $r->compress([])), '$r->compress([]) returns undef'); 
ok( !defined $r->expand('1&2'), '$r->expand("1&2") returns undef'); 
ok( !defined $r->expand(undef), '$r->expand(undef) returns undef'); 
ok('1-2' eq $r->compress($r->expand('1-2')), '$r->compress($r->expand())');
ok('"1.com","2.com"' eq $r->compress($r->expand('"1.com","2.com"')), '$r->compress($r->expand())');
ok('"1.com","2.com"' eq $r->compress($r->expand('q(1.com),q(2.com)')), '$r->compress($r->expand())');
ok('q(1.com),q(2.com)' eq $r->compress('q(1.com),q(2.com)'),'$r->compress()');


sub compare_arrays {
    my ($first, $second) = @_;
    no warnings;  # silence spurious undef complaints
    return 0 unless @$first == @$second;
    for (my $i = 0; $i < @$first; $i++) {
        return 0 if $first->[$i] ne $second->[$i];
    }
    return 1;
}
__END__
