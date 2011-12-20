#!/usr/bin/perl

######################################################################
# Copyright (c) 2011, Yahoo! Inc.  All rights reserved.
# Copyrights licensed under the New BSD License. See the accompanying LICENSE file for terms.  


######################################################################

=head1 NAME

rangeDiff - Diff a seco/tools/conf directory against the web service

=head1 DESCRIPTION

rangeDiff executes 'kv(allClusters())' to identify differences
between a seco/tools/conf directory and a production range web
service.  This method shows the "evaluated" effect of a change
to range, 

=head1 SYNOPSIS

rangeDiff <libcrange.conf>

=cut


######################################################################
# Initialization
#
    use warnings;
    use strict;


######################################################################
# Includes
#
    use Seco::Data::Range qw();
    use Seco::Libcrange qw();

    # 3rd Party Stuff
    use File::Basename qw();


######################################################################
# Globals
#
    my $CALLED_AS = File::Basename::basename( $0 );
    my $DEFAULT_STC_DIR = "/home/seco/tools/conf";
#    my $DEFAULT_STC_CONF = "/etc/libcrange.conf";
    my $DEFAULT_STC_CONF = "/home/armstd/projects/rangeTest/libcrange.conf";


######################################################################
# MAIN
#
sub main
{
    # First read in the local Libcrange clusters
#TODO - migrate to GetOpt
    my $stcConf = shift( @ARGV );
#    my $clusterRanges = \@ARGV;
    my $clusterRanges = [];
#    my $stcConf = $DEFAULT_STC_CONF;

    if( ! defined( $stcConf ) )
    {
        $stcConf = $DEFAULT_STC_CONF;
        print STDERR "Usage: $CALLED_AS <libcrange.conf>\n";
#        print STDERR "Usage: $CALLED_AS <libcrange.conf> [<cluster range>[ <cluster range>[ ...]]]\n";
        exit( 1 );
    }

    my $slcrHandle = Seco::Libcrange->new( $stcConf );

    if( scalar( @{$clusterRanges} ) == 0 )
    {
        $clusterRanges = [ 'allclusters()' ];

        # Special case...we'll use the local handle to read all/IGNORE clusters for diff also
        push( @{$clusterRanges}, listIgnoredClusters( $stcConf ) );
    }

    my $slcrHash = loadClusters( $slcrHandle, $clusterRanges );
#debugging Seco::Libcrange destruction print of ``
#exit( 0 );

    # Use Seco::Data::Range to contact production Range server and
    # download all clusters keyvalue pairs
    my $sdrHandle = Seco::Data::Range->new( 'list' => 1 );
    my $sdrHash = loadClusters( $sdrHandle, $clusterRanges );

    my $diffHash = diffClusterHashes( $sdrHash, $slcrHash, $slcrHandle );
    printClusterDiff( $diffHash, $slcrHandle );

#TODO maybe Seco::Libcrange is printing something???
# Avoid global desctruction, it's not pretty
exec( "/bin/true" );

    exit( 0 );
}
main;


######################################################################
# Subroutines
#
sub printClusterDiff
{
    my( $diffHash, $slcrHandle ) = @_;

#    print "before #clusters: " . scalar( keys( %{$beforeHash} ) ) . "\n";
#    print "after #clusters: " . scalar( keys( %{$afterHash} ) ) . "\n";

    my @removedClusters = sort( keys( %{$diffHash->{'removedClusters'}} ) );
    if( scalar( @removedClusters ) )
    {
        print "REMOVED Clusters\n"
            . "=" x 70 . "\n"
            . "\t" . join( "\n\t", @removedClusters ) . "\n"
            . "\n\n"
            ;
    }

    my @addedClusters = sort( keys( %{$diffHash->{'addedClusters'}} ) );
    if( scalar( @addedClusters ) )
    {
        print "ADDED Clusters\n"
            . "=" x 70 . "\n"
            . "\t" . join( "\n\t", @addedClusters ) . "\n"
            . "\n\n"
            ;
    }

    my @changedClusters = sort( keys( %{$diffHash->{'changedClusters'}} ) );

    if( scalar( @changedClusters ) )
    {
        print "CHANGED Clusters\n"
            . "=" x 70 . "\n\n"
            ;
    }
    
    foreach my $changedCluster ( @changedClusters )
    {
        my $removedKeys = $diffHash->{'changedClusters'}->{$changedCluster}->{'removedKeys'};
        my $addedKeys = $diffHash->{'changedClusters'}->{$changedCluster}->{'addedKeys'};
        my $changedKeys = $diffHash->{'changedClusters'}->{$changedCluster}->{'changedKeys'};

        print $changedCluster . "\n" . "-" x 70 . "\n";

        foreach my $removedKey ( sort( keys( %{$removedKeys} ) ) )
        {
            my $printableValue = $removedKeys->{$removedKey};
            if( ! defined( $printableValue ) )
            {
                $printableValue = "<Undefined>";
            }

            print "    Key Removed: $removedKey\n"
                . "        Value: $printableValue\n"
                . "\n"
                ;
        }

        foreach my $addedKey ( sort( keys( %{$addedKeys} ) ) )
        {
            my $printableValue = $addedKeys->{$addedKey};
            if( ! defined( $printableValue ) )
            {
                $printableValue = "<Undefined>";
            }

            print "    Key Added: $addedKey\n"
                . "        Value: $printableValue\n"
                . "\n"
                ;
        }

        foreach my $changedKey ( sort( keys( %{$changedKeys} ) ) )
        {
            my $printableBefore = $changedKeys->{$changedKey}->{'before'};
            my $printableAfter = $changedKeys->{$changedKey}->{'after'};

            if( defined( $printableBefore ) )
            {
                if( ( defined( $printableAfter ) )
                 && ( $printableAfter ne "" ) )
                {
                    my $removedRange = $changedKeys->{$changedKey}->{'removed'};
                    my $addedRange = $changedKeys->{$changedKey}->{'added'};

                    $printableBefore = "";
                    $printableAfter = "";

                    if( defined( $removedRange )
                     && ( $removedRange ne "" ) )
                    {
                        $printableAfter .= "       Removed: $removedRange\n";
                    }

                    if( defined( $addedRange )
                     && ( $addedRange ne "" ) )
                    {
                        $printableAfter .= "         Added: $addedRange\n";
                    }
                }
                else
                {
                    $printableBefore = "        Before: $printableBefore\n";
                    $printableAfter = "         After: <Undefined>\n";
                }
            }
            else
            {
                $printableBefore = "        Before: <Undefined>\n";

                if( ( defined( $printableAfter ) )
                 && ( $printableAfter ne "" ) )
                { 
                    $printableAfter = "         After: $printableAfter\n";
                }  
                else
                {  
                    $printableAfter = "         After: <Undefined>\n";
                }  
            }

            print "    Key Changed: $changedKey\n"
                . $printableBefore
                . $printableAfter
                . "\n"
                ;
        }

        print "\n";
    }

    return( 1 );
}

