package Seco::Data::Range;

# Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
# Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.  


use strict;
use warnings 'all';

use fields qw/server port timeout useragent last_err _ua list/;
use Carp;
use LWP::UserAgent;
use URI::Escape;

our $VERSION = v1.0;

my $node_regex = qr/
    ([-\w.]*?)          # prefix
    (\d+)               # followed by the start of the range
    (\.[-A-Za-z\d.]*[-A-Za-z]+[-A-Za-z\d.]*)?  # optional domain
/x;

sub new {
    my $class            = shift;
    my __PACKAGE__ $self = fields::new($class);
    my $default_server   = 'range.ysm';
    if (@_ == 1) {
        $default_server = shift;
    }

    # override default arguments with user supplied hash
    my %args = (
        'server'    => $default_server,
        'port'      => 9999,
        'timeout'   => 10,
        'useragent' => $0,
        'list'      => undef,
        @_
    );
    
    $self->{list}      = $args{list};
    $self->{server}    = $args{server};
    $self->{port}      = $args{port};
    $self->{timeout}   = $args{timeout};
    $self->{useragent} = $args{useragent};
    $self->{_ua}       = LWP::UserAgent->new(keep_alive => 1);
    $self->{_ua}->agent($self->{useragent});
    $self->{_ua}->timeout($self->{timeout});

    $self->{last_err} = undef;
    return $self;
}

sub expand {
    my __PACKAGE__ $self = shift;
    my $range = shift;
    return $range unless $range;
    my $query = 'expand';

    $query = 'list' if ( $self->{list} );

    $self->{last_err} = undef;
    my $ua     = $self->{_ua};
    my $server = $self->{server};
    my $port   = $self->{port};
    my $req;
    $req =   HTTP::Request->new(
                GET => "http://$server:$port/range/$query?" . uri_escape($range));
    my $res = $ua->request($req);

    my @nodes;
    if ($res->is_success) {
        if ( $self->{list} ) {
            for my $line ( split ("\n",$res->content) ) {
                chomp $line; 
                push @nodes,$line;
            }
        }
        else {
            @nodes = _simple_expand($res->content);
        }
        $self->{last_err} = $res->header('RangeException');
    }
    else {

        # try again
        my $res = $ua->request($req);
        if ($res->is_success) {
            if ( $self->{list} ) {
                for my $line ( split ("\n",$res->content) ) {
                    chomp $line; 
                    push @nodes,$line;
            }
        }
        else {
            @nodes = _simple_expand($res->content);
        }
        $self->{last_err} = $res->header('RangeException');
        }
        else {
            $self->{last_err} = $res->status_line;
        }
    }
    return @nodes;
}

sub last_err {
    my __PACKAGE__ $self = shift;
    return $self->{last_err};
}

sub _simple_compress {
    my @nodes = @{ $_[0] };
    my %set;
    @set{@nodes} = undef;
    @nodes = keys %set;
    @nodes = _sort_nodes(\@nodes);

    my @result;
    my ($prev_prefix, $prev_digits, $prev_suffix) = ("", undef, "");
    my $prev_n;
    my ($prefix, $digits, $suffix);
    my $count = 0;

    for my $n (@nodes) {
        if ($n =~ /^$node_regex$/) {
            ($prefix, $digits, $suffix) = ($1, $2, $3);
            $prefix = "" unless defined $prefix;
            $suffix = "" unless defined $suffix;
        }
        else {
            ($prefix, $digits, $suffix) = ($n, undef, undef);
        }
        if (    defined $digits
            and $prefix eq $prev_prefix
            and $suffix eq $prev_suffix
            and defined $prev_digits
            and $digits == $prev_digits + $count + 1)
        {
            $count++;
            next;
        }
        if (defined $prev_n) {
            if ($count > 0) {
                push @result,
                  _get_group($prev_prefix, $prev_digits, $count, $prev_suffix);
            }
            else {
                push @result, $prev_n;
            }
        }

        $prev_n      = $n;
        $prev_prefix = $prefix;
        $prev_digits = $digits;
        $prev_suffix = $suffix;
        $count       = 0;
    }

    if ($count > 0) {
        push @result,
          _get_group($prev_prefix, $prev_digits, $count, $prev_suffix);
    }
    else {
        push @result, $prev_n;
    }

    return join(",", @result);
}

sub _extra_compress {
    my @nodes = @{ $_[0] };
    my %domains;
    for (@nodes) {
        s/^([a-z]+)(\d+)([a-z]\w+)\./$1$2.UNDOXXX$3./;
    }
    my $result = _simple_compress(\@nodes);
    for ($result) {
        s/(\d+\.\.\d+)\.UNDOXXX/{$1}/g;
        s/(\d+)\.UNDOXXX/$1/g;
    }
    return $result;
}

