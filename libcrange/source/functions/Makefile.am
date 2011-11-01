AM_CFLAGS = -g -pg -Wall -DLIBCRANGE_FUNCDIR=\"$(pkglibdir)\" -I../src @PCRE_CFLAGS@ @APR_CFLAGS@
AM_LDFLAGS = -module -L../src -lcrange -lyaml -lsqlite3 @PCRE_LIBS@ @APR_LIBS@

pkglib_LTLIBRARIES = yst-ip-list.la ip.la nodescf.la yamlfile.la sqlite.la

sqlite_la_SOURCES = sqlite.c
nodescf_la_SOURCES = nodescf.c
yamlfile_la_SOURCES = yamlfile.c
yst_ip_list_la_SOURCES = yst-ip-list.c netblock.c tinydns_ip.c \
                         hosts-netblocks.c
ip_la_SOURCES = ip.c tinydns_ip.c