sub diffClusterHashes
{
    my( $beforeHash, $afterHash, $slcrHandle ) = @_;

    my $removedClusters = {};
    my $addedClusters = {};
    my $commonClusters = {};
    my $changedClusters = {};

    # Find the clusters Removed
    foreach my $beforeCluster ( sort( keys( %{$beforeHash} ) ) )
    {
        if( ! exists( $afterHash->{$beforeCluster} ) )
        {
            $removedClusters->{$beforeCluster} = $beforeHash->{$beforeCluster};
        }
        else
        {
            # Found it
            $commonClusters->{$beforeCluster} = 1;
        }
    }

    # Find the clusters Added
    foreach my $afterCluster ( keys( %{$afterHash} ) )
    {
        # This time we'll search commonClusters, should be smaller/faster than beforeHash
        if( ! exists( $commonClusters->{$afterCluster} ) )
        {
            $addedClusters->{$afterCluster} = $afterHash->{$afterCluster};
        }
    }

    # Find the diffed clusters
    foreach my $commonCluster ( sort( keys( %{$commonClusters} ) ) )
    {
        my $clusterChanged = 0;
        my $removedKeys = {};
        my $addedKeys = {};
        my $commonKeys = {};
        my $changedKeys = {};

        # Find the keys removed
        foreach my $beforeKey ( keys( %{$beforeHash->{$commonCluster}} ) )
        {
            if( ! exists( $afterHash->{$commonCluster}->{$beforeKey} ) )
            {   
                my $compressedBefore = $slcrHandle->compress( $slcrHandle->expand( $beforeHash->{$commonCluster}->{$beforeKey} ) );

                $removedKeys->{$beforeKey} = $compressedBefore;
                $clusterChanged = 1;
            }  
            else
            {   
                # Found it 
                $commonKeys->{$beforeKey} = 1;
            }
        }

        # Find the keys added
        foreach my $afterKey ( keys( %{$afterHash->{$commonCluster}} ) )
        {
            # This time we'll search commonKeys, should be smaller/faster than beforeHash
            if( ! exists( $commonKeys->{$afterKey} ) )
            {   
                my $compressedAfter = $slcrHandle->compress( $slcrHandle->expand( $afterHash->{$commonCluster}->{$afterKey} ) );

                $addedKeys->{$afterKey} = $compressedAfter;
                $clusterChanged = 1;
            }
        }

        # Find the diffed keys
        foreach my $commonKey ( sort( keys( %{$commonKeys} ) ) )
        {
            my $beforeValue = $beforeHash->{$commonCluster}->{$commonKey};
            my $afterValue = $afterHash->{$commonCluster}->{$commonKey};
            my( $compressedBefore, $compressedAfter );

            if( ( defined( $beforeValue ) )
             && ( $beforeValue ne "" ) )
            {
                if( ( ! defined( $afterValue ) )
                 || ( $beforeValue ne $afterValue ) )
                {
                    my $compressedBefore = $slcrHandle->compress( $slcrHandle->expand( $beforeValue ) );
                    my $compressedAfter = $slcrHandle->compress( $slcrHandle->expand( $afterValue ) );

                    if( ( ! defined( $compressedAfter ) )
                     || ( $compressedBefore ne $compressedAfter ) )
                    {
                        my $removedRange = $slcrHandle->range_sub( $beforeValue, $afterValue );
                        my $addedRange = $slcrHandle->range_sub( $afterValue, $beforeValue );

                        $changedKeys->{$commonKey} = { 'before'  => $compressedBefore,
                                                       'after'   => $compressedAfter,
                                                       'removed' => $removedRange,
                                                       'added'   => $addedRange,
                                                     };

                        $clusterChanged = 1;
                    }
                }
            }
            elsif( ( defined( $afterValue ) )
                && ( $afterValue ne "" ) )
            {
                my $compressedAfter = $slcrHandle->compress( $slcrHandle->expand( $afterValue ) );
                $changedKeys->{$commonKey} = { 'before' => $compressedBefore,
                                               'after'  => $compressedAfter,
                                             };
                $clusterChanged = 1;
            }
        }

        if( $clusterChanged )
        {
            $changedClusters->{$commonCluster} = { 'removedKeys' => $removedKeys,
                                                   'addedKeys'   => $addedKeys,
                                                   'changedKeys' => $changedKeys,
                                                 };
        }
    }

    return( { 'removedClusters' => $removedClusters,
              'addedClusters'   => $addedClusters,
              'changedClusters' => $changedClusters,
            }
          );
}