sub compress {
    my __PACKAGE__ $self = shift;
    my $ref = ref $_[0];

    $self->{last_err} = undef;
    my @nodes = $ref ? @{ $_[0] } : @_;
    unless (@nodes) {
        $self->{last_err} = "No nodes specified.";
        return;
    }

    # do some extra work to achieve the extra compression
    my %domain;
    my @no_domains;
    for my $node (@nodes) {
        return _simple_compress(\@nodes)
               if ($node =~ /^(?:"|q\()/);

        my ($host, $domain) = split '\.', $node, 2;
        if ($domain) {
            push @{ $domain{$domain} }, $node;
        }
        else {
            push @no_domains, $host;
        }
    }
    my @result;
    if (@no_domains) {
        push @result, _simple_compress(\@no_domains);
    }
    for my $domain (sort keys %domain) {
        my $r = _extra_compress($domain{$domain});
        for ($r) {
            s/\.$domain,/,/g;
            s/\.$domain$//;
            $_ = "{$_}" if /,/;
        }
        push @result, "$r.$domain";
    }
    return join(",", @result);
}

sub _sort_nodes {
    my $ref_nodes = shift;

    my @sorted =
      map { $_->[0] }
      sort {
             $a->[1] cmp $b->[1]
          || $a->[3] cmp $b->[3]
          || $a->[2] <=> $b->[2]
          || $a->[0] cmp $b->[0]
      }
      map {
        if (/\A$node_regex\z/)
        {
            [
                $_,
                defined $1 ? $1 : "",
                defined $2 ? $2 : 0,
                defined $3 ? $3 : ""
            ];
        }
        else { [ $_, "", 0, "" ] }
      } @$ref_nodes;
    return @sorted;
}

sub _simple_expand {
    my $range_with_commas = shift;
    return unless $range_with_commas;

    my @res;
    my @parts = ($range_with_commas =~ /("[^"]+"),?/gs);
    @parts = split(",", $range_with_commas) unless @parts;

    for my $range (@parts) {
        if (
            $range =~ /\A
                   $node_regex
                   \.\.            # our separator is '..'
                   \1?          # the prefix again, which is optional
		  (\d+)         # and the end of the range
		  ((?(3) \3 |   # if the domain matched before, we want it here
		  (?:\.[-A-Za-z\d.]+)?)) # if it didn't then we can have a new
			        # one here, like foo1-3.search
		  \z/xs
          )
        {
            my ($prefix, $start, $suf1, $end, $suf2) = ($1, $2, $3, $4, $5);
            $prefix = "" unless defined $prefix;
            my $suffix = "";
            if (defined $suf1 and defined $suf2) {
                if ($suf1 ne $suf2) {
                    warn "Different suffixes: $suf1 $suf2";
                }
                $suffix = $suf1;
            }
            elsif (defined $suf2) {
                $suffix = $suf2;
            }
            my $len = length($start);

            # pad $end with leading characters from start so we can
            # type 01..3 and expand that to 01,02,03 or maybe
            # ks301000..9 for ks301000..301009
            my $len_end = length($end);
            $end = substr($start, 0, $len - $len_end) . $end
              if $len_end < $len;
            push @res,
              map { $_ = sprintf("$prefix%0*d$suffix", $len, $_) }
              ($start .. $end);
        }
        else {

            # single machine
            push @res, $range;
        }
    }
    return @res;
}

# compress_range related stuff
sub _ignore_common_prefix {
    my ($start, $end) = @_;

    my $len_start = length $start;
    if ($len_start < length $end) {
        return $end;
    }

    my $i;
    for ($i = 0 ; $i < $len_start ; $i++) {
        last if substr($start, $i, 1) ne substr($end, $i, 1);
    }
    return substr($end, $i);
}

sub _get_group {
    my ($prefix, $digits, $count, $suffix) = @_;

    $prefix = "" unless defined $prefix;
    my $group = sprintf("%s%0*d..%s",
        $prefix, length($digits), $digits,
        _ignore_common_prefix($digits, $digits + $count));

    $suffix = "" unless defined $suffix;
    return $group . $suffix;
}

1;

__END__

=head1 NAME

Seco::Data::Range - OO interface to ranged

=head1 SYNOPSIS

  use Seco::Data::Range;

  my $range = Seco::Data::Range->new;
  or 
  my $range = Seco::Data::Range->new(list => '1' );

  This will use "list" instead of "expand" and works as expected for any 
  range expressions using q(). Only use when needed.

  my @nodes = $range->expand("vlan(pain)");
  my $nodes = $range->compress(["foo10", "foo11"]);
  my $err = $range->last_err;

=head1 DESCRIPTION

TODO

=head2 EXPORT

None by default.

=head1 SEE ALSO

ranged, range functions.

=head1 AUTHOR

Daniel Muino, E<lt>dmuino@yahoo-inc.comE<gt>

=head1 COPYRIGHT AND LICENSE

Copyright (C) 2006 Yahoo! Inc.

=cut
