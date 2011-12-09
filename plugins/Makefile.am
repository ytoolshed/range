# for yamlfile
LIBRANGE_YAML_DIR = "@localstatedir@/range"
# for sqlite
DEFAULT_SQLITE_DB = "@localstatedir@/range/range.sqlite"

PLUGIN_PATHDEFS = $(PATHDEFS) \
									-DLIBRANGE_YAML_DIR=\"$(LIBRANGE_YAML_DIR)\" \
									-DDEFAULT_SQLITE_DB=\"$(DEFAULT_SQLITE_DB)\"

AM_CFLAGS = -g -pg -Wall @PCRE_CFLAGS@ @APR_CFLAGS@ $(PLUGIN_PATHDEFS)
AM_LDFLAGS = -module -L$(top_srcdir)/src -lrange -lyaml -lsqlite3 @PCRE_LIBS@ @APR_LIBS@

pkglib_LTLIBRARIES = yst-ip-list.la ip.la nodescf.la yamlfile.la sqlite.la

sqlite_la_SOURCES = sqlite.c
nodescf_la_SOURCES = nodescf.c
yamlfile_la_SOURCES = yamlfile.c
yst_ip_list_la_SOURCES = yst-ip-list.c netblock.c tinydns_ip.c \
                         hosts-netblocks.c
ip_la_SOURCES = ip.c tinydns_ip.c

