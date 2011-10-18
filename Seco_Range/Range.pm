=head1 NAME

Range - deal with Seco ranges.

=head1 SYNOPSIS

use Range qw/:common/;

my @nodes = expand_range('%ks301');

my $nodes = compress_range(\@nodes);

my $same_nodes = compress_range(@nodes);

my @sorted_nodes = sorted_expand_range('@ALL');

=head1 DESCRIPTION

Do stuff with ranges.

Expand ranges and cluster definitions.
Compress (a ref to) an array of nodes into a compact string rep.

Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.

=cut

package Seco::Range;

use warnings;
use strict;
use Exporter;
use IO::File;
use Sys::Hostname;
use Storable;
use Carp;

use constant NODE_CLUSTER => '/home/seco/candy/whoismycluster/node_cluster.dat';

use vars qw(@ISA @EXPORT_OK @EXPORT %EXPORT_TAGS $VERSION $recursion);
use vars qw($IGOR);
use Log::Log4perl qw(:easy);

@ISA = qw/Exporter/;
@EXPORT_OK = qw/expand_range get_cluster_nodes range_set_altpath
    compress_range sorted_expand_range nodes_parser get_expanded_clusters/;
%EXPORT_TAGS = (
    all => [@EXPORT_OK],
    common => [qw/expand_range compress_range sorted_expand_range nodes_parser
                  get_expanded_clusters/]);
@EXPORT = (); # don't pollute the namespace - use Range qw/:common/

$VERSION = "1.4.1";
$recursion = 0;

#eval <<'MEMOIZE';
#use Memoize; # hmmm caching
#memoize('expand_range');
#memoize('_get_cluster_keys');
#MEMOIZE

my $node_regex = qr/
    ([-\w.]*?)          # prefix
    (\d+)               # followed by the start of the range
    (\.[-A-Za-z\d.]*[-A-Za-z]+[-A-Za-z\d.]*)?  # optional domain
/x;

my ($balanced_parens, $balanced_braces);
if ($] > 5.006) {
    $balanced_parens = qr/
        \(
            (?: (?> [^(  )]+ ) # no backtracking here (normal chars)
                |              # or
            (??{ $balanced_parens }) )*  # recursive matching here
        \)
    /x;

    $balanced_braces = qr/
        {
            (?: (?> [^{  }]+ ) # no backtracking here (normal chars)
            |
            (??{ $balanced_braces }) )*  # recursive matching here
        }
    /x;
} else {
    # F*ing solaris machines
    $balanced_parens = qr/
        \(
            (?: (?> [^()]+ ) | \( (?> [^()]+) \)+)*
        \)
    /x;
    $balanced_braces = qr/
        {
            (?: (?> [^{}]+ ) | { (?> [^{}]+) }+)*
        }
    /x;
}

my $range_re = qr@
      (?:^|,)         # beginning of the string or , is start of range
      (               # start capturing our range
        [^(){}/,]*    # normal characters (not {} or / or ())
        (?:
         $balanced_parens
         |
         (?:-|&) \/ [^\/]+ \/  # a reg.ex.
         |                     # or
         (?:-|&) \| [^\|]+ \|
         |
         $balanced_braces
         [^{},]*      # followed by optional normal chars
      )+              # one or more times
      |               # or it can be a simple thing (no braces involved)
      (?>             # never backtrack over these
         [^(){},/]+)  # normal chars
    )@x;

my $range_altpath;
sub range_set_altpath {
    my $new_path = shift;
    return $range_altpath = $new_path;
}

sub _sort_nodes {
    my $ref_nodes = shift;

    my @sorted =
        map { $_->[0] }
        sort { $a->[1] cmp $b->[1] ||
            $a->[3] cmp $b->[3] ||
            $a->[2] <=> $b->[2] ||
            $a->[0] cmp $b->[0] }
        map { if (/^$node_regex$/) {
                [$_, defined $1 ? $1 : "", defined $2 ? $2 : 0,
                     defined $3 ? $3 : ""]
              } else { [$_, "", 0, ""] }
        } @$ref_nodes;
    return @sorted;
}

