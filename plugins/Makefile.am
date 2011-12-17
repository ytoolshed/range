# for yamlfile
LIBRANGE_YAML_DIR = "@localstatedir@/range"
# for sqlite
LIBRANGE_SQLITE_DB = "@localstatedir@/range/range.sqlite"
# for ip-list
LIBRANGE_IP_LIST = "@localstatedir@/range-ip-list"

PLUGIN_PATHDEFS = $(PATHDEFS) \
									-DLIBRANGE_YAML_DIR=\"$(LIBRANGE_YAML_DIR)\" \
									-DLIBRANGE_SQLITE_DB=\"$(LIBRANGE_SQLITE_DB)\" \
									-DLIBRANGE_IP_LIST=\"$(LIBRANGE_IP_LIST)\"

AM_CFLAGS = -g -pg -Wall @PCRE_CFLAGS@ @APR_CFLAGS@ $(PLUGIN_PATHDEFS)
AM_LDFLAGS = -module -L$(top_srcdir)/src -lrange -lyaml -lsqlite3 @PCRE_LIBS@ @APR_LIBS@

pkglib_LTLIBRARIES = ip-list.la ip.la nodescf.la yamlfile.la sqlite.la

sqlite_la_SOURCES = sqlite.c
nodescf_la_SOURCES = nodescf.c
yamlfile_la_SOURCES = yamlfile.c
ip_list_la_SOURCES = ip-list.c netblock.c tinydns_ip.c \
                         hosts-netblocks.c
ip_la_SOURCES = ip.c tinydns_ip.c

yamldir = $(LIBRANGE_YAML_DIR)
yaml_DATA = example.foo.yaml example.bar.yaml
