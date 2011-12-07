use 5.006000;
use ExtUtils::MakeMaker;

# install into version-independent path
use Config;
my $installsitelib = $Config{installsitelib};
$installsitelib =~ s/\/[0-9\.]+$//;
die "version-independent libdir not found in \@INC"
    unless (grep { $_ eq $installsitelib } (@INC));

WriteMakefile(NAME => 'Seco::Data::Range',
              VERSION => '1.0',
              INSTALLSITELIB => $installsitelib);