# compress_range related stuff
sub _get_group {
    my ($prefix, $digits, $count, $suffix) = @_;

    $prefix = "" unless defined $prefix;
    my $len_digits = length($digits);
    my $node_fmt = "\%s\%0${len_digits}d";
    my $group_fmt = "$node_fmt-" . substr($node_fmt, 2);
    my $group = sprintf($group_fmt, $prefix, $digits,
        $digits + $count);

    $suffix = "" unless defined $suffix;
    return $group . $suffix;
}

sub compress_range {
    my @nodes = @_;
    if (@nodes == 1 and ref $nodes[0]) {
        @nodes = @{$nodes[0]};
    }

    unless (@nodes) {
        _range_warn("No nodes specified.");
        return;
    }

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
            #print defined $prefix ? $prefix : "(undef)", " - ", defined $digits ? $digits : "(undef)", " - ", defined $suffix ? $suffix : "(undef)", "\n";
        } else {
            ($prefix, $digits, $suffix) = ($n, undef, undef);
        }
        if (defined $digits and
            $prefix eq $prev_prefix and
            $suffix eq $prev_suffix and
            defined $prev_digits and
            $digits == $prev_digits + $count + 1) {
            $count++;
            next;
        }
        if (defined $prev_n) {
            if ($count > 0) {
                push @result, _get_group($prev_prefix, $prev_digits, $count,
                    $prev_suffix);
            }  else {
                push @result, $prev_n;
            }
        }

        $prev_n = $n;
        $prev_prefix = $prefix;
        $prev_digits = $digits;
        $prev_suffix = $suffix;
        $count = 0;
    }

    if ($count > 0) {
        push @result, _get_group($prev_prefix, $prev_digits, $count,
            $prev_suffix);
    }  else {
        push @result, $prev_n;
    }

    return join(",", @result);
}

sub nodes_parser {
    my ($c, $r, $x) = @_;
    my @range = ();
    if (defined $r) {
        push @range, $r;
    }
    if (defined $c) { push @range, '%' . $c; }
    if (defined $x) { push @range, "-($x)" };

    return sorted_expand_range(join(",", @range));
}

sub sorted_expand_range {
    my @nodes = expand_range(@_);
    return _sort_nodes(\@nodes);
}

my %current_clusters;
sub get_expanded_clusters {
    return [keys %current_clusters];
}

