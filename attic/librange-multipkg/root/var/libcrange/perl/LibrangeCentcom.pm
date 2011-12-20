package LibrangeCentcom;

sub functions_provided {
    return qw/centcom_environment centcom_services centcom_facility
      centcom_status/;
}

sub centcom_status {
    eval "require Centcom;";
    return () if ($@);
    my ( $rr, $range ) = @_;
    my @ret;
    my $centcom = Centcom->new;
    for my $status (@$range) {
        push @ret, $centcom->findHosts( { status => $status } );
    }
    return @ret;
}

sub centcom_facility {
    eval "require Centcom;";
    return () if ($@);
    my ( $rr, $range ) = @_;
    my @ret;
    my $centcom = Centcom->new;
    for my $env (@$range) {
        push @ret, $centcom->findHosts( { facility => $env } );
    }
    return @ret;
}

sub centcom_services {
    eval "require Centcom;";
    return () if ($@);
    my ( $rr, $range ) = @_;
    my @ret;
    my $centcom = Centcom->new;
    for my $env (@$range) {
        push @ret, $centcom->findHosts( { services => $env } );
    }
    return @ret;
}

sub centcom_environment {
    eval "require Centcom;";
    return () if ($@);
    my ( $rr, $range ) = @_;
    my @ret;
    my $centcom = Centcom->new;
    for my $env (@$range) {
        push @ret, $centcom->findHosts( { environment => $env } );
    }
    return @ret;
}

1;
