"""
Various core functions for dealing with merging and normalizing data that will
be added to range
"""
# Core

# 3rd party

# Local
import seco.range

def sync(config):
  range_server = config.get('range_server', 'localhost:80')
  range = seco.range.Range(range_server)
  rev_index = {}
  for cluster in range.expand("allclusters()"):
    values = None
    try:
      values = range.expand("%" + cluster)
    except seco.range.RangeException:
      print("Could not lookup up {0}".format(cluster))
    if values:
      for v in values:
        #print "Adding {0} to {1}".format(cluster, v)
        if v in rev_index:
          rev_index[v].add(cluster)
        else:
          rev_index[v] = set([cluster,])
  return {'index': rev_index}
