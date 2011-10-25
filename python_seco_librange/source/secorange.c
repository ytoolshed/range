#include <Python.h>
#include "range.h"

static PyObject *exception = NULL;

static PyObject*
secorange_sortedexpandrange(PyObject *self, PyObject *args)
{
  const char* range;
  int i;
  PyObject* retval = NULL;
  const char** r;

  if (!PyArg_ParseTuple(args, "s", &range))
    return NULL;

  r = range_expand_sorted(range);
  if (range_get_exception()) {
    PyErr_SetString(exception, range_get_exception());
    return NULL;
  }
  retval = PyList_New(0);
  for (i=0; r[i] != NULL; i++) 
    PyList_Append(retval, PyString_FromString(r[i]));

  return retval;
}

static PyObject*
secorange_expandrange(PyObject *self, PyObject *args)
{
  const char* range;
  int i;
  PyObject* retval = NULL;
  const char** r;

  if (!PyArg_ParseTuple(args, "s", &range))
    return NULL;

  r = range_expand(range);
  if (range_get_exception()) {
    PyErr_SetString(exception, range_get_exception());
    return NULL;
  }
  retval = PyList_New(0);
  for (i=0; r[i] != NULL; i++) 
    PyList_Append(retval, PyString_FromString(r[i]));

  return retval;
}

static PyObject*
secorange_compressrange(PyObject *self, PyObject *args)
{
  int i, length;
  PyObject* nodes;
  const char** node_lst;
  const char* result;

  if (!PyArg_ParseTuple(args, "O", &nodes))
    return NULL;

  length = PyList_Size(nodes);
  node_lst = malloc(sizeof(char*) * (length + 1));
  for (i=0; i<length; i++)
    node_lst[i] = PyString_AsString(PyList_GetItem(nodes, i));
  node_lst[length] = NULL;

  result = range_compress(node_lst, ",");
  free(node_lst);
  if (range_get_exception()) {
    PyErr_SetString(exception, range_get_exception());
    return NULL;
  }

  return Py_BuildValue("s", result);
}

static PyObject*
secorange_librangeversion(PyObject *self, PyObject *args)
{
  return Py_BuildValue("s", range_get_version());
}

static PyObject*
secorange_clearcaches(PyObject *self, PyObject *args)
{
  range_clear_caches();
  Py_INCREF(Py_None);
  return Py_None;
}

static PyObject*
secorange_setaltpath(PyObject *self, PyObject *args)
{
  const char* path;
  if (!PyArg_ParseTuple(args, "s", &path))
    return NULL;
  range_set_altpath(path);
  if (range_get_exception()) {
    PyErr_SetString(exception, range_get_exception());
    return NULL;
  }
  Py_INCREF(Py_None);
  return Py_None;
}

static PyObject*
secorange_wantcaching(PyObject *self, PyObject *args)
{
  int want;
  if (!PyArg_ParseTuple(args, "i", &want))
    return NULL;

  range_want_caching(want);
  if (range_get_exception()) {
    PyErr_SetString(exception, range_get_exception());
    return NULL;
  }
  Py_INCREF(Py_None);
  return Py_None;
}

static PyObject*
secorange_wantwarnings(PyObject *self, PyObject *args)
{
  int want;
  if (!PyArg_ParseTuple(args, "i", &want))
    return NULL;

  range_want_warnings(want);
  if (range_get_exception()) {
    PyErr_SetString(exception, range_get_exception());
    return NULL;
  }
  Py_INCREF(Py_None);
  return Py_None;
}


static PyMethodDef SecorangeMethods[] = {
  {"expand_range", secorange_expandrange, METH_VARARGS,
   "Expand a seco range returning a list of nodes (not sorted)"},
  {"compress_range", secorange_compressrange, METH_VARARGS,
   "Compress a list of nodes"},
  {"sorted_expand_range", secorange_sortedexpandrange, METH_VARARGS,
   "Expand a seco range returning a list of nodes (sorted)"},
  {"range_set_altpath", secorange_setaltpath, METH_VARARGS,
   "Change the location of where to look for nodes.cf files"},
  {"librange_version", secorange_librangeversion, METH_VARARGS,
   "Get version of underlying librange"},
  {"want_caching", secorange_wantcaching, METH_VARARGS,
   "Enable or disable caching"},
  {"want_warnings", secorange_wantwarnings, METH_VARARGS,
   "Enable or disable warnings"},
  {"clear_caches", secorange_clearcaches, METH_VARARGS,
   "Clear caches"},
  {NULL, NULL, 0, NULL}
};


PyMODINIT_FUNC
initsecorange(void)
{
  PyObject *module, *dict;
  range_startup();
  module = Py_InitModule("secorange", SecorangeMethods);

  dict = PyModule_GetDict(module);
  exception = PyErr_NewException("secorange.error", NULL, NULL);
  PyDict_SetItemString(dict, "error", exception);

}
