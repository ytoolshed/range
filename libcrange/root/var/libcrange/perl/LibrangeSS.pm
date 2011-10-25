package LibrangeSS;

sub functions_provided {
  return qw/ ds_rid flatten flatten_all /;
}

sub _get_seco_root {
  my $SECO_ROOT = "/home/seco/tools/conf/";
  return $SECO_ROOT;
}

sub ds_rid {
  eval "require YAML::Syck";
  return () if ($@);

  my $rr    = shift;
  my $range = shift;
  return "one node at a time" if scalar @$range != 1;

  my $SECO_ROOT = _get_seco_root();

  my $node = pop @$range;
  my $cluster = Libcrange::expand($rr, "clusters(clusters(clusters($node)))");

  my $rid_file = $SECO_ROOT . $cluster . '/rid.yaml';
  my $rid      = YAML::Syck::LoadFile($rid_file);

  return $rid->{$node};
}

sub rid_map {
  my $rr    = shift;
  my $range = shift;
  return "one cluster at a time" if scalar @$range != 1;

  my $SECO_ROOT = _get_seco_root();

  my $cluster  = pop @$range;
  my $rid_file = $SECO_ROOT . $cluster . '/rid.yaml';

  open $fh, "$rid_file" or return "can't open rid file";
  my $contents = join '', <$fh>;
  close $fh;

  return $contents;
}

sub flatten {
  my $rr    = shift;
  my $range = shift;

  my @ret = ();

  for my $elem (@{ $range }){
    if (my @expansion = Libcrange::expand($rr, "%$elem") ){
      push @ret, flatten( $rr, [ $_ ] ) for @expansion;
    }
    else {
      push @ret, $elem;
    }
  }

  return @ret;
}

sub flatten_all {
  my $rr    = shift;
  my $range = shift;

  use Data::Dumper;
  warn Dumper $range;

  my @ret = ();

  for my $elem (@{ $range }){
    if (my @expansion = Libcrange::expand($rr, "%$elem") ){
      push @ret, flatten_all( $rr, [ $_ . ":ALL" ] ) for @expansion;
    }
    else {
      push @ret, $elem;
    }
  }

  return @ret;
}
1;