sub loadClusters
{
    my( $rangeHandle, $clusterRanges ) = @_;

    my $clustersHash = {};

    my @allClusters;
    foreach my $clusterRange ( @{$clusterRanges} )
    {
        # Some of the all/IGNORE clusters will simply fail to
        # expand, and we're basically ok with that.
        push( @allClusters, $rangeHandle->expand( $clusterRange ) );
    }

    foreach my $clusterName ( @allClusters )
    {
        if( exists( $clustersHash->{$clusterName} ) )
        {
            # ignore duplicate cluster names
            next;
        }

        my @kvLines = $rangeHandle->expand( "kv($clusterName)" );
        my %kvHash = map { split( /=/, $_, 2 ) } @kvLines;
        $clustersHash->{$clusterName} = \%kvHash;
    }

    return( $clustersHash );
}


sub listIgnoredClusters
{
    my( $stcConf ) = @_;

    my $stcDir = findStcDir( $stcConf );

    my @ignoredClusters;

    my $ignoredFD;
    if( ( defined( $stcDir ) )
     && ( open( $ignoredFD, "$stcDir/all/IGNORE" ) ) )
    {
        @ignoredClusters = map { chomp( $_ ); return( $_ ); } <$ignoredFD>;
        close( $ignoredFD );
    }

    return( @ignoredClusters );
}

sub findStcDir
{
    my( $stcConf ) = @_;

    my $stcDir;

    # See if the environment or the config file specify an alternate directory
    if( exists( $ENV{'LIBCRANGE_NODESCF_PATH'} ) )
    {
        $stcDir = $ENV{'LIBCRANGE_NODESCF_PATH'};
    }

    if( ! defined( $stcDir ) )
    {
        # No environment defined, try config file
        my $stcConfFD;
        if( open( $stcConfFD, $stcConf ) )
        {
            while( my $cfLine = <$stcConfFD> )
            {
                chomp( $cfLine );
                $cfLine =~ s/^\s+//;
                $cfLine =~ s/\s+$//;

                if( $cfLine =~ /^#/ )
                {
                    next;
                }
                
                my @splitCmd = split( /\s+/, $cfLine );

                if( ( ! defined( $splitCmd[0] ) )
                 || ( $splitCmd[0] eq "perlmodule" ) )
                {
                    # ignore perlmodule lines
                    next;
                }
                elsif( $splitCmd[0] eq "loadmodule" )
                {
                    if( ( defined( $splitCmd[1] ) )
                     && ( $splitCmd[1] eq "nodescf" ) )
                    {
                        # subsequent definitions don't matter once the nodescf module is loaded
                        last;
                    }

                    # ignore other loadmodule lines
                    next;
                }

                my @splitDef = split( /=/, $cfLine, 2 );

                if( ( defined( $splitDef[0] ) )
                 && ( $splitDef[0] eq "nodescf_path" ) )
                {
                    $stcDir = $splitDef[1];

                    # We'll keep looping in case it gets set more than once.
                }
            }

            close( $stcConfFD );
        }
    }

    if( ! defined( $stcDir ) )
    {
        # No environment, no config, use default
        $stcDir = $DEFAULT_STC_DIR;
    }

    return( $stcDir );
}


######################################################################
# Standard copyright for documentation
#

=head1 AUTHOR

David L. Armstrong <armstd@yahoo-inc.com>

=head1 COPYRIGHT AND LICENSE

Copyright (c) 2010 Yahoo! Inc.  All rights reserved.

=head1 SEE ALSO


=cut

