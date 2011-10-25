use strict;

package Seco::Data::Writer::Meta::P4;

use base qw/Seco::Data::Writer::Meta/;

use Seco::P4::Client::Temporary;
use YAML::Syck qw/Dump/;

sub options {
    $_[0]->SUPER::options,
    seco_depot => [ undef, "depot path to seco/tools/conf" ],
    seco_alt_path => [ '/', "unused" ],
}

sub init {
    my $self = shift;

    if (! $self->SUPER::init()) {
        return;
    }

    $self->{_p4} = Seco::P4::Client::Temporary->new(
        views => { $self->option('seco_depot') => '/' },
        verbose => $self->{_verbose},
    );

    $self->setOption('seco_alt_path', $self->{_p4}->root());
}

sub commit {
    my $self = shift;

    foreach my $cluster (keys(%{$self->{_clusters}})) {
        if ($self->{_clusters}->{$cluster}->{dirty}) {
            my $path = $self->{_clusters}->{$cluster}->{backend}->{file};
            $self->verbose("updating $path");
            if (-e $path) {
                if (! $self->{_p4}->edit($path) ) {
                    return $self->error("could not p4 edit $path");
                }
                $self->{_clusters}->{$cluster}->write();
            } else {
                $self->mkparentdirs($path);
                $self->{_clusters}->{$cluster}->write();
                if (! $self->{_p4}->add($path) ) {
                    return $self->error("could not p4 add $path");
                }
            }
        }
    }

    my $diff = $self->{_p4}->diff();
    print "$diff\n";

    return 1;
}

sub mkparentdirs {
    my $self = shift;
    my $path = shift;

    $self->verbose("mkparentdirs $path\n");
    my $p = '/';
    $path =~ s/[^\/]*$//;
    my @components = split(/\//, $path);
    foreach my $c (@components) {
        if (! $c) { next; }
        $p .= $c;
        if (! -d $p) {
            mkdir($p);
        }
        $p .= '/';
    }
}

1;
