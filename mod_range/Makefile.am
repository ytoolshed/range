lib_LTLIBRARIES = libmodrange.la
libmodrange_la_SOURCES = mod_range.c
libmodrange_la_CFLAGS = @APR_CFLAGS@ -I@APACHE_INCDIR@ -I$(top_srcdir)/src

ACLOCAL_AMFLAGS = -I m4

install:
	@echo "*** installing apache module via apxs ***"
	@APXS@ -i -a -n range libmodrange.la
	@echo "***"
	@echo "*** NOTE: module installed but not configured, see mod_apache/README ***"
	@echo "***"

