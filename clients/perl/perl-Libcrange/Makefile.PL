use 5.006;
use ExtUtils::MakeMaker;

my $ld_flags = " -L/usr/lib -lapr-1 -lpthread";
my $c_flags  = "  -DDARWIN -DSIGPROCMASK_SETS_THREAD_MASK -I/usr/include/apr-1 ";

WriteMakefile(
    NAME         => 'Libcrange',
    VERSION_FROM => 'lib/Libcrange.pm',    # finds $VERSION
    PREREQ_PM    => {},                    # e.g., Module::Name => 1.1
    (
        $] >= 5.005
        ?    ## Add these new keywords supported since 5.005
          (
            ABSTRACT_FROM => 'lib/Libcrange.pm', # retrieve abstract from module
            AUTHOR => 'Daniel Muino <dmuino@yahoo-inc.com>'
          )
        : ()
    ),
    LIBS => ["-L/usr/local/lib -lcrange $ld_flags"],    # e.g., '-lm'
    DEFINE => '',                         # e.g., '-DHAVE_SOMETHING'
    INC    => "-I. -I../src $c_flags",    # e.g., '-I. -I/usr/include/other'
         # Un-comment this if you add C files to link with later:
         # OBJECT            => '$(O_FILES)', # link all the C files too
);
