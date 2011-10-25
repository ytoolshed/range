use strict;
use warnings;


use Test::Simple qw/no_plan/;
use Test::Exception;

use Seco::Data::Writer;
use File::Copy;



print "Core functionality tests \n";

my ($obj,$range);

#################
init();
$obj = create();
ok( 
    (defined($obj) and (ref $obj eq 'Seco::Data::Writer')),
    'object created' 
  );
##################
init();
$obj = create();
$obj->deleteKey('WATCHER');
$obj->write;
$obj = create();
my %keys = map { $_ => 1 } $obj->dumpKeys();
ok (
      ! defined $keys{'WATCHER'},
      'deleteKey'
    );
####################
init ();
$obj = create();
$obj->addKey('TEST');
$obj->getKey('TEST')->include('test301999');
$obj->write;
$obj = create();
ok (
      $obj->getKey('TEST')->getRange eq 'test301999',
      'addKey'
      );
#####################
init();
$obj = create();
$obj->getKey('STABLE')->include('test301999');
$obj->write;
$obj = create();
$range = $obj->getKey('STABLE')->getRange;
ok (
      $obj->{r}->get_range ("$range,&test301999") eq 'test301999',
      'getKey->include'
   );
#####################
init();
$obj = create();
$obj->getKey('STABLE')->rminclude('test301200');
$obj->write;
$obj = create();
$range = $obj->getKey('STABLE')->getRange;
ok (
      $obj->{r}->get_range ("test301200,-($range)") eq 'test301200',
      'getKey->uninclude'
   );
######################
init();
$obj = create();
$obj->getKey('STABLE')->exclude('test301181');
$obj->write;
$obj = create();
$range = $obj->getKey('STABLE')->getRange;
ok (
      $obj->{r}->get_range ("test301181,-($range)") eq 'test301181',
      'getKey->exclude'
   );
########################
init();
$obj = create();
$obj->getKey('STABLE')->rmexclude('test301001');
$obj->write;
$obj = create();
$range = $obj->getKey('STABLE')->getRange;
ok (
      $obj->{r}->get_range ("test301001,&($range)") eq 'test301001',
      'getKey->rmexclude'
   );
##########################
print "Exception testing\n";

init();
$obj = create();
throws_ok 
            {$obj->getKey('STBLE')} qr /unknown key/ ,
            'getKey on unknown key' ;
############################
init();
$obj = create();
throws_ok 
            {$obj->addKey('STABLE')} qr /key exists/ ,
            'addKey on existing key' ;
############################
init();
$obj = create();
throws_ok 
            {$obj->deleteKey('STBLE')} qr /unknown key/ ,
            'deleteKey on unknown key' ;

#############################
sub init {
    system ('cp','-p','-f','./t/input/test301/nodes.cf.good' 
      =>  './t/input/test301/nodes.cf') == 0
    or die "copy: $!";
}

sub create {
   return Seco::Data::Writer::->new (
                     seco_alt_path => "$ENV{PWD}/t/input",
                     cluster =>  'test301',
                     edit   => '1',
                 );
}

__END__

# vim: syntax=perl ts=4 expandtab
