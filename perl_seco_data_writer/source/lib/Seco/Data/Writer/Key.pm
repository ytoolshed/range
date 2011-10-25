# Module to handle each invidiual key
package Seco::Data::Writer::Key;

use strict;
use warnings;

use Carp;

sub new {
    my ( $class, %args ) = @_;
    my $self = {};
    $self->{key}     = $args{'name'}   || croak "need a key";
    $self->{parent}  = $args{'parent'} || croak "need a reference to parent";
    return bless( $self, $class );
}


sub has_simple_exclude {
    my ( $self, $range ) = @_;
    $self->{parent}->todo( $self->{key}, "has_simple_exclude", $range );
}

sub has_simple_include {
    my ( $self, $range ) = @_;
    $self->{parent}->todo( $self->{key}, "has_simple_include", $range );
}

sub include {
    my ( $self, $range, $comment, $no_check ) = @_;
    my $r = $self->{parent}{r};
    my $to_include = $no_check ? $range
                               : $r->range_sub( $range, $self->getRange );
    if (! $to_include && ! $no_check) {
        print STDERR "WARNING: not including [$range] in [" . $self->{parent}->{cluster} . "] because it already exists there.\n";
        return;
    }
    $self->{parent}->todo( $self->{key}, "include", $to_include, $comment );
    $self->dirty;
    return $to_include;
}

sub exclude {
    my ( $self, $range, $comment, $no_check ) = @_;
    my $r = $self->{parent}{r};
    my $to_exclude = $no_check ? $range 
                               : $r->range_and( $range, $self->getRange );;
    if (! $to_exclude && ! $no_check) {
        print STDERR "WARNING: not excluding [$range] from [" . $self->{parent}->{cluster} . "] because it doesn't exist there.\n";
        return;
    }
    $self->{parent}->todo( $self->{key}, "exclude", $to_exclude, $comment );
    $self->dirty;
    return $to_exclude;
}

sub rmexclude {
    my ( $self, $range, $no_check ) = @_;
    my $r = $self->{parent}{r};
    my $to_rmexclude = $no_check ? $range 
                                 : $r->range_sub ($range, $self->getRange );
    if (! $to_rmexclude && ! $no_check) {
        print STDERR "WARNING: not removing exclude [$range] from [" . $self->{parent}->{cluster} . "].\n";
        return;
    }
    $self->{parent}->todo( $self->{key}, "rmexclude", $to_rmexclude );
    $self->dirty;
    return $to_rmexclude;
}

sub rminclude {
    my ( $self, $range, $no_check ) = @_;
    my $r = $self->{parent}{r};
    my $to_rminclude = $no_check ? $range
                                 : $r->range_and ( $self->getRange,$range);
    if (! $to_rminclude && ! $no_check) {
        print STDERR "WARNING: not removing include [$range] from [" . $self->{parent}->{cluster} . "].\n";
        return;
    }
    $self->{parent}->todo( $self->{key}, "rminclude", $to_rminclude );
    $self->dirty;
    return $to_rminclude;
}


sub set {
    my ( $self, $range ) = @_;
    $self->{parent}->todo( $self->{key},"set",$range);
    $self->dirty;
	return $range;
}

sub dirty {
    return ( $_[0]->{parent}->{dirty} = 1 );
}

sub getRange {
    my $self = shift;
    my $r = $self->{parent}{r};
    return $r->get_range( "%" . $self->{parent}->cluster . ":" . $self->{key} );
}

sub take {
    my $self = shift;
    my $source = shift;
    my @values = shift;

    foreach my $val (@values) {
        if (! $source->has_simple_include($val)) {
            croak "value $val in key $source does not exist";
        }
    }
    foreach my $val (@values) {
        $source->rminclude($val);
        $self->include($val);
    }
}

1;

__END__

#vim expandtab ts=4 syntax=perl
