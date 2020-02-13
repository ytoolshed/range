# How to build

Install and update setuptools and wheel

    python3 -m pip install --upgrade setuptools wheel

Run setup.py to build the package

    python3 setup.py sdist bdist_wheel

dist/ contains the package as a built distribution and tar.gz

    python3 -m twine upload dist/*

# Usage

    import seco.range

