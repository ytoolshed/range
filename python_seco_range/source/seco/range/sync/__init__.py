"""
Various core functions for dealing with merging and normalizing data that will
be added to range
"""
# Core
import os
import logging
import re
import shutil
import tempfile
import time

# 3rd party
import yaml

# Local
import seco.range.sync.local
import seco.range.sync.svn
import seco.range.sync.git_sync
import seco.range.sync.http
import seco.range.sync.index
import seco.range.sync.version

log = logging.getLogger(__name__)

class RangeSyncError(Exception):
  """
  Base exception for things going wrong in the range syncers
  """
  pass

def range_data_merge(main_data, added_data):
  """
  Take main data and then use the added data to merge in and override existing
  keys
  """
  for cluster in main_data:
    if cluster in added_data:
      main_data[cluster].update(added_data[cluster])

  for cluster in added_data:
    if cluster not in main_data:
      main_data[cluster] = added_data[cluster]

  return main_data

def range_data_override(main_data, added_data):
  """
  Take main data and then use the added data to completely overwrite clusters and all
  keys in the clusters
  """
  # HULK SMAAAAASH!
  for cluster in added_data:
    main_data[cluster] = added_data[cluster]

  return main_data

def range_data_nomerge(main_data, added_data):
  """
  Take main data and then update clusters with the added data only if they do
  not already exist.  Return only the valid clusters (not full set)
  """
  ret_data = {}
  for cluster in added_data:
    if main_data.get(cluster) is None:
      ret_data[cluster] = added_data[cluster]

  return ret_data


def norm_key(key_name):
  """
  Normalize key names to not have spaces or semi-colons
  """
  if key_name:
    return re.sub('[;\s]', '_', key_name)
  return None

def norm_string(range_val):
  """
  Look at a range value and if it's got characters that make range parsing unhappy
  then put it in a q()
  """
  re_badchars = re.compile(r'[\s\/]')
  re_minus = re.compile(r'((\S)+ - (\S)+)+')
  re_quoted = re.compile(r'^q\(.*\)$')
  re_int_parens = re.compile(r'[\(\)]')
  re_l_paren = re.compile(r'\(')
  re_r_paren = re.compile(r'\)')

  # Escape internal parms, wrap in a q() if they exist
  if re_int_parens.search(range_val) and not re_quoted.match(range_val):
    range_val = re_l_paren.sub(r'\(', range_val)
    range_val = re_r_paren.sub(r'\)', range_val)
    range_val = 'q(%s)' % range_val

  # Look for spaces and slashes, if they exist, wrap in a q()
  if re_badchars.search(range_val) and not re_quoted.match(range_val):
    if not re_minus.match(range_val):
      range_val = 'q(%s)' % range_val

  return range_val

def norm_values(rangedata):
  """
  Function to iterate over our cluster keys and normalize sets into lists
  otherwise the yaml is not quite what we want
  """
  dumper = {}
  for k, v in rangedata.items():
    if isinstance(v, (set,list,tuple)):
      new_list = []
      for item in v:
        try:
          item = norm_string(item)
        except TypeError:
          # Sometimes we have integers/floats and they don't regex match very well
          # Just pass them in as-is
          pass
        new_list.append(item)
      dumper[k] = new_list
    else:
      try:
        v = norm_string(v)
      except TypeError:
        # Sometimes we have integers and other things that can't have spaces
        # Just pass them in as-is
        pass
      dumper[k] = v

  return dumper

def norm_file(filename):
  """
  Three os.path methods that actually normalize out path names
  """
  if filename:
    return os.path.realpath(os.path.abspath(os.path.expanduser(filename)))
  return None

def sync_range(src_dir, dest_dir, clean=True, protected=[]):
  """
  Iterate over your tmp directory full of range files, copy them into place,
  then remove the old stuff
  """
  src_files = None
  dest_files = None
  re_protected = [ re.compile(r) for r in protected ]
  if not os.path.exists(dest_dir):
    os.mkdir(dest_dir)
  if not os.path.isdir(dest_dir):
    raise RangeSyncError('Destination is not a directory: %s' % dest_dir)
  src_files = set([f for f in os.listdir(src_dir) if f.endswith('.yaml')])
  dest_files = set([f for f in os.listdir(dest_dir) if f.endswith('.yaml')])

  delete_after = dest_files.difference(src_files)

  for f in src_files:
    if not acopy(src_dir, f, dest_dir):
      log.warning('Could not copy {0} to {1}'.format(os.path.join(src_dir, f), dest_dir))

  if clean:
    for f in delete_after:
      if is_protected(f, re_protected):
        log.info("Skipping protected file {0}".format(f))
        continue
      else:
        log.warning("Deleting file {0}".format(f))
        os.remove(os.path.join(dest_dir, f))

def is_protected(file_name, regex_list):
  """
  Given a list of compiled regexes, verify if a filename matches and thus,
  is "protected" from being deleted
  """
  for regex in regex_list:
    if regex.search(file_name):
      return True
  # Fall through to false
  return False

def acopy(src_dir, src_file, dest_dir):
  '''
  Simple atomic copy
  '''
  source_path = os.path.join(src_dir, src_file)
  staging_path = os.path.join(dest_dir, ".{0}.rngsyn".format(src_file))
  dest_path = os.path.join(dest_dir, src_file)
  shutil.copy(source_path, staging_path)
  try:
    # This is an atomic operation when on the same filesystem
    os.rename(staging_path, dest_path)
    return True
  except OSError:
    return False
  finally:
    if os.path.exists(staging_path):
      os.remove(staging_path)

def outputter(clusters, outdir, output_type='yaml', clean=True, protected=[]):
  """
  Wrapper for range output, currently only support yaml output style
  """
  if output_type != 'yaml':
    raise NotImplementedError('Output types other than yaml not yet supported')
  elif not os.path.isdir(outdir):
    raise TypeError("{0} is not a directory".format(outdir))
  else:
    tmpdir = None
    try:
      tmpdir = tempfile.mkdtemp(prefix='range_sync_output-')
      for cluster in clusters:
        # Copy data into a dict. This is necessary so the yaml module
        # wil write out the correct thing.
        # Without it you get something like: (for an undefined CLUSTER)
        # !!python/object/apply:collections.defaultdict
        # - !!python/name:__builtin__.set ''
        dict_data = dict(clusters[cluster])
        write_range_file(cluster, dict_data, tmpdir)
      sync_range(tmpdir, outdir, clean, protected)
    finally:
      if tmpdir and os.path.exists(tmpdir):
        shutil.rmtree(tmpdir)

def write_range_file(cluster, output, outdir):
  """Write out a range file to the specified output directory"""
  if output:
    try:
      output = norm_values(output)
    except AttributeError as e:
      log.error("Failed to normalize {0}: {1}".format(output, e))
  else:
    log.info("No output: {0}".format(cluster))
    # It is debatable if this is the right solution; an empty file may be better.
    # But, create at least a "CLUSTER".
    output = norm_values(dict({'CLUSTER': ''}))
  with open(os.path.join(outdir, cluster + '.yaml'), 'w') as fh:
    yaml.dump(output, fh, default_flow_style=False, indent=4)

