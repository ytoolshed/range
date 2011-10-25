package LibrangeAdminscf;

use Libcrange;
use YAML::Syck;
use warnings 'all';

sub functions_provided {
    return qw/boot_v v_boot boothosts bh/;
}

sub _get_cf {
    my $rr = shift;
    my $path = Libcrange::get_var($rr, "nodescf_path");
    $path ||= "/home/seco/tools/conf";
    my $file = "$path/admins.cf";
    unless (-r $file) {
        Libcrange::warn($rr, "$path/admins.cf not readable");
        return;
    }
    return YAML::Syck::LoadFile($file);
}

sub boot_v {
    my $rr    = shift;
    my $range = shift;

    my $cf = _get_cf($rr);
    return unless $cf;

    my %net_bh;
    while ( my ( $bh, $bh_cfg ) = each(%$cf) ) {
        for my $net ( @{ $bh_cfg->{networks} } ) {
            push @{ $net_bh{$net} }, $bh;
        }
    }

    my @ret;
    for my $net (@$range) {
        $net =~ s/\A"(.*)"\z/$1/s;
        push @ret, @{ $net_bh{$net} };
    }
    return @ret;
}

sub v_boot {
    my $rr    = shift;
    my $range = shift;
    my $cf    = _get_cf();
    return unless $cf;

    my @ret;
    for my $bh (@$range) {
        my $bh_cfg = $cf->{$bh};
        next unless $bh_cfg;

        push @ret, map { qq("$_") } @{ $bh_cfg->{networks} };
    }
    return @ret;
}

sub boothosts {
    my $rr = shift;
    my $cf = _get_cf();
    return keys %$cf;
}

sub bh {
    my ($rr, $range) = @_;
    my $what  = join( ",", @{$range} );
    return Libcrange::expand( $rr, "boot_v(vlan($what))" );
}

1;
