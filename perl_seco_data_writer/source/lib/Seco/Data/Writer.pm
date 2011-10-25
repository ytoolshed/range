package Seco::Data::Writer;
# Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
# Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.  

use strict;
use warnings;

use Carp;
use Scalar::Util qw/weaken/;
use File::Copy;
use File::Spec;
use File::Temp;
use POSIX qw/strftime/;

use Seco::Libcrange;
use Seco::Data::Writer::Key;
use Seco::Data::Writer::Text;

use constant NO  => 0;
use constant YES => 1;


sub new {
    my ( $class, %args ) = @_;
    my $self = {
        cluster       => $args{cluster},
        dirty         => NO,
        edit          => NO,
        seco_alt_path => File::Spec->canonpath ($args{seco_alt_path}) . '/',
        changelog_path => File::Spec->canonpath ($args{changelog_path}) . '/',
        r             => undef,
        __init__      => NO,
        create        => $args{create} ? YES : NO,
    };

    if (defined $args{r}) {
       $self->{r} = $args{r};
    }
    else {
        ### XXX: enhance Seco::Libcrange to expose methods
        ### for adding modules/setting vars
        my ( $tfh, $tmpfile ) = File::Temp::tempfile();
        croak "tmpfile failed: $!"
            unless ( defined $tfh && -f $tmpfile );
        print $tfh "nodescf_path=$self->{seco_alt_path}\n";
        print $tfh "loadmodule nodescf\n";
        close $tfh;
        $self->{r_config} = $tmpfile;
        $self->{r} = Seco::Libcrange::->new($tmpfile);
    }
    $self->{edit} = defined  $args{edit} ? YES : NO;
    bless( $self, $class );
    $self->__init__;
    return $self;
}

sub cluster {
    return $_[0]->{cluster};
}

sub __init__ {
    return unless ( $_[0]->{__init__} == 0 );

    my $self = shift;
    my $weakself = $self;
    weaken($self);

    no strict 'refs';
    $self->{backend} =
      Seco::Data::Writer::Text::->init(
        'seco_alt_path' => $self->{seco_alt_path},
        'cluster'       => $self->{cluster} ,
        'r'             => $self->{r},
        'create'        => $self->{create},
      );

    foreach my $key ( $self->dumpKeys ) {
        $self->{$key} = Seco::Data::Writer::Key->new(
            "parent" => $weakself,
            "name"   => $key,
            "data"   => undef,
        );
    }

    if ($self->{create}) {
        if (! $self->{ALL}) {
            $self->addKey('ALL');
        }
        if (! $self->{STABLE}) {
            $self->addKey('STABLE', '$ALL');
            $self->getKey('STABLE')->exclude('%ngd-inactive:ALL & $ALL', undef, 1);
        }
        if (! $self->{CLUSTER}) {
            $self->addKey('CLUSTER', '$STABLE');
        }
        
    }
    $self->{__init__} = YES;
}

sub todo {
    my ( $self, $key, $action, @args ) = @_;
    no strict 'refs';
    $self->noteChange($key, $action, @args);
    $self->{backend}->$action( $key, @args );
}

sub noteChange {
    my $self = shift;
    my $key = shift;
    my $action = shift;
    my @vals = @_;

    if ($action =~ /^(dump|has_|get)/) {
        return;
    }

    my @caller = caller(2);
    my $class = shift(@caller);

    my @v;
    foreach my $v (@vals) {
        if (defined($v) && $v !~ /^$/) {
            push(@v, $v);
        }
    }
    @vals = @v;
    my $vals = shift(@vals);
    $vals ||= '';
    #$vals = join(',', grep(!/^$/, @vals));
    push(@{$self->{_changes}}, [ $class, $key, $action, $vals ]);
}

sub displayChanges {
    my $self = shift;
    foreach my $change (@{$self->{_changes}}) {
        my ($caller, $key, $action, $vals) = @{$change};
        print "CHANGE: $caller | $key | $action | $vals\n";
    }
}

sub writeChanges {
    my $self = shift;
    my $msg = shift;

    return unless ( $self->{dirty} && $self->{edit} );

    my $path = $self->{changelog_path} . $self->{cluster};

    my $ts = strftime('%Y-%m-%d %H:%M:%S', gmtime());

    my $changes = "---\n- [$ts, $msg]\n";
    foreach my $change (@{$self->{_changes}}) {
        my ($caller, $key, $action, $vals) = @{$change};
        $changes .= "- [$caller, $key, $action, \"$vals\"]\n";
    }
    if (! open(F, ">>$path")) {
        print STDERR "open: $path: $!";
        return 0;
    }

    print F $changes;
    close(F);

    return 1;
}

