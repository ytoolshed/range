package LibrangeOpsdb;

use Seco::OpsDB;

sub functions_provided {
    Seco::OpsDB->connect;
    return qw/order orders/;
}

sub orders {
    my @result;
    my $it = Seco::OpsDB::NodesGroup->search_where( gtype => 'groups' );
    while ( my $order = $it->next ) {
        push @result, $order->name;
    }
    return @result;
}

sub order {
    my ( $rr, $r_orders ) = @_;
    my @result;
    for my $order (@$r_orders) {
        my $it = Seco::OpsDB::NodesGroup->retrieve(
            gname => $order,
            gtype => 'groups'
        );
        while ( my $node = $it->next ) {
            push @result, $node->name;
        }
    }
    return @result;
}

1
