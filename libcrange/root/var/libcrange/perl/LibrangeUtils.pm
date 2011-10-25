package LibrangeUtils;

sub functions_provided {
    return qw/clean limit count even odd/;
}

sub clean {
    my ( $rr, $range ) = @_;
    my @result = map { s/\.inktomisearch\.com//; $_ } @$range;
    return @result;
}

sub count {
    my ( $rr, $range ) = @_;
    return scalar @$range;
}

sub limit {
    my ( $rr, $r_limit, $range ) = @_;
    my $limit = $r_limit->[0];
    my @range = @$range;
    return @range[ 0 .. ( $limit - 1 ) ];
}

sub even {
    my ( $rr, $range ) = @_;
    my @result = grep { /[02468]\z/ms } @$range;
    return @result;
}

sub odd {
    my ( $rr, $range ) = @_;
    my @result = grep { /[13579](?:\.inktomisearch\.com)?\z/ms } @$range;
    return @result;
}

1;
