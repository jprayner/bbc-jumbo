#!/bin/bash
set -e

cd src
beebasm -v -i main.asm -do jumbo.ssd -opt 3
