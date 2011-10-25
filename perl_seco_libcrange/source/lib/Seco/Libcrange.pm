package Seco::Libcrange;

# Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
# Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.  

use 5.008005;
use strict;
use warnings;

our $VERSION = '0.01';
require XSLoader;
XSLoader::load('Seco::Libcrange', $VERSION);

# Preloaded methods go here.
sub _extra_compress {
    my $self = shift;
    my @nodes = @{ $_[0] };
    my %domains;
    for (@nodes) {
        s/^([a-z]+)(\d+)([a-z]\w+)\./$1$2.UNDOXXX$3./;
    }   
    my $result = $self->compress_xs(\@nodes);
    for ($result) {
        s/(\d+-\d+)\.UNDOXXX/{$1}/g;
        s/(\d+)\.UNDOXXX/$1/g;
    }
    return $result;
} 

sub compress {
  my $self = shift;
  return unless (defined $_[0]);
  my $ref = ref $_[0];
  my @nodes = $ref ? @{ $_[0] } : @_;
  return unless (@nodes);
  ### UGLY SDR compat
  my %domain;
  my @no_domains;
  foreach my $node (@nodes) {
    ## spare literal's from extra compression
    return $self->compress_xs(\@nodes)
       if ($node =~ /^(?:"|q\()/);
    my ($host, $domain) = split('\.',$node,2);
    if ($domain) {
        push @{ $domain{$domain} }, $node;
    }
    else {
        push @no_domains, $host;
    }
  }
  my @result;
  if (@no_domains) {
    push @result, $self->compress_xs(\@no_domains);
  }
  for my $domain (sort keys %domain) {
    my $r = $self->_extra_compress($domain{$domain});
    for ($r) {
        s/\.$domain,/,/g;
        s/\.$domain$//;
        $_ = "{$_}" if /,/;
    }
    push @result, "$r.$domain";
  }
  return join(",", @result);
}

sub get_range {
    my $r = shift;
    return unless ($_[0]);
    return $r->compress($r->expand($_[0]));
}

sub range_sub {
    my $r = shift;
    my ( $range1, $range2 ) = @_;
    return $range1 unless ( defined $range2 );
    return $r->get_range( $range1 . ",-(" . $range2 . ")" );
}

sub range_add {
    my $r = shift;
    my ( $range1, $range2 ) = @_;
    return $range1 unless ( defined $range2 );
    return $r->get_range( $range1 . ",(" . $range2 . ")" );
}

sub range_and {
    my $r = shift;
    my ( $range1, $range2 ) = @_;
    return $r->get_range( $range1 . ",&(" . $range2 . ")" );
}

sub is_simple_range {
    my $r = shift;
    my $range = shift;
    return 1 if ( $range =~ /^["\s\.\w,\-\{\}]*$/ );
    return 0;
}

1;
__END__

=head1 NAME

Seco::Libcrange - Perl extension for Libcrange

=head1 SYNOPSIS

  use Seco::Libcrange;
  my $r = Seco::Libcrange::->new('/etc/libcrange.conf');
  my @keys = $r->expand('%ngd-ac4-rmxad2p0:KEYS')
  my $range = $r->compress(\@keys);
   or
  my $range = $r->compress(@keys);

=head1 DESCRIPTION
  
  See SYNOPSIS


=head1 AUTHOR

Syam Puranam, E<lt>syam@yahoo-inc.com<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2010 by Yahoo!

=cut

=head1  BUGS

Currently only one instance of Libcrange works :-\
