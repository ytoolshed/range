package Seco::Data::Writer::Text;

use strict;
use warnings FATAL => qw/uninitialized/;

use Carp;
use File::Copy qw/move/;
use File::Temp;
use POSIX qw/strftime/;

sub init {
    my ( $class, %args ) = @_;
    my $self = {};

    
    $self->{cluster} = $args{'cluster'} || croak 'need cluster name';
    $self->{r}       = $args{'r'}       || croak 'need range obj';
    $self->{create}  = $args{'create'} ? 1 : 0;


    $self->{seco_alt_path} =
        $args{'seco_alt_path'}
      ? $args{'seco_alt_path'}
      : "/home/seco/tools/conf/";
    $self->{file} = $self->{seco_alt_path} . $self->{cluster} . "/nodes.cf";
    #range_set_altpath( $self->{seco_path} ); ## SDR no support :|
    bless( $self, $class );
    $self->__read__;
    return $self;
}


sub has_simple_exclude {
    my ($self,$key,$range) = @_;
    my $r = $self->{r};
    foreach my $l ( @{ $self->{data}{$key} } ) {
        my ( $tag, $val, $comment ) = parse_line($l);
        next unless ( defined $tag && $tag =~ /EXCLUDE/ );
        return 1 if ($r->is_simple_range($val) && $r->range_and( $val,$range));
    }
    return;
}

sub has_simple_include {
    my ($self,$key,$range) = @_;
    my $r = $self->{r};
    foreach my $l ( @{ $self->{data}{$key} } ) {
        my ( $tag, $val, $comment ) = parse_line($l);
        next unless ( defined $tag && $tag =~ /INCLUDE/ );
        return 1 if ($r->is_simple_range($val) && $r->range_and( $val,$range));
    }
    return;
}

sub getRawKey {
    my ($self,$key) = @_;

    my @lines;
    foreach my $l ( @{ $self->{data}{$key} } ) {
        my ( $tag, $val, $comment ) = parse_line($l);
        next unless ( defined $tag );
        push(@lines, [ $tag, $val, $comment ]);
    }

    return @lines;
}

sub dumpRawKeys {
    my $self = shift;

    return @{$self->{__KEYS_IN_ORDER__}}
}

sub addKey {
    my ( $self, $key, $range, $comment) = @_;
    push( @{ $self->{__KEYS_IN_ORDER__} }, $key );
    if (defined $range) {
          $self->{data}{$key} 
           = [ defined $comment ? "INCLUDE $range #$comment"
                                : "INCLUDE $range" ];
    }
    else {
        $self->{data}{$key} = [];
    }
}

sub deleteKey {
    my ( $self, $key ) = @_;
    delete $self->{data}{$key};
    my @tmp;
    foreach my $k ( @{ $self->{__KEYS_IN_ORDER__} } ) {
        unless ( $k eq $key ) { push( @tmp, $k ); }
    }
    $self->{__KEYS_IN_ORDER__} = \@tmp;
}

sub set {
    my ($self,$key,$range,$comment) = @_;
    $self->{data}{$key} = undef unless (defined $range);
    $self->{data}{$key} = [ defined $comment ? "INCLUDE $range #$comment"
                                            : "INCLUDE $range" ];
}

sub include {
    my ( $self, $key, $to_include, $comment ) = @_;
    push @{ $self->{data}{$key} }, 
            defined $comment ? "INCLUDE $to_include #$comment"
                             : "INCLUDE $to_include";
}

sub exclude {
    my ( $self, $key, $to_exclude, $comment ) = @_;
    $to_exclude = "EXCLUDE $to_exclude";
    $to_exclude .= " #$comment" if ( defined $comment);
    push @{ $self->{data}{$key} }, $to_exclude; 
}

sub rmexclude {
    my ( $self, $key, $to_rmexclude ) = @_;
    my ( @tmp, @ux, $seen );
    my $r = $self->{r};

    foreach my $l ( @{ $self->{data}{$key} } ) {
        #XXX: make a different sub
        my ( $tag, $val, $comment ) = parse_line($l);
        unless ( defined $tag && $tag =~ /EXCLUDE/ ) {
            push @tmp, $l;
            next;
        }
        # check each line and remove range or subset
        if ( defined (my $match = $r->range_and( $val,$to_rmexclude))) {
            $seen++;
            if ( $r->is_simple_range($val)) {
                push @ux,$match;
                $val = $r->range_sub( $val, $to_rmexclude );
                push( @tmp, "EXCLUDE $val $comment" ) 
                    if ( defined $val );
                next;
            }
        }
        push @tmp,$l;
   }
   # we failed :|
   if ( $seen && ( my $failed = $r->range_sub( 
                                    $to_rmexclude, 
                                    $r->compress( join( ',', @ux ))))) {
       carp "warn: rmexclude failed ($failed)";
   }
   $self->{data}{$key} = \@tmp;
}

