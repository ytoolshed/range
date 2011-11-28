AM_YFLAGS = -d
AM_CFLAGS = -fPIC -Wall
bin_PROGRAMS = crange

crange_SOURCES = main.c
crange_CFLAGS = @APR_CFLAGS@
crange_LDFLAGS = -lcrange @PERL_LIBS@ @APR_LIBS@
include_HEADERS = libcrange.h

BUILT_SOURCES = range_scanner.h
lib_LTLIBRARIES = libcrange.la
libcrange_la_SOURCES = range_parser.y range_scanner.l \
          set.c range_request.c \
          range_sort.c range_parts.c perl_functions.c \
          libcrange.c ast.c range_compress.c \
          range.c

libcrange_la_CFLAGS = -Wall -DLIBCRANGE_FUNCDIR=\"$(pkglibdir)\" -DLIBCRANGE_CONF=\"$(sysconfdir)/range.conf\" -DDEFAULT_SQLITE_DB=\"$(localstatedir)/range.sqlite\" -DLIBCRANGE_YAML_DIR=\"$(sysconfdir)/range/\" @PERL_CFLAGS@ @PCRE_CFLAGS@ @APR_CFLAGS@
libcrange_la_LDFLAGS = @PERL_LIBS@ @PCRE_LIBS@ @APR_LIBS@

range_scanner.h:
	$(LEX) range_scanner.l




