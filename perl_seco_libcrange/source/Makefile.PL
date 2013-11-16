use 5.006;
use ExtUtils::MakeMaker;

sub find_executable {
    my $exe = shift;
    my @PATH = split ":", $ENV{PATH};
    my $dir = (grep { -x "$_/$exe" } @PATH)[0];
    return unless $dir;

    print "Using $dir/$exe\n";
    return "$dir/$exe";
}

my $apr_config = find_executable("apr-config");
$apr_config ||= find_executable("apr-1-config");

my $ld_flags = `$apr_config --link-ld`;
chomp($ld_flags);
my $c_flags = `$apr_config --cflags --cppflags --includes`;
chomp($c_flags);

WriteMakefile(
    NAME              => 'Seco::Libcrange',
    VERSION_FROM      => 'lib/Seco/Libcrange.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Seco/Libcrange.pm', # retrieve abstract from module
       AUTHOR         => 'Syam Puranam <github@syam.in>') : ()),
   # Libcrange unfortunately installs 64 bit libraries in 32 bit paths
    LIBS              => [" -L/usr/lib -L/usr/local/lib -lcrange $ld_flags"], # e.g., '-lm'
    DEFINE            => '', # e.g., '-DHAVE_SOMETHING'
    INC               => "-I. $c_flags", # e.g., '-I. -I/usr/include/other'
	# Un-comment this if you add C files to link with later:
    # OBJECT            => '$(O_FILES)', # link all the C files too
);
