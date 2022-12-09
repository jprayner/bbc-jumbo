#!/bin/bash

# Assumes jsbeeb running on port 8000
# Run following from jsbeeb dir:
#    pyenv shell 2
#    python -mSimpleHTTPServer
JSBEEB_DIR=/Users/jayray/Acorn/jsbeeb
JSBEEB_PORT=8000

# Don't forget to symlink beebasm to current dir
# i.e. ln -s $BEEBASM_DIR/beebasm
# To build, run `make code` in src dir of beebasm

set -e

#./beebasm -i main.asm -do jumbo.ssd -v
./beebasm -i main.asm -do jumbo.ssd -boot Code -v

/Applications/b2\ Debug.app/Contents/MacOS/b2 -b -0 jumbo.ssd
#/Applications/b2.app/Contents/MacOS/b2 -b -0 jumbo.ssd

# echo "Kicking off browser..."
# mv jumbo.ssd $JSBEEB_DIR/discs
# open "http://localhost:$JSBEEB_PORT/?disc1=jumbo.ssd&autoboot&model=Master"
# open "http://localhost:$JSBEEB_PORT/?disc1=jumbo.ssd&autoboot"

#exit 0

# python /Users/jayray/Acorn/tom-seddon/beeb/bin/ssd_extract.py jumbo.ssd
# rm -rf /Users/jayray/Acorn/beeblink-server/volumes/jumbo
# mv jumbo /Users/jayray/Acorn/beeblink-server/volumes

# echo "Starting beeblink server..."
# cd ~/Acorn/beeblink-server/
# ./beeblink-server --default-volume jumbo ./volumes
