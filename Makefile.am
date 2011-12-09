ACLOCAL_AMFLAGS = -I m4

if WANT_MODRANGE
	MAYBE = mod_range $(MAYBE)
endif

#if WANT_PERL
#	MAYBE = perl
#endif

# stealing from http://www.gnu.org/prep/standards/html_node/Directory-Variables.html */
LIBRANGE_CONF 		= "@sysconfdir@/librange.conf"
LIBRANGE_FUNCDIR 	= "@libdir@/librange"
LIBRANGE_DATADIR 	= "@localstatedir@/range"
PATHDEFS = -DLIBRANGE_CONF=\"$(LIBRANGE_CONF)\" \
					-DLIBRANGE_FUNCDIR=\"$(LIBRANGE_FUNCDIR)\" \
					-DLIBRANGE_DATADIR=\"$(LIBRANGE_DATADIR)\" \
					-DDEFAULT_SQLITE_DB=\"$(DEFAULT_SQLITE_DB)\"


SUBDIRS = src plugins $(MAYBE) doc
EXTRA_DIST = configure attic m4 clients utils

