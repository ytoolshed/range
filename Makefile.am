if WANT_MODRANGE
	MAYBE = mod_range $(MAYBE)
endif

#if WANT_PERL
#	MAYBE = perl
#endif

# stealing from http://www.gnu.org/prep/standards/html_node/Directory-Variables.html */
LIBRANGE_CONF = @sysconfdir@/librange.conf
DEFAULT_SQLITE_DB = @localstatedir@/range.sqlite
LIBRANGE_FUNCDIR = @libdir@/librange/

SUBDIRS = src plugins $(MAYBE) doc
EXTRA_DIST = configure attic m4 clients utils
ACLOCAL_AMFLAGS = -I m4
LIBRANGE_DATADIR = "/var/range"


