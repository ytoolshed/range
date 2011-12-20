package Seco::AwesomeRange;

# Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
# Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.

use 5.005_03;
use strict;
use warnings;
use Carp;

require Exporter;
use AutoLoader;

our @ISA = qw(Exporter);

our  @EXPORT_OK = qw/ expand_range range_set_altpath
                      compress_range sorted_expand_range
                      nodes_parser want_warnings want_caching
                      clear_caches get_version
                      expand compress sorted_expand test_range
                    /;             

our %EXPORT_TAGS = (
                       'all' => [ @EXPORT_OK ],
                       'common' => [ qw/ expand_range compress_range 
                                         sorted_expand_range nodes_parser test_range / ],
                    );

our @EXPORT = qw( );

our $VERSION = '0.01';

sub AUTOLOAD {
    # This AUTOLOAD is used to 'autoload' constants from the constant()
    # XS function.

    my $constname;
    our $AUTOLOAD;
    ($constname = $AUTOLOAD) =~ s/.*:://;
    croak "&Seco::AwesomeRange::constant not defined" if $constname eq 'constant';
    my ($error, $val) = constant($constname);
    if ($error) { croak $error; }
    {
	no strict 'refs';
        *$AUTOLOAD = sub { $val };
    }
    goto &$AUTOLOAD;
}

our $raise_exceptions = 0;
our $errno = 0;
require XSLoader;
XSLoader::load('Seco::AwesomeRange', $VERSION);

# Preloaded methods go here.

*expand_range = \&range_expand;
*expand = \&range_expand;
*sorted_expand_range = \&range_expand_sorted;
*sorted_expand = \&range_expand_sorted;
*want_caching = \&range_want_caching;
*want_warnings_real = \&range_want_warnings;
*get_exception = \&range_get_exception;
*clear_exception = \&range_clear_exception;
*clear_caches = \&range_clear_caches;
*get_version = \&range_get_version;


sub range_compress {
    my $ref = ref $_[0];

    if (not $ref) {
        return range_compress_xs(\@_, ",");
    } elsif ($ref eq "ARRAY") {
	return range_compress_xs($_[0], ",")
    } elsif ($ref ne "HASH") {
        croak "range_compress can only be called with an array, ref to array, or ref to hash";
    }

    # hash ref
    my %settings = (
        separator => ',',
        level => 1,
        readable => 0,
        %{$_[0]}
    );
    
    my $nodes = $settings{nodes} || $settings{hosts};
    croak "range_compress: the 'nodes' argument is required."
        unless $nodes;

    my $l = $settings{level};
    my $sep = $settings{separator};
    if ($l == 0) {
        return join($sep, @$nodes);
    } elsif ($l == 1) {
        return range_compress_xs($nodes, $sep);
    } elsif ($l == 2) {
        return _extra_compress($nodes, $sep);
    }
    # do some extra work to achieve the extra compression
    my %domain;
    my @no_domains;
    for my $node (@$nodes) {
        my ($host, $domain) = split '\.', $node, 2;
        if ($domain) {
            push @{$domain{$domain}}, $node;
        } else {
            push @no_domains, $host;
        }
    }
    my @result;
    if (@no_domains) {
        push @result, range_compress_xs(\@no_domains, $sep);
    }
    for my $domain (sort keys %domain) {
        my $r = _extra_compress($domain{$domain}, ",");
        for ($r) {
            s/\.$domain$sep/$sep/g;
            s/\.$domain$//;
            $_ = "{$_}" if /,/;
        }
        push @result, "$r.$domain";
    }
    return join($sep, @result);
}

sub _extra_compress {
    my ($nodes, $sep) = @_;
    my @nodes = @{$nodes};
    my %domains;
    for (@nodes) {
        s/^([a-z]+)(\d+)([a-z]\w+)\./$1$2.UNDOXXX$3./;
    }
    my $result = range_compress_xs(\@nodes, $sep);
    for ($result) {
        s/(\d+-\d+)\.UNDOXXX/{$1}/g;
        s/(\d+)\.UNDOXXX/$1/g;
    }
    return $result;
}

*compress_range = \&range_compress;
*compress = \&range_compress;

