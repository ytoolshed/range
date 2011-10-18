package Seco::Data::Range::Simple;
=head1 NAME

  Seco::Data::Range::Simple

=head1

 Not meant to be used directly. This super simple stub is for loading
 into other bootstrap software such as a ybiip profile where
 the environment is not fully set up (no lwp)

 usage: simple_range("rangehost.yahoo.com", 9999, '@ALL');

Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.  

=cut


sub simple_range {
    my ($rangehost, $rangeport, $rangequery, $timeout) = @_;
    $timeout ||= 15;
    my $s = IO::Socket::INET->new(
                                  PeerHost => $rangehost,
                                  PeerPort => $rangeport,
                                  Proto => "tcp",
                                  Timeout => $timeout,
                                 );
    syswrite $s, "GET /range/list?$rangequery\n";
    my @names = <$s>;
    chomp for @names;
    return @names;
}

1;

=head1 AUTHOR

Evan Miller, E<lt>eam@yahoo-inc.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 Yahoo! Inc.

=cut
