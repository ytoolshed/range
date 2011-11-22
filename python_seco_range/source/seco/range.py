"""
Library for querying the range webservice - http://github.com/ytoolshed/range
ebourget@linkedin.com
"""

import urllib2
import sys

class RangeException(Exception):
    def __init__(self, value):
        self.value = value
    def __str__(self):
        return repr(self.value)

class Range(object):
    def __init__(self, host):
        self.host = host

    def expand(self, expr, ret_list=True):
        if isinstance(expr, list):
                expr = ','.join(expr)
        if ret_list:
            url = 'http://%s/range/list?%s' % (self.host, urllib2.quote(expr))
        else:
            url = 'http://%s/range/expand?%s' % (self.host, urllib2.quote(expr))
        req = None
        try:
            req = urllib2.urlopen(url)
        except urllib2.URLError, e:
            raise RangeException(e)
        code = req.getcode()
        if code != 200:
            raise RangeException("Got %d response code from %s" % (code, url))
        reqinfo = req.info()
        exception = reqinfo.getheader('RangeException')
        if exception:
            raise RangeException(exception)
        if ret_list:
            expansion = []
            for line in req.readlines():
                expansion.append(line.rstrip())
            expansion.sort()
            return expansion
        else:
            return req.read()

    def collapse(self, expr):
        return self.expand(expr, ret_list=False)

if __name__ == '__main__':
    try:
        r = Range("localhost:80")
    except RangeException as e:
        print e
        sys.exit(1)
    print r.expand(sys.argv[1])
