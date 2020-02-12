"""
A range sync plugin to download all the files from a remote URL
"""
# Core libs
import os
import re
import shutil
import tempfile

# 3rd party
import requests
from bs4 import BeautifulSoup

# Local

def sync(args, debug=False):
  import seco.range.sync.local as local_sync

  url = args['url']
  if debug: print("URL is %s" % url)
  file_re = re.compile(args['filter'])
  if debug: print("Filter is %s" % file_re)
  req = requests.get(url)
  if debug: print("Request made")
  content = BeautifulSoup(req.content)
  if debug: print("Request parsed")

  content_links = content.findAll('a')

  files = set()
  for link in content_links:
    if debug: print("Inspecting %s" % link)
    if file_re.search(link['href']):
      if debug: print("Found match: %s" % link['href'])
      files.add(link['href'])


  if debug: print("Have files %s" % (', '.join(files)))
  try:
    tmpdir = tempfile.mkdtemp(prefix='range_sync_http-')
    for f in files:
      with open(os.path.join(tmpdir, f), 'w') as fh:
        req_file = None
        if url.endswith('/'):
          req_file = requests.get(url + f)
        else:
          req_file = requests.get(url + '/' + f)
        fh.write(req_file.content)

    return local_sync.sync({'dir': tmpdir})
  finally:
    if tmpdir and os.path.exists(tmpdir):
      if debug:
        print("Look in %s" % tmpdir)
      else:
        shutil.rmtree(tmpdir)

if __name__ == '__main__':
  args = {
      'url': 'http://admin.example.com/yum/example/prod/6/x86_64/',
      'filter': r'^salt.*\.rpm$'
  }
  sync(args, debug=True)