sub expand_range {
    my ($ranges) = @_; return () unless defined $ranges;

    local $recursion = $recursion + 1;
    confess "Max recursion hit in expand_range"
        if $recursion > 20;

    DEBUG("expand_range($ranges)");
    if ($recursion == 1) {
        DEBUG("resetting current_clusters");
        %current_clusters = () ;
    }


    my %nodes;
    for ($ranges) {
        s/\s+//g;        # Get rid of spaces
        s/^"(.*)"$/$1/;  # Dequote if quoted

        # Igor has no notion of expanding "hosts" vs "groups" so 
        # we're only going to use a single syntax (%HOST:)
        #s/@([A-Za-z0-9][^,]+)/%GROUPS:$1/g;  # shorthand notation for groups
        s/@([A-Za-z0-9][^,]+)/%HOSTS:$1/g;   # shorthand notation for hosts
    }

    my @ranges = $ranges =~ m/$range_re/g;
    for my $range (@ranges) {
        # see if it's a special range
        if (substr($range,0,1) eq "(") {
            my $parens_text = $range;
            my $content = ($parens_text =~ m/^($balanced_parens)$/)[0];
            $content = substr($content, 1, -1);
            my @nodes = expand_range($content);
            @nodes{@nodes} = undef;
        } elsif ($range =~ m{^&\|([^|]+)\|} ||
                 $range =~ m{^&\/([^\/]+)\/}) {
            # filter
            my $regex = qr/$1/;
            while (my ($k, $v) = each(%nodes)) {
                delete $nodes{$k} unless $k =~ /$regex/;
            }
        } elsif ($range =~ m{^-\|([^|]+)\|} ||
                 $range =~ m{^-\/([^\/]+)\/}) {
            # filter not
            my $regex = qr/$1/;
            while (my ($k, $v) = each(%nodes)) {
                delete $nodes{$k} if $k =~ /$regex/;
            }
        } elsif ($range =~ /^(%|-|&|\^|\*)(.+)$/) {
            # special operators that modify the rest of the range
            my ($special_op, $rest) = ($1, $2);
            if ($special_op eq "%") {
                # it's a cluster
                my @nodes = get_cluster_nodes($rest);
                @nodes{@nodes} = undef;
            } elsif ($special_op eq "-") {
                # delete nodes from nodes
                my @nodes = expand_range($rest);
                delete @nodes{@nodes};
            } elsif ($special_op eq "&") {
                # intersection
                my @common_nodes = ();
                my @nodes = expand_range($rest);
                for my $node (@nodes) {
                    push @common_nodes, $node if exists $nodes{$node};
                }
                %nodes = (); @nodes{@common_nodes} = undef;
            } elsif ($special_op eq "^") {
                my @nodes = expand_range($rest);
                my @admins = _get_admins_for(@nodes);
                @nodes{@admins} = undef;
            } elsif ($special_op eq "*") {
                my @nodes = expand_range($rest);
                my @clusters = _get_clusters_for(@nodes);
                @nodes{@clusters} = undef;
            }
        } else {
            # simple range
            if ($range =~ /^
                $node_regex
                -            # our separator is '-'
                \1?          # the prefix again, which is optional
                (\d+)        # and the end of the range
                ((?(3) \3 |   # if the domain matched before, we want it here
                  (?:\.[-A-Za-z\d.]+)?)) # if it didn't then we can have a new
                             # one here, like foo1-3.search
                $
                /x)
            {
                my ($prefix, $start, $suf1, $end, $suf2) = ($1, $2, $3, $4, $5);
                $prefix = "" unless defined $prefix;
                my $suffix = "";
                if (defined $suf1 and defined $suf2) {
                    if ($suf1 ne $suf2) {
                        warn "Different suffixes: $suf1 $suf2";
                    }
                    $suffix = $suf1;
                } elsif (defined $suf2) {
                    $suffix = $suf2;
                }
                my $len = length($start);
                # pad $end with leading characters from start so we can
                # type 01-3 and expand that to 01,02,03 or maybe
                # ks301000-9 for ks301000-301009
                my $len_end = length($end);
                $end = substr($start, 0, $len - $len_end) . $end
                    if $len_end < $len;
                my @nodes = map {$_ = sprintf("$prefix%0${len}d$suffix", $_) }
                    ($start .. $end);
                @nodes{@nodes} = undef;
            } elsif ($range =~ /{/) { # }
                my @nodes = expand_range(join(",", _expand_braces($range)));
                @nodes{@nodes} = undef;
            } else {
                # single machine
                $nodes{$range} = undef;
            }
        }
    }
    return keys %nodes;
}

sub get_cluster_nodes {
    my $cluster = shift;
    $cluster =~ s/HOSTS://;
    $current_clusters{$cluster} = 1;
    DEBUG("expanding $cluster");

    my $role    = $IGOR->get_role(split(/\./,$cluster,2));
    if ($IGOR->{'use_expand_cache'}) {
        my $members = $role->get_members();
        my $hosts = $members->expand();
        my $base  = $members->based_on();
        for (@$base) {
            $current_clusters{$_} = 1;
        }
        return @$hosts;
    }
    my $members = $role->get_members()->get_range();
    DEBUG("  $members");
    my $nodes   = [expand_range($members)];

    return @$nodes;

=for ignoring

    my $cluster = shift;
    my @clusters = expand_range($cluster);
    my @result;

    for $cluster (@clusters) {
        die "Malformed cluster name $cluster"
            unless $cluster =~ /^([-\w.]+):?([-\w.]+)?$/;
        $cluster = $1;
        my $part = defined($2) ? $2 : "CLUSTER";
        my %keys = _get_cluster_keys($cluster);
        push @result, expand_range($keys{$part});
    }
    return @result;

=cut

}

{
    my %nodes_admin;

    sub _populate_nodes_admin {
        my @admins = expand_range('%HOSTS:KEYS');
        for my $admin (@admins) {
            my @admin_nodes = expand_range("\%HOSTS:$admin");
            for my $node (@admin_nodes) {
                $nodes_admin{$node} = $admin;
            }
        }
    }

    sub _get_admins_for {
        my @nodes = @_;
        _populate_nodes_admin() unless %nodes_admin;
        my %results;
        for my $node (@nodes) {
            my $admin = $nodes_admin{$node};
            if ($admin) {
                $results{$admin}++;
            } else {
                _range_warn("$node: admin not found");
            }
        }
        return keys %results;
    }
}

{
    my $nodes_cluster;
    sub _populate_nodes_cluster {
        $nodes_cluster = retrieve(NODE_CLUSTER);
        unless ($nodes_cluster) {
            _range_warn("Can't read node_cluster.dat");
            return;
        }
    }

    sub _get_clusters_for {
        my @nodes = @_;
        _populate_nodes_cluster() unless $nodes_cluster;
        my %results;
        for my $node (@nodes) {
            my $cluster = $nodes_cluster->{$node};
            if ($cluster) {
                $results{$cluster}++;
            } else {
                _range_warn("$node: cluster not found");
            }
        }
        return keys %results;
    }
}


sub _expand_braces {
    my $range = shift;
    my @todo = ($range);
    my @results;
    local $_;

    while (@todo) {
        $_ = shift(@todo);
        if (/^(.*)($balanced_braces)(.*)$/) {
            my ($pre, $braces, $post) = ($1, $2, $3);
            my @braces = expand_range(substr($braces, 1, -1));
            for my $elt (@braces) {
                if ($pre =~ /{/) {
                    push @todo, "$pre$elt$post";
                } else {
                    push @results, "$pre$elt$post";
                }
            }
        } else {
            push @results, $_;
        }
    }
    return @results;
}

sub _get_cluster_keys {
    my $cluster = shift;
    my @lines = _read_cluster_file($cluster);
    return unless @lines;

    my (%keys, $current_key, @current_range);

    for (@lines) {
        s/#.*$//; s/\s+$//;
        s/\$(\w+)/\%$cluster:$1/g;  # Turn $MACRO into %cluster:MACRO
        next unless /\S/;

        my $joinsep;
        if (/^\s/ && $current_key) {
            if (/^\s+INCLUDE/) {
                s/^\s+INCLUDE\s+//;
            } elsif (/^\s+EXCLUDE/) {
                s/^\s+EXCLUDE\s+(.*)/-($1)/;
            } else {
                die "RangeError: $_: don't know how to parse that";
            }

            s/\s+//; # strip white space
            push @current_range, $_;
        } else { # New Key
            # save old key info if it exists
            $keys{$current_key} = join(",", @current_range) if $current_key;

            $current_key = $_;
            @current_range = ();
        }
    }

    $keys{$current_key} = join(",", @current_range) if $current_key;
    $keys{KEYS} = join(",", keys %keys);
    $keys{UP} =  "\%${cluster}";
    $keys{DOWN} =  "\%${cluster}:ALL,-\%${cluster}:CLUSTER";
    $keys{VIPS} = _get_cluster_vips($cluster);
    return %keys;
}

sub _get_cluster_file {
    my $cluster = shift;
    my ($fh, $filename);
    my $alt = $range_altpath || "";

    ($filename) = grep( -e $_ ,
        "$alt/$cluster/tools/conf/nodes.cf",
        "$alt/$cluster/nodes.cf",
        "/home/seco/tools/conf/$cluster/nodes.cf",
        "/usr/local/gemclient/$cluster/nodes.cf");
    $filename or _range_warn("$cluster: missing on this machine");
    return $filename;
}

sub _read_big_file {
    my $filename = shift;
    open my $big_fh, '<', $filename or do {
        _range_warn("$filename: $!");
        return;
    };

    my @result;
    while (<$big_fh>) {
        if (/^\$INCLUDE\s+"([^"]+)"/) {
            my $include = $1;
            my $relative_dir = "./";
            if ($include !~ m{^/}) {
                # it's a relative PATH, prepend the dir for the cur file
                if ($filename =~ m{^(.*/)}) {
                    $relative_dir = $1;
                }
            }

            push @result, _read_big_file("$relative_dir$filename");
        } else {
            push @result, $_;
        }
    }
    close $big_fh;
    return wantarray() ? @result : join("", @result);
}

