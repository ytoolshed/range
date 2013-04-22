"""
Pull down pre-built range files from subversion
"""
import tempfile
import os
import shutil

import pysvn


def sync(args):
  """
  Sync pre-built range files from a subversion repository.

  Args:
    repo: the subversion URL to a directory full of files
  """
  # Import inside the sync module to avoid circular imports
  import seco.range.sync.local as local_sync

  svn_url = args['repo']

  tmpdir = None
  try:
    tmpdir = tempfile.mkdtemp(prefix='range_sync_svn-')
    svn_client = pysvn.Client()
    head = pysvn.Revision(pysvn.opt_revision_kind.head)
    svn_client.export(svn_url, tmpdir, force=True, revision=head, native_eol=None)

    args = { 'dir': tmpdir }

    # Now read all the data in and return it
    return local_sync.sync(args)
  finally:
    if tmpdir and os.path.exists(tmpdir):
      shutil.rmtree(tmpdir)