sub nodes_parser {
	my ($c, $r, $x) = @_;
	my @range = ();
	if (defined $r) {
		push @range, $r;
	}
	if (defined $c) { push @range, '%' . $c; }
	if (defined $x) { push @range, "-($x)" }
	return range_expand_sorted(join(",", @range));
}

my $wanted_warnings = 0;
sub want_warnings {
  my $prev = $wanted_warnings;
  if (scalar @_) {
    ($wanted_warnings) = @_;
    want_warnings_real(@_);
  }
  return $prev;
}

sub test_range { 
  my $w = want_warnings(0);
  my ($b) = scalar(expand_range(@_));
  want_warnings($w);
  return $b ? 1 : 0;
}


want_caching(1);
want_warnings(-t STDIN && -t STDOUT);

# Autoload methods go after =cut, and are processed by the autosplit program.

1;
__END__
# Below is stub documentation for your module. You'd better edit it!

=head1 NAME

Seco::AwesomeRange - Perl extension for dealing with Seco ranges

=head1 SYNOPSIS

use Seco::AwesomeRange qw/:common/;

my @nodes = expand_range('%ks301');

my $nodes = compress_range(\@nodes);  

my $same_nodes = compress_range(@nodes);

my @sorted_nodes = sorted_expand_range('@ALL');

=head1 DESCRIPTION

Do stuff with ranges.

Expand ranges and cluster definitions.
Compress (a ref to) an array of nodes into a compact string rep.

=head1 COMMON USAGE

If you decide to import the most common functions into your name space:

    use Seco::AwesomeRange qw/:common/;

That imports the functions 

    expand_range

    compress_range

    sorted_expand_range

    nodes_parser

You can also decide which functions you prefer like:

    use Seco::AwesomeRange qw/expand compress/

    my @nodes = expand($range);

    my $nodes_repr = compress(\@nodes);

=head2 CACHING 

    By default the library will cache the results of your expansions. This is
    probably what most command line utilities want. But this will have unwanted
    effects if your program is a long running one. In that case you can use the
    default (C<want_caching(1)>) and explictily call the C<clear_caches()> function.
    
=head2 WARNINGS

    By default the library will print warnings to STDERR if running under a tty,
    and be quiet otherwise. You can be explicit about wanting to see the warnings using:
    C<want_warnings()>

=head1 FUNCTIONS

=head2 compress_range

    Returns the string representation of a given list of nodes. The input can be a
    reference to an array or the the list of nodes. The input doesn't have to be
    sorted.

    $string = compress_range(\@nodes);

    $string = compress_range(@nodes);

=head2 expand_range

    Expands a string representation of nodes and returns a list of nodes. The
    result is not guaranteed to be in any particular order. If you care about the
    result being sorted use C<sorted_expand_range>, otherwise use this one (it'll be faster.)

    @nodes = expand_range('%ks301-7 & @REDHAT')

=head2 sorted_expand_range

    Same as C<expand_range> but the return list is sorted.

=head2 want_caching

    want_caching(1) # caching enabled (default)

    want_caching(0) # caching is disabled

=head2 want_warnings

    want_warnings(1) # print warnings to STDERR

    want_warnings(0) # be quiet

=head2 get_exception

=head2 clear_exception

=head2 clear_caches

    Clear all caches used by librange.

    clear_caches()

=head2 get_version

Returns the version for librange

    my $version = Seco::AwesomeRange::get_version();


=head2 expand / compress

    You can use the aliases expand/compress:

    my @nodes = Seco::AwesomeRange::expand($range);
    my $repr = Seco::AwesomeRange::compress(\@nodes);

=head2 nodes_parser

    Function provided for compatibility with the old Seco.pm module (standardNodesParser).

    my @nodes = nodes_parser(<cluster>,<range>,<excludes>);

=head1 RANGE SYNTAX

=head2 Simple Ranges

=head2 Union

=head2 Intersection

=head2 Difference

=head2 Expand clusters

=head2 Expand GROUPS/HOSTS

=head2 Named functions

=head1 SEE ALSO

perldoc Seco::Range

=head1 AUTHOR

Daniel Muino, E<lt>dmuino@yahoo-inc.comE<gt>
Evan Miller, E<lt>eam@yahoo-inc.comE<gt>

=cut
