"""
Library for querying the range webservice - http://github.com/ytoolshed/range
ebourget@linkedin.com
"""

import urllib2
import socket
import sys
import getpass

__version__ = '1.0'

class RangeException(Exception):
  def __init__(self, value):
    self.value = value
  def __str__(self):
    return repr(self.value)

class Range(object):
  def __init__(self, host, user_agent=None):
    self.host = host
    self.headers = {}
    self.headers['User-Agent'] = self.get_user_agent(user_agent)

  def expand(self, expr, ret_list=True):
    if isinstance(expr, list):
        expr = ','.join(expr)
    if ret_list:
      url = 'http://%s/range/list?%s' % (self.host, urllib2.quote(expr))
    else:
      url = 'http://%s/range/expand?%s' % (self.host, urllib2.quote(expr))
    range_req = urllib2.Request(url, None, self.headers)
    req = None
    try:
      req = urllib2.urlopen(range_req)
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

  def get_user_agent(self, provided_agent):
    """
    Build a verbose User-Agent for sending to the range server.
    Terribly useful if you ever have to track down crappy clients.
    """
    myhost = socket.gethostname()
    me = getpass.getuser()
    myscript = provided_agent or sys.argv[0] or 'seco.range'
    return '{0}/{1} ({2}; {3})'.format(myscript, __version__, me, myhost)

if __name__ == '__main__':
  try:
    r = Range("localhost:80")
  except RangeException as e:
    print e
    sys.exit(1)
  print r.expand(sys.argv[1])