sub dumpKeys {
    return $_[0]->{r}->expand( "%" . $_[0]->{cluster} . ":KEYS" );
}

sub dumpRawKeys {
    $_[0]->todo( undef, 'dumpRawKeys' );
}

sub getKeys {
    my ($self) = shift;
    return
      map { $self->{$_} } ( $self->{r}->expand( "%" . $self->{cluster} . ":KEYS" ) );
}

sub getKey {
    my ( $self, $key ) = @_;
    croak "unknown key ($key)" unless ( $self->{$key} );
    return $self->{$key};
}

sub hasKey {
    my ($self, $key) = @_;

    return exists($self->{$key});
}

sub addKey {
    my ( $self, $key, $range, $comment ) = @_;
    croak "key exists ($key)" if ( $self->{$key} );

    my $weakself = $self;
    weaken($weakself);
    $self->{$key} = Seco::Data::Writer::Key->new(
        parent => $weakself,
        name   => $key,
    );
    $self->todo( $key, 'addKey', $range, $comment);
    $self->{dirty} = YES;
    return $self->{$key};
}

sub deleteKey {
    my ( $self, $key ) = @_;
    croak "unknown key ($key)" unless ( $self->{$key} );
    $self->todo( $key, 'deleteKey' );
    delete $self->{$key} if ( $self->{$key} );
    $self->{dirty} = YES;
}

sub getRawKey {
    my ( $self, $key ) = @_;
    croak "unknown key ($key)" unless ( $self->{$key} );
    return $self->todo( $key, 'getRawKey' );
}

sub clone {
   my ( $self, $src, $range, $comment ) = @_;
   my $no_check = 1;
   foreach my $kobj ($self->getKeys) {
      $kobj->include($range, $comment, $no_check) 
        if ( $kobj->has_simple_include($src));
      $kobj->exclude($range, $comment, $no_check) 
        if ( $kobj->has_simple_exclude($src));
   }
}


sub write {
    return unless ( $_[0]->{dirty} && $_[0]->{edit} );
    my $self = shift;
    $self->{backend}->write;
}

sub cleanup {
    return unless ( $_[0]->{dirty} && $_[0]->{edit} );
    my $self = shift;
    $self->{backend}->cleanup;
}

sub diff {
    return unless ( $_[0]->{dirty} && $_[0]->{edit} );
    my $self = shift;
    $self->{backend}->diff;
}

sub inheritKeys {
    my $self = shift;
    my $source = shift;
    my @keys = @_;

    if (! scalar(@keys)) {
        @keys = grep(!/^_comment/, $source->dumpRawKeys);
    }

    my $cluster = $source->{cluster};

    foreach my $key (@keys) {
        if ($key =~ /^(ALL|STABLE|CLUSTER)$/) {
            next;
        }
        if ($self->hasKey($key)) {
            $self->deleteKey($key);
        }
        $self->addKey($key, '%' . $cluster . ':' . $key);
    }
}

sub copyKeys {
    my $self = shift;
    my $source = shift;
    my @keys = @_;

    if (! scalar(@keys)) {
        @keys = grep(!/^_comment/, $source->dumpRawKeys);
    }

    foreach my $key (@keys) {
        if ($key =~ /^(ALL|STABLE|CLUSTER)$/) {
            next;
        }
        if ($self->hasKey($key)) {
            $self->deleteKey($key);
        }
        my @r = $source->getRawKey($key);
        if (!scalar(@r)) {
            $self->addKey($key, undef);
            next;
        }
        my $v = shift(@r);
        my ($tag, $range, $comment) = @{$v};
        croak "first entry in $key is not INCLUDE" if ($tag ne 'INCLUDE');
        my $k = $self->addKey($key, $range, $comment);
        foreach my $v (@r) {
            my ($tag, $range, $comment) = @{$v};
            if ($tag eq 'INCLUDE') {
                $k->include($range, $comment, 1);
            } elsif ($tag eq 'EXCLUDE') {
                $k->exclude($range, $comment, 1);
            } else {
                croak "don't know tag $tag";
            }
        }
    }
}

sub DESTROY {
    my $self = shift;
    if ($self->{r_config} =~ /^\/tmp/) {
        unlink($self->{r_config});
    }
}

1;

# vim ts=4 expandtab syntax=perl
