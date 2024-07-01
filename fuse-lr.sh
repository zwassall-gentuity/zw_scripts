#!/bin/bash

magick --version && echo && mkdir -p $1 && ls | sed -E 's/_.*//' | sort -u | xargs -ixxx -n1 -P8 -t magick montage xxx_* -geometry +0+0 $1/xxx.png
