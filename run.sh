#!/bin/bash

set -e

cd src
beebasm -v -i main.asm -do jumbo.ssd -opt 3
#/Applications/b2\ Debug.app/Contents/MacOS/b2 -b -0 jumbo.ssd

python /Users/jayray/Acorn/tom-seddon/beeb/bin/ssd_extract.py jumbo.ssd
rm -rf /Users/jayray/Acorn/beeblink-server/volumes/jumbo
mv jumbo /Users/jayray/Acorn/beeblink-server/volumes
