#!/bin/sh

mkdir a b
cd a
ar x $1/libunix.a
cd ..
cd b
ar x $1/libasmrun.a
