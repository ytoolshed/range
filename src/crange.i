%module Crange
%{
#include "librange.h"
%}
%include "libcrange.h"
%inline %{
char **string_array(int size) {
     int i;
     char **a = (char **)malloc(sizeof(char *) * size);
     for(i = 0; i < size; i++) {
           a[i] = NULL;
     }
     return a;
}
void string_destroy(char **a) {
     free(a);
}
void string_set(char **a, int i, char *val) {
     a[i] = val;
}
char *string_get(char **a, int i) {
     return a[i];
}

%}
