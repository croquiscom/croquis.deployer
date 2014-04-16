#!/bin/bash
PROJECT_NAME=$1
REF=$2
TARGET=~/running
VERSIONS=.versions

SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`

echo !- Installing node modules
npm install --production
npm install forever

echo !- Clean copy of repositories to $TARGET/$VERSIONS/$REF
mkdir -p $TARGET/$VERSIONS
rsync -az . $TARGET/$VERSIONS/$REF

echo !- Make live link
cd $TARGET
rm -f $PROJECT_NAME
ln -s $VERSIONS/$REF $PROJECT_NAME
cd $PROJECT_NAME

echo !- Compile CoffeeScripts
./node_modules/.bin/coffee -c app
./node_modules/.bin/coffee -c config

echo !- Run server
./node_modules/.bin/croquis_start

echo !- Build documentation
cake doc > /dev/null &