sub rminclude {
    my ( $self, $key, $to_rminclude ) = @_;
    my ( @tmp, @ui, $seen );
    my $r = $self->{r};

    foreach my $l ( @{ $self->{data}{$key} } ) {
        #XXX: make a different sub
        my ( $tag, $val, $comment ) = parse_line($l);
        unless ( defined $tag && $tag =~ /INCLUDE/ ) {
            push @tmp, $l;
            next;
        }
        # check each line and remove range or subset
        if ( defined (my $match = $r->range_and ( $val,$to_rminclude))) {
            $seen++;
            if ( $r->is_simple_range($val) ) {
                push @ui,$match;
                # $val now contains the original range - 
                # the stuff we want to be un-included
                $val = $r->range_sub( $val, $to_rminclude );
                push( @tmp, "INCLUDE $val $comment" ) 
                    if ( defined $val );
                next;
            }
        }
        push @tmp, $l;
    }

    # we failed :|
    if ($seen && (my $failed =
        $r->range_sub( $to_rminclude, $r->compress( join( ',', @ui ))))) {
        carp "warn: rminclude failed for ($failed)";
    }
    $self->{data}{$key} = \@tmp;
}

sub write_to_temp {
    my $self = shift;
    my ( $tfh, $tmpfile ) = File::Temp::tempfile();

    croak "tmpfile failed: $!"
      unless ( defined $tfh && -f $tmpfile );

    # XXX: gross
    chmod 0544, $tmpfile;
    
    foreach my $key ( @{ $self->{__KEYS_IN_ORDER__} } ) {

        # no empty keys please
        push @{$self->{data}{$key}}, "INCLUDE \n" 
          if (not @{$self->{data}{$key}});

        # no leading space for keys
        $key =~ s/^\s+//;
        print $tfh "$key\n" unless ( $key =~ /^_comment/ );
        foreach ( @{ $self->{data}{$key} } ) {
            # prepend 4 spaces to new values
            # new values are identified with lack of leading
            # space
            s/^\s*/    /
              if (  $key !~ /^_comment/ && $_ !~ /^\s+/ && $_ !~ /^#/ 
                                        && $_ !~ /^\s*$/);
            print $tfh "$_\n";
        }
    }
    close $tfh;
    $self->{tmpfile} = $tmpfile;
    return $tmpfile;
}

sub diff {
    my $self = shift;
    $self->write_to_temp;
    if (! -f $self->{file}) {
        print "--- " . $self->{file} . " (nonexistant)\n";
        print "+++ " . $self->{tmpfile} . strftime("\t%Y-%m-%d %H:%M;%S.000000000 +0000\n", gmtime());
        open(T, $self->{tmpfile});
        my @t = <T>;
        close(T);
        grep(s/^/+/, @t);
        print "@@ -0,0 +1," . scalar(@t) . " @@\n";
        print @t;
        return;
    }
    system( 'diff', '-u', $self->{file}, $self->{tmpfile} );
}

sub write {
    my $self = shift;
    $self->write_to_temp;
    move( $self->{tmpfile}, $self->{file} )
      or croak "move ($self->{tmpfile},$self->{file}): $!";
}

sub cleanup {
    my $self = shift;
    if (-f $self->{tmpfile}) {
        unlink($self->{tmpfile});
    }
}

sub __read__ {
    my ($self) = shift;
    my ( $fh, %data, @result );

    if (! -f $self->{file}) {
        if (! $self->{create}) {
            croak $self->{file} . " does not exist";
        }
        $self->{data} = { __KEYS_IN_ORDER__ => [ ] };
        $self->{__KEYS_IN_ORDER__} = $self->{data}->{__KEYS_IN_ORDER__};
        return;
    }

    open( $fh, $self->{file} ) || croak "open($self->{file}): $!";
    my $key;
    my $comment_no = 0;

    while (<$fh>) {
        chomp;
        #empty line terminates a key
        undef $key if (/^\s*$/);
        if (/^#/ || /^\s*$/) {
            # create a 'comment' key for 'comments' / empty lines
            unless (defined $key) {
                $key = '_comment' . $comment_no++;
                push @{ $data{__KEYS_IN_ORDER__} }, $key;
            }
        }
        if (/^([\w\-_\.]+)\s*\Z/) {
            $key = $1;
            croak "duplicate entry for $key [" . $self->{file} . ":" . $fh->input_line_number(). "]" if ( $data{$key} );
            push @{ $data{__KEYS_IN_ORDER__} }, $key;
            next;
        }
        push @{ $data{$key} }, $_;
    }
    $self->{data}              = \%data;
    $self->{__KEYS_IN_ORDER__} = $data{__KEYS_IN_ORDER__};
}

sub parse_line {
    my ($line) = shift;
    my @valid_tags = qw/INCLUDE EXCLUDE/;
    my %valid_tags = map { $_ => 1 } @valid_tags;
    my ( $tag, $val, $comment );

    if ( $line =~ /^\s*(\w+)\s*(.*?)(#.*|$)/ ) {
        croak "invalid tag $1" unless $valid_tags{$1};
        $tag     = $1;
        $comment = $3;
        $val     = $2;
    }
    return ( $tag, $val, $comment );
}

1;

__END__

# vim ts=4 expandtab syntax=perl
