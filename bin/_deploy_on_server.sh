#!/bin/bash
PROJECT_NAME=$1
REF=$2
ROOT=~/running
VERSIONS=.versions
DATE=`date +'%F,%R'`
TARGET=$VERSIONS/$DATE,$REF

SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`

echo !- Installing node modules
npm install --production

echo !- Clean copy of repositories to $ROOT/$TARGET
mkdir -p $ROOT/$TARGET
rsync -az . $ROOT/$TARGET

echo !- Make live link
cd $ROOT
rm -f $PROJECT_NAME
ln -s $TARGET $PROJECT_NAME
cd $PROJECT_NAME

echo !- Compile CoffeeScripts
./node_modules/.bin/coffee -c app
./node_modules/.bin/coffee -c config

echo !- Run server
./node_modules/.bin/croquis_start

echo !- Build documentation
cake doc > /dev/null &
