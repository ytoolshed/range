
#define LIBRANGE_VERSION "2.0.0"

void range_startup(void);
const char ** range_expand(const char * c_range);
const char ** range_expand_sorted(const char * c_range);
char * range_compress(const char ** c_nodes, const char * c_separator);
char * range_parse(const char * c_range);
void range_set_altpath(const char * c_path);
void range_free_nodes(const char ** p);
void range_clear_caches();

void range_want_caching(int);
void range_want_warnings(int);

char * range_get_exception();
void range_clear_exception();
char * range_get_version();
