#How to build

Install and update setuptools and wheel
- python3 -m pip install --upgrade setuptools wheel

Run setup.py to build the package
- python3 setup.py sdist bdist_wheel

dist/ contains the package as a built distribution and tar.gz
at least for testing I'm installing the .whl file directly with pip
- python3 -m pip install ./dist/seco_range-2.0-py3-none-any.whl

You may need to move the whl file somewhere else to make pip realize its not already installed
