use strict;

package Seco::Data::Writer::Meta::SVN;

use base qw/Seco::Data::Writer::Meta/;

use Seco::SVN::WorkingCopy::Temporary;
use YAML::Syck qw/Dump/;

sub options {
    $_[0]->SUPER::options,
    path => [ 'path to svn repository' ],
    seco_alt_path => [ '/', "unused" ],
}

sub init {
    my $self = shift;

    $self->setOption('seco_alt_path', '/');

    $self->{_svn} = new Seco::SVN::WorkingCopy::Temporary (
        svnroot => $self->option('path'),
        verbose => $self->{_verbose},
    );
    $self->setOption('seco_alt_path', $self->{_svn}->root());
    $self->{_rawopts}->{seco_alt_path} = $self->{_svn}->root();

    if ($self->option('changelog') =~ /^svn/) {
        $self->{_svn_changelog} = new Seco::SVN::WorkingCopy::Temporary (
            svnroot => $self->option('changelog'),
            verbose => $self->{_verbose},
        );
        $self->{_rawopts}->{changelog} = $self->{_svn_changelog}->root();
        $self->setOption('changelog', $self->{_svn_changelog}->root())
    }

    return 1;
}

sub commit {
    my $self = shift;
    my $msg = shift;

    if (! $self->commit_clusters()) {
        return $self->error("could not commit clusters");
    }

    if (! $self->{_svn}->commit($msg)) {    
        return $self->error("svn commit failed");
    }

    my $rev = $self->{_svn}->output('commitRev');

    return $self->commit_changelogs($msg, $rev);
}

sub commit_changelogs {
    my $self = shift;
    my $msg = shift;
    my $rev = shift;

    if (! $self->SUPER::commit_changelogs($msg, $rev)) {
        return 0;
    }

    if ($self->{_svn_changelog}) {
        if (! $self->{_svn_changelog}->commit($msg)) {    
            return $self->error("svn changelog commit failed");
        }
    }
    
    return 1;
}

sub create_changelog {
    my $self = shift;
    my $cluster = shift;
    my $msg = shift;

    if (! $self->SUPER::create_changelog($cluster, $msg)) {
        return 0;
    }

    my $path = $self->option('changelog') . '/' . $cluster;
    
    if ($self->{_svn_changelog} && ! $self->{_svn_changelog}->add($path)) {
        return $self->error("could not svn add $path");
    }

    return 1;
}

sub update_changelog {
    my $self = shift;
    my $cluster = shift;
    my $msg = shift;

    my $path = $self->option('changelog') . '/' . $cluster;
    
    if ($self->{_svn_changelog} && ! $self->{_svn_changelog}->edit($path)) {
        return $self->error("could not svn edit $path");
    }

    return $self->SUPER::update_changelog($cluster, $msg);
}

sub create_cluster {
    my $self = shift;
    my $cluster = shift;

    if (! $self->SUPER::create_cluster($cluster)) {
        return 0;
    }

    my $p = $self->{_mkparentdir_top};

    if (! $self->{_svn}->add($p) ) {
        return $self->error("could not svn add $p");
    }

    return 1;
}

sub update_cluster {
    my $self = shift;
    my $cluster = shift;

    my $path = $self->{_clusters}->{$cluster}->{backend}->{file};
    if (! $self->{_svn}->edit($path) ) {
        return $self->error("could not svn edit $path");
    }
    return $self->SUPER::update_cluster($cluster);
}

1;