sub _read_cluster_file {
    my $cluster = shift;
    my $filename = _get_cluster_file($cluster);
    my @lines = _read_big_file($filename);

    # TODO: parse $INCLUDE
    return @lines;
}

sub _range_warn {
    my $warn = shift;
    warn "$warn\n" if -t STDIN && -t STDOUT;
}

sub _open_cluster_vips {
    my $cluster = shift;
    my ($fh, $filename);

    my $alt = $range_altpath || "";
    ($filename) = grep ( -e $_,
        "$alt/$cluster/tools/conf/vips.cf",
        "$alt/$cluster/vips.cf",
        "/home/seco/tools/conf/$cluster/vips.cf");
    $filename ||= "/dev/null";
    $fh = new IO::File "$filename", "r";
    return $fh;
}

sub _get_cluster_vips {
    my $cluster = shift;
    my $fh = _open_cluster_vips($cluster);
    my (@vips);

    while (<$fh>) {
        s/#.*$//;
        s/\s+$//;
        next unless /\S/;
        my($vip) = split(/\s+/);
        push(@vips,$vip) if ($vip =~ m/./);
    }
    close($fh);
    return join(",",@vips);
}

1;

__END__

=head1 FUNCTIONS

=head2 compress_range

    $string = compress_range(\@nodes)

    $string = compress_range(@nodes)

