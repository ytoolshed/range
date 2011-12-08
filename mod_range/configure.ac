# for gnu autoconf
AC_PREREQ(2.59)
AC_INIT([mod_range],[1.0],[ytoolshed@hep.cat])
AC_CONFIG_MACRO_DIR([m4])
AC_CONFIG_AUX_DIR([build-aux])
AM_INIT_AUTOMAKE

AC_DEFINE_UNQUOTED([PACKAGE], ["$PACKAGE"], [Package name])
AC_DEFINE_UNQUOTED([VERSION], ["$VERSION"], [Package version])
AC_SUBST(PACKAGE)
AC_SUBST(VERSION)

AC_PROG_CC
AC_PROG_LIBTOOL

# find range headers
LIBRANGE_PREFIX="/usr/local"
AC_ARG_WITH(librange,
            [AC_HELP_STRING([[--with-librange[=DIR]]],
                            [location of librange headers])],
[
    if test "$withval" != "yes"; then
      LIBRANGE_PREFIX="$withval"
    fi
])

AC_MSG_CHECKING(for librange)
if test -z "$LIBRANGE_PREFIX"; then
  for i in /usr/local /usr; do
    if test -f "$i/include/librange.h"; then
      LIBRANGE_INCDIR="$i/include"
      break
    fi
  done
else
  if test -f "$LIBRANGE_PREFIX/include/librange.h"; then
    LIBRANGE_INCDIR="$LIBRANGE_PREFIX/include"
    break
  fi
fi

if test -z "$LIBRANGE_INCDIR"; then
  AC_MSG_RESULT(not found)
  exit 1
else
  AC_MSG_RESULT(ok)
fi

AC_SUBST(LIBRANGE_INCDIR)

# check for apxs
AC_ARG_WITH(apxs,
            [AS_HELP_STRING([[--with-apxs[=FILE]]],
                            [path to the apxs, defaults to "apxs".])],
[
    if test "$withval" = "yes"; then
      APXS=apxs
    else
      APXS="$withval"
    fi
])

AC_MSG_CHECKING(for apxs)
if test -z "$APXS"; then
  for i in /usr/sbin /usr/local/apache/bin /usr/bin ; do
    if test -f "$i/apxs2"; then
      APXS="$i/apxs2"
      AC_MSG_RESULT(yes)
      break
    fi
    if test -f "$i/apxs"; then
      APXS="$i/apxs"
      AC_MSG_RESULT(yes)
      break
    fi
  done
fi

APACHE_INCDIR=`$APXS -q INCLUDEDIR`
AC_SUBST(APXS)
AC_SUBST(APACHE_INCDIR)

AC_OUTPUT(Makefile)

