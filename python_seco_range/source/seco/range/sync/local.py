"""
Function dealing with locally syncing range data
"""

import os
import re
import sys

# 3rd party
import yaml

def sync(args):
  """
  Sync in files from a local directory on a range server, mostly used for
  debug and testing purposes when called directly.  Also used for reading 
  the data out of svn pull downs

  Args:
    dir: The local directory to sync in
  """
  local_dir = args['dir']
  range_data = {}
  yaml_re = re.compile('(.*)\.yaml$')
  if os.path.isdir(local_dir):
    for rfile in os.listdir(local_dir):
      match = yaml_re.match(rfile)
      if match:
        cluster_name = match.group(1)
        try:
          range_data[cluster_name] = yaml.load(open(os.path.join(local_dir, rfile)))
        except (OSError, IOError) as e:
          sys.stderr.write("Could not read local file: %s\n" % e)

  return range_data
