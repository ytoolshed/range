# Author Evan Miller eam@yahoo-inc.com
# Ruby bindings to librange

require 'dl/import'

class SecoRangeError < RuntimeError
end

module Seco
  module Range
    extend DL::Importable
    dlload "librange.so"
      
    extern "void range_startup()"
    extern "const char ** range_expand(const char *)"
    extern "const char ** range_expand_sorted(const char *)"
    extern "char * range_compress(const char **)"
    extern "char * range_parse(const char *)"
    extern "int range_set_altpath(const char *)"
    extern "void range_clear_caches()"
    extern "void range_want_caching(int)"
    extern "void range_want_warnings(int)"
    extern "char * range_get_exception()"
    extern "char * range_get_version()"
 
    range_startup()

    # override complex params
    class << self   
      alias range_want_caching_c range_want_caching
      alias range_want_warnings_c range_want_warnings

      def expand_range(range)
        res = range_expand(range)
        e = range_get_exception
        if e.nil?
          res.to_a('S')
        else
          raise SecoRangeError, e.dup
        end
      end
      def sorted_expand_range(r)
        res = range_expand_sorted(r)
        e = range_get_exception
        if e.nil?
          res.to_a('S')
        else
          raise SecoRangeError, e.dup
        end
      end
      def compress_range(r)
        r = r.dup << nil unless r[-1].nil?
        res = range_compress(r.to_ptr)
        e = range_get_exception
        if e.nil?
          res
        else
          raise SecoRangeError, e.dup
        end
      end
    end
  end
end
