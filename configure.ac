# Process this file with autoconf to produce a configure script.

AC_PREREQ(2.59)
AC_INIT([librange], [1.1], [ytoolshed@hep.cat])
AC_CONFIG_SRCDIR([src/librange.h])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])
AM_CONFIG_HEADER([src/config.h])
AM_INIT_AUTOMAKE

AC_DEFINE_UNQUOTED([PACKAGE], ["$PACKAGE"], [Package name])
AC_DEFINE_UNQUOTED([VERSION], ["$VERSION"], [Package version])

# Checks for programs.
AC_PROG_YACC
AM_PROG_LEX
AC_PROG_CC
AC_LANG_C
AC_PROG_INSTALL
AC_PROG_MAKE_SET
AC_PROG_LIBTOOL
AM_PROG_CC_C_O


# begin perl checking
perl_default="/usr/local/bin/perl"
AC_ARG_ENABLE(
  perl,
  AC_HELP_STRING([--enable-perl@<:@=PERL@:>@],
    [Use this perl binary to build perl functionality.  Requires libperl and working PCRE.  (default = /usr/local/bin/perl)]),
    if test "$enableval" == "yes"; then
      PERL=$perl_default
    else
      PERL=$enableval
    fi
)
AM_CONDITIONAL([WANT_PERL], [test ! -z "$PERL"])

AC_ARG_ENABLE(
  [mod-range],
  AC_HELP_STRING([--enable-mod-range],
    [Build apache module (Default = enabled)]),
    MOD_RANGE=$enableval)
AM_CONDITIONAL([WANT_MODRANGE], [test "$MOD_RANGE" == "yes"])

AC_DEFUN([AC_CHECK_PERL],[
AC_MSG_CHECKING(perl in $PERL)
if test [ -f "$PERL" ]
then
  AC_SUBST(PERL)
  AC_MSG_RESULT(yes)
  AC_MSG_CHECKING(perl includes)
  PERL_CFLAGS=`${PERL} -MExtUtils::Embed -e ccopts`
  AC_SUBST(PERL_CFLAGS)
  AC_MSG_RESULT($PERL_CFLAGS)
  AC_MSG_CHECKING(perl libraries)
  PERL_LIBS=`${PERL} -MExtUtils::Embed -e ldopts`
  AC_SUBST(PERL_LIBS)
  AC_MSG_RESULT($PERL_LIBS)
else
  AC_MSG_ERROR([${PERL} not found])
fi
])

AC_DEFUN([AC_CHECK_PCRE],[
AC_PATH_PROG(pcreconfig,pcre-config)
if test [ -z "$pcreconfig" ]
then
    AC_MSG_ERROR([pcre-config executable not found])
else
    AC_MSG_CHECKING(pcre includes)
    PCRE_CFLAGS=`${pcreconfig} --cflags`
    AC_MSG_RESULT($PCRE_CFLAGS)
    AC_SUBST(PCRE_CFLAGS)
    AC_MSG_CHECKING(pcre libraries)
    PCRE_LIBS=`${pcreconfig} --libs`
    AC_MSG_RESULT($PCRE_LIBS)
    AC_SUBST(PCRE_LIBS)
fi
])

AC_DEFUN([AC_CHECK_APR],[
AC_PATH_PROG(aprconfig,apr-config)
if test [ -z "$aprconfig" ]
then
    AC_PATH_PROG(aprconfig, apr-1-config)
fi
if test [ -z "$aprconfig" ]
then
    AC_MSG_ERROR([apr-config/apr-1-config executable not found])
else
    AC_MSG_CHECKING(apr includes)
    APR_CFLAGS=`${aprconfig} --cflags --cppflags --includes`
    AC_MSG_RESULT($APR_CFLAGS)
    AC_SUBST(APR_CFLAGS)
    AC_MSG_CHECKING(apr libraries)
    APR_LIBS=`${aprconfig} --link-libtool --libs`
    APR_LIBS_LD=`${aprconfig} --link-ld --libs`
    AC_MSG_RESULT($APR_LIBS)
    AC_SUBST(APR_LIBS)
    AC_SUBST(APR_LIBS_LD)
fi
])

AC_DEFUN([AC_CHECK_APXS],[
AC_CHECK_PROGS(APXS,[apxs apxs2],[],[path=$PATH$PATH_SEPARATOR/usr/local/apache$PATH_SEPARATOR/usr/apache])
if test -z "$APXS"; then
  AC_MSG_ERROR("apxs not found")
fi
])

# always need APR
AC_CHECK_APR

# optionally check for perl
if test ! -z "$PERL"; then
  AC_CHECK_PERL
  AC_CHECK_PCRE
fi

# optionally check for apxs
if test ! -z "$MOD_RANGE"; then
  AC_CHECK_APXS
fi

AC_CHECK_LIB([m], [sin], [], [exit 1])
AC_CHECK_LIB([pthread], [pthread_create], [], [exit 1])
AC_CHECK_LIB([z], [zlibVersion], [], [exit 1])

# Checks for header files.
AC_HEADER_STDC
AC_CHECK_HEADERS([stdlib.h string.h unistd.h])

# Checks for typedefs, structures, and compiler characteristics.
AC_C_CONST
AC_TYPE_SIZE_T

# Checks for library functions.
AC_FUNC_STAT
AC_FUNC_STRERROR_R
AC_CHECK_FUNCS([strerror])

AC_CONFIG_FILES([Makefile
                 doc/Makefile
                 m4/Makefile
                 src/Makefile
                 plugins/Makefile])
AC_OUTPUT
