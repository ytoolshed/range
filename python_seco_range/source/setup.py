#!/usr/bin/python
import setuptools

with open("README.md", 'r') as f:
    long_description = f.read()

setuptools.setup(
    name='python3-seco-range',
    version = '1.0.0',
    author='ytoolshed',
    description='A Python 3 version of the library to interact with Range from ytoolshed',
    long_description=long_description,
    url='https://github.com/xadrnd/range/tree/master/python_seco_range/source',
    packages = setuptools.find_packages(),
    classifiers=[
        "Programming Language :: Python :: 3",
        "Development Status :: 4 - Beta",
        "License :: OSI Approved :: BSD License",
        "Operating System :: OS Independent"
    ],
    python_requires='>=3.6'
)
