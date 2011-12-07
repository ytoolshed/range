package Seco::Embed::Range;

use lib '/var/libcrange/perl';
use Data::Dumper;

my %functions;

sub load_file {
    my ($prefix, $module) = @_;

#   print STDERR "Loading $module prefix=[$prefix]\n";
    require "$module.pm";
    my @functions = $module->functions_provided;
    my @mapped_functions = map { "$prefix$_" } @functions;

    for (@functions) {
        $functions{"$prefix$_"} = \&{"${module}::$_"};
    }

    @mapped_functions;
}

sub call_func {
    my $func = shift;
    my @args = @_;

    my $fun_ref = $functions{$func};
    die "No function $func\n" unless $fun_ref;

    &$fun_ref(@args);
}

1;