=head2 expand_range

    @nodes = expand_range($range) # @nodes in random order, faster

=head2 sorted_expand_range

    @nodes = sorted_expand_range($range) # @nodes in a nice order

=head2 get_cluster_nodes

    @nodes = get_cluster_nodes("ks301"); # random order

=head2 range_set_altpath

    range_set_altpath("/usr/local/gemclient")
    # look for cluster definitions in the directory specified

=head1 RANGE SYNTAX

=head2 SIMPLE RANGES

    node1,node2,node3,node4 == node1-node4 == node1-4

    node1000-1099 == node1000-99 # auto pads digits to the end of the range

    1-100   # numeric only ranges

    foo1-2.search.scd.yahoo.com ==
        foo1.search.scd.yahoo.com-foo2.search.scd.yahoo.com # domain support

    209.131.40.1-209.131.40.255 == 209.131.40.1-255 # IP ranges

=head2 CLUSTERS

    %ks301 == nodes defined in ks301/nodes.cf - Default Section CLUSTER

    %ks301:ALL == nodes defined in a specific section of ks301/nodes.cf

    %ks301:VIPS == IPs in ks301/vips.cf

=head2 SPECIAL CLUSTERS

    %HOSTS and %GROUPS

    %HOSTS:haides has all the hosts that haides is responsible for.

    @haides is a shortcut for the above.

    %GROUPS:ADMIN has all the machines in the group ADMIN

    @ADMIN is a shortcut.


=head2 OPERATIONS

    range1,range2  == union

    range1,-range2 == set difference

    range1,&range2 == intersection

    ^range1 == admins for the nodes in range1

    range1,-(range2,range3) == () can be used for grouping

    range1,&|regex| # all nodes in range1 that match regex

    range1,-|regex| # all nodes in range1 that do not match regex

    /regex/ == all nodes that match regex (it does matching against @ALL)

    The difference between |regex| and /regex/ is that |regex| does the
    matching against the left side of the expression, while /regex/ does
    the matching against all nodes. Therefore

    fornode.pl -r /ks30/ -l # makes sense

    fornode.pl -r |ks30| -l # doesn't make sense since there's nothing to the left


=head2 MORE ADVANCED RANGES

    foo{1,3,5} == foo1,foo3,foo5

    %ks30{1,3} == %ks301,%ks303

    %ks301-7 == nodes in clusters ks301 to ks307

    %all:KEYS == all defined sections in cluster all

    %{%all} == expands all clusters in %all

    %all:sc5,-({f,k}s301-7) == names for clusters in sc5 except ks301-7,fs301-7

    %all:sc5,-|ks| == clusters in sc5, except those matching ks

=head1 BUGS

Need more docs

=head1 AUTHOR

Daniel Muino <dmuino@yahoo-inc.com>

=cut
