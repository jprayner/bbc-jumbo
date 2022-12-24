#!/bin/sh

set -e

echo "Updating distro..."
apt-get update
apt install -y git build-essential

echo "==================="
echo "= Install BeebAsm ="
echo "==================="

echo "Cloning repo..."
git clone https://github.com/stardot/beebasm/

echo "Building..."
cd beebasm/src
make code

echo "Moving binary to /usr/local/bin..."
ls -l ../beebasm
cp ../beebasm /usr/local/bin

echo "Fininshed."
