
#include <caml/alloc.h>
#include <caml/callback.h>
#include <caml/mlvalues.h>
#include <caml/memory.h>
#include <caml/custom.h>

#include <string.h>

#include "range.h"

value *cb_range_parse;
value *cb_range_expand;
value *cb_range_compress;
value *cb_range_expand_sorted;
value *cb_range_set_altpath;
value *cb_range_clear_caches;
value *cb_range_want_caching;
value *cb_range_want_warnings;
value *cb_range_set_warning_callback;


/* holds exception, if any, last call threw */

char * ocaml_exception = NULL;

/* Must be called before any range functions */
void range_startup() {
  char *argv[] = { "librange", NULL };
  caml_startup(argv);
  cb_range_parse = caml_named_value("ocaml_parse_range");
  cb_range_expand = caml_named_value("ocaml_expand_range");
  cb_range_compress = caml_named_value("ocaml_compress_range");
  cb_range_expand_sorted = caml_named_value("ocaml_sorted_expand_range");
  cb_range_set_altpath = caml_named_value("ocaml_range_set_altpath");
  cb_range_clear_caches = caml_named_value("ocaml_clear_caches");
  cb_range_want_caching = caml_named_value("ocaml_want_caching");
  cb_range_want_warnings = caml_named_value("ocaml_want_warnings");
  cb_range_set_warning_callback = caml_named_value("ocaml_set_warning_callback");
}

int range_set_exception(value caml_result) {
  if (Is_exception_result(caml_result)) {
    if (ocaml_exception) free(ocaml_exception);
    ocaml_exception = strdup(String_val(Field(Extract_exception(caml_result), 1)));
    return 1;
  } else {
    range_clear_exception();
    return 0;
  }
}

void range_clear_exception() {
    if (ocaml_exception) free(ocaml_exception);
    ocaml_exception = NULL;
}
char * range_get_exception() {
    return ocaml_exception;
}

char * range_get_version() {
    return LIBRANGE_VERSION;
}

/* fixme no error checking */
void range_free_nodes(const char ** nodes) {
  int i;
  for (i = 0; nodes[i] != NULL; i++) {
  	free(nodes[i]); /* free char pointers */
  }
  free(nodes); /* free char* pointers */
}

/* Generic range expander */

const char ** meta_range_expand(value *cb, const char * c_range) {
  const char ** c_result;
  int i;
  int num_nodes;
  CAMLparam0();
  CAMLlocal2(caml_result, caml_range);

  caml_range = caml_copy_string(c_range);
  caml_result = callback_exn(*cb, caml_range);

  if (range_set_exception(caml_result)) {
    CAMLreturn(NULL);
  } else {
    num_nodes = Wosize_val(caml_result);
    c_result = malloc( (num_nodes + 1) * sizeof(char*) );

    for (i = 0; i < num_nodes; i++) {
      char * t;
      t = String_val(Field(caml_result,i));
      c_result[i] = strdup(t);
    }
    c_result[num_nodes] = NULL;
    CAMLreturn(c_result);
  }
}

const char ** range_expand(const char * c_range) {
  return meta_range_expand(cb_range_expand, c_range);
}
const char ** range_expand_sorted(const char * c_range) {
  return meta_range_expand(cb_range_expand_sorted, c_range);
}

/*
 *   Compress a bunch of nodes into a range
 */

char * range_compress(const char ** c_nodes, const char* c_separator) {
  CAMLparam0();
  CAMLlocal3(caml_result, caml_nodes, caml_separator);

  caml_nodes = copy_string_array(c_nodes);
  caml_separator = caml_copy_string(c_separator);
  caml_result = callback2_exn(*cb_range_compress, caml_nodes, caml_separator);

  if (range_set_exception(caml_result))
    CAMLreturn(NULL);
  else
    CAMLreturn(strdup(String_val(caml_result)));
}

/*
 *  Parse a range by expanding, then compressing
 */

char * range_parse(const char * c_range) {
  CAMLparam0();
  CAMLlocal2(caml_result, caml_range);

  caml_range = caml_copy_string(c_range);
  caml_result = callback_exn(*cb_range_parse, caml_range);

  if (range_set_exception(caml_result))
    CAMLreturn(NULL);
  else
    CAMLreturn(strdup(String_val(caml_result)));
}

/* set altpath */

void range_set_altpath(const char * c_path) {
  CAMLparam0();
  CAMLlocal2(caml_result, caml_path);

  caml_path = caml_copy_string(c_path);
  caml_result = callback_exn(*cb_range_set_altpath, caml_path);

  range_set_exception(caml_result);
  CAMLreturn0;
}

void range_clear_caches() {
  CAMLparam0();
  CAMLlocal1(caml_result);
  caml_result = callback_exn(*cb_range_clear_caches, Val_unit);
  range_set_exception(caml_result);
  CAMLreturn0;
}

void range_want_caching(int c_want) {
  CAMLparam0();
  CAMLlocal1(caml_result);
  caml_result = callback_exn(*cb_range_want_caching, Val_bool(c_want));
  range_set_exception(caml_result);
  CAMLreturn0;
}

void range_want_warnings(int c_want) {
  CAMLparam0();
  CAMLlocal1(caml_result);
  caml_result = callback_exn(*cb_range_want_warnings, Val_bool(c_want));
  range_set_exception(caml_result);
  CAMLreturn0;
}
