use strict;

package Seco::Data::Writer::Meta;

# Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
# Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.  

use base qw/Seco::Bootie/;

use Seco::Data::Writer;
use POSIX qw/strftime/;
use YAML::Syck qw/Dump/;

sub options {
    $_[0]->SUPER::options,
    seco_alt_path   => [ undef, "path to seco conf" ],
    changelog       => [ '', "path to changelog base" ],
}

sub new_cluster {
    my $self = shift;
    my $cluster = shift;

    $cluster = $self->cluster($cluster, 1);

    return $cluster;
}

sub cluster {
    my $self = shift;
    my $cluster = shift;
    my $create = shift;

    if (! exists($self->{_clusters}->{$cluster})) {
        $self->{_clusters}->{$cluster} = Seco::Data::Writer->new(
            seco_alt_path => $self->option('seco_alt_path'), 
            cluster => $cluster, 
            edit => 1, 
            create => $create,
            changelog_path => $self->option('changelog'),
        );
    }
    return $self->{_clusters}->{$cluster};
}

sub init {
    my $self = shift;

    if (! $self->SUPER::init()) {
        return;
    }

    if ($self->option('changelog')) {
        my $changelog = $self->option('changelog');
        if (! -d $changelog) {
            return $self->error("changelog path $changelog does not exist");
        }
    }
    if (! -d $self->option('seco_alt_path') ) {
        return $self->error("path " . $self->option('seco_alt_path') . " does not exist");
    }

    return 1;
}

sub diff {
    my $self = shift;
    foreach my $cluster (sort keys(%{$self->{_clusters}})) {
        print "Index: $cluster\n";
        print "===================================================================\n";
        $self->{_clusters}->{$cluster}->diff();
        $self->{_clusters}->{$cluster}->cleanup();
    }
    $self->display_changes();
}

sub display_changes {
    my $self = shift;
    foreach my $cluster (sort keys(%{$self->{_clusters}})) {
        print "cluster changes: $cluster\n";
        $self->{_clusters}->{$cluster}->displayChanges();
    }
    my @changes;
}

sub username { $ENV{USER}; }


sub commit {
    my $self = shift;
    my $msg = shift;

    if (! $self->commit_clusters()) {
        return $self->error("could not commit clusters");
    }
    return $self->commit_changelogs($msg);
}

sub commit_clusters {
    my $self = shift;
    my $msg = shift;

    my @changed;

    foreach my $cluster (keys(%{$self->{_clusters}})) {
        if ($self->{_clusters}->{$cluster}->{dirty}) {
            if (! $self->commit_cluster($cluster)) {
                return $self->error("could not commit changes to $cluster");
            }
            push(@{$self->{_changed_clusters}}, $cluster);
        }
    }

    return 1;
}

sub commit_changelogs {
    my $self = shift;
    my $msg = shift;
    my $rev = shift;

    $msg = $self->username . ($rev ? ", $rev" : "") . ", \"$msg\"";

    my $changelog = $self->option('changelog');
    if (! $changelog) {
        return 1;
    }

    if (! $self->{_changed_clusters}) {
        return 1;
    }
    my @clusters = @{$self->{_changed_clusters}};
    foreach my $cluster (@clusters) {
        if (! $self->commit_changelog($cluster, $msg)) {
            $self->error("changelog write for $cluster failed. continueing");
        }
    }

    return 1;
}

sub commit_changelog {  
    my $self = shift;
    my $cluster = shift;
    my $msg = shift;

    my $path = $self->option('changelog') . "/$cluster";
    if (-f $path) {
        return $self->update_changelog($cluster, $msg);
    } else {
        return $self->create_changelog($cluster, $msg);
    }
}

sub create_changelog {
    my $self = shift;
    my $cluster = shift;
    my $msg = shift;

    my $path = $self->option('changelog') . "/$cluster";
    $self->verbose("creating $path");
    if (! $self->{_clusters}->{$cluster}->writeChanges($msg)) {
        return $self->error("writeChanges() failed");
    }
    return 1;
}

sub update_changelog {
    my $self = shift;
    my $cluster = shift;
    my $msg = shift;

    my $path = $self->option('changelog') . "/$cluster";
    $self->verbose("updating $path");
    if (! $self->{_clusters}->{$cluster}->writeChanges($msg)) {
        return $self->error("writeChanges() failed");
    }
    return 1;
}

sub DESTROY {
    my $self = shift;

    foreach my $cluster (sort keys(%{$self->{_clusters}})) {
        $self->{_clusters}->{$cluster}->cleanup();
    }
}

sub addChangeRefs {
    my $self = shift;
    my $reference = shift;

    my $date = strftime('%Y-%m-%d', gmtime);
    foreach my $cluster (sort keys(%{$self->{_clusters}})) {
        if ($self->{_clusters}->{$cluster}->{dirty}) {
            if (! $self->{_clusters}->{$cluster}->hasKey('CHANGES')) {
                $self->{_clusters}->{$cluster}->addKey('CHANGES');
            }
            $self->{_clusters}->{$cluster}->getKey('CHANGES')->include('q(' . $date . ';' . $reference . ')');
        }
    }
}

sub createDependentCluster {
    my $self = shift;
    my $orig = shift;
    my $new = shift;

    $self->new_cluster($new);
    $self->cluster($new)->inheritKeys($self->cluster($orig));
}


sub commit_cluster {
    my $self = shift;
    my $cluster = shift;

    my $path = $self->{_clusters}->{$cluster}->{backend}->{file};

    if (-e $path) {
        return $self->update_cluster($cluster);
    } 

    return $self->create_cluster($cluster);
}

sub create_cluster {
    my $self = shift;
    my $cluster = shift;

    my $path = $self->{_clusters}->{$cluster}->{backend}->{file};
    my @mk = $self->mkparentdirs($path);
    if (! @mk) {
        return $self->error("Could not create $path");
    }
    if (! $self->{_clusters}->{$cluster}->write()) {
        return $self->error("could not write $path");
    }
    if (! chmod(0644, $path)) {
        return $self->error("could not chmod $path");
    }
    $self->{_mkparentdir_top} = shift(@mk);
    return 1;
}

sub update_cluster {
    my $self = shift;
    my $cluster = shift;

    my $path = $self->{_clusters}->{$cluster}->{backend}->{file};
    $self->verbose("updating $cluster ($path)");
    $self->{_clusters}->{$cluster}->write();
}

sub mkparentdirs {
    my $self = shift;
    my $path = shift;

    my @mk;

    $self->verbose("mkparentdirs $path\n");
    my $p = '/';
    $path =~ s/[^\/]*$//;
    my @components = split(/\//, $path);
    foreach my $c (@components) {
        if (! $c) { next; }
        $p .= $c;
        if (! -d $p) {
            mkdir($p);
            push(@mk, $p);
        }
        $p .= '/';
    }

    return @mk;
}

1;

