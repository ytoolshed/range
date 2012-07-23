OCAMLMAKEFILE = OCamlMakefile

SOURCES = memoize.ml range_utils.ml parser.mly lexer.mll tinydns.ml \
	  netmask.ml netblocks.ml admins.ml hosts_netblocks.ml evaluate.ml range.ml
RESULT  = range
PACKS = pcre
LIBS = unix

PATH = /usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin

LDPATH=-L /usr/lib/ocaml/site-lib/pcre/ -L /usr/local/lib -L /usr/lib

OCAML_PCRE=$(shell ocamlfind query pcre)
OCAML_STDLIB=$(shell ocamlfind query unix)

librange.so: camlcode.o librange.o 
	ld -fPIC -Bsymbolic -shared --whole-archive -o librange.so camlcode.o librange.o $(OCAML_STDLIB)/libunix.a $(OCAML_STDLIB)/libasmrun.a $(OCAML_PCRE)/libpcre_stubs.a -lm -lpcre -ldl


# unused 
#pcre_stubs.o:
#	ar x /opt/godi/lib/ocaml/pkg-lib/pcre/libpcre_stubs.a
# unused 
#libunix_unix.o:
#	sh rip_objects_hack.sh /opt/godi/lib/ocaml/std-lib

install:
	mkdir -p $(DESTDIR)/usr/include/ $(DESTDIR)/usr/lib/
	install -m 644 range.h $(DESTDIR)/usr/include/
	install -m 755 librange.so $(DESTDIR)/usr/lib/

camlcode.o: ncl
	ocamlopt -fPIC -I $(OCAML_PCRE) -output-obj -o camlcode.o unix.cmxa pcre/pcre.cmxa range_utils.cmx parser.cmx lexer.cmx memoize.cmx tinydns.cmx netmask.cmx admins.cmx netblocks.cmx hosts_netblocks.cmx evaluate.cmx range.cmx

librange.o: librange.c
	gcc -fPIC -Wall -g -c librange.c -I $(OCAML_STDLIB)

cleaner: clean
	rm -f librange.so librange.o testrange camlcode.o pcre_stubs.o
	rm -rf a b 
	rm -f memoize.o memoize.cmx 

include $(OCAMLMAKEFILE)

