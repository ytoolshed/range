AM_YFLAGS = -d
AM_CFLAGS = -fPIC -Wall
bin_PROGRAMS = range

range_SOURCES = main.c
range_CFLAGS = @APR_CFLAGS@
range_LDFLAGS = -lrange @PERL_LIBS@ @APR_LIBS@
include_HEADERS = librange.h

BUILT_SOURCES = range_scanner.h
lib_LTLIBRARIES = librange.la
librange_la_SOURCES = range_parser.y range_scanner.l \
          set.c range_request.c \
          range_sort.c range_parts.c perl_functions.c \
          librange.c ast.c range_compress.c \
          range.c

librange_la_CFLAGS = -Wall @PERL_CFLAGS@ @PCRE_CFLAGS@ @APR_CFLAGS@
librange_la_LDFLAGS = @PERL_LIBS@ @PCRE_LIBS@ @APR_LIBS@

range_scanner.h:
	$(LEX) range_scanner.l

