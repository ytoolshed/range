"""
Various core functions for dealing with merging and normalizing data that will
be added to range
"""
# Core
import time

def sync(config):
  """
  Add a version cluster that contains the last update time and an svn rev of the
  zipped in files
  """
  now = int(time.time())
  clusters = {'version': {'CLUSTER': now, 'UPDATE': now}}

  return clusters
