lib_LTLIBRARIES = libmodrange.la
libmodrange_la_SOURCES = mod_range.c
INCLUDES = -I@APACHE_INCDIR@ -I@LIBRANGE_INCDIR@
ACLOCAL_AMFLAGS = -I m4

install:
	@APXS@ -i -a -n range libmodrange.so
