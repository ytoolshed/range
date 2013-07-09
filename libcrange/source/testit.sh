#!/bin/sh

cd t
for i in *.t; do ./$i; done
