"""
Pull down pre-built range files from git
"""
import tempfile
import os
import shutil

import git

def sync(args):
  """
  Sync pre-built range files from a git repository

  Args:
    repo: the git URL to a directory full of files
    dir: the directory under the cloned repository where the yaml files live
  """
  # Import inside the sync module to avoid circular imports
  import seco.range.sync.local as local_sync

  git_url = args['repo']
  git_dir = args['dir']

  tmpdir = None
  try:
    tmpdir = tempfile.mkdtemp(prefix='range_sync_git-')
    git_repo = git.Repo.clone_from(git_url, tmpdir)
    local_dir = os.path.join(tmpdir, git_dir)
    args = { 'dir': local_dir }

    # Now read all the data in and return it
    return local_sync.sync(args)
  finally:
    if tmpdir and os.path.exists(tmpdir):
      shutil.rmtree(tmpdir)
