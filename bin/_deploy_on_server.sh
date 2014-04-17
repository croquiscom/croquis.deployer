#!/bin/bash
PROJECT_NAME=$1
REF=$2
ROOT=~/running
VERSIONS=.versions
DATE=`date +'%F,%R'`
TARGET=$VERSIONS/$DATE,$REF

SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`

echo !- Installing project node modules
npm install --production
npm uninstall coffee-script

echo !- Clean copy of repositories to $ROOT/$TARGET
mkdir -p $ROOT/$TARGET
rsync -az . $ROOT/$TARGET

echo !- Installing deployer node modules
cd $ROOT
npm install coffee-script forever
npm install git+https://github.com/croquiscom/croquis.deployer.git

echo !- Make live link
rm -f $PROJECT_NAME
ln -s $TARGET $PROJECT_NAME
cd $PROJECT_NAME

echo !- Compile CoffeeScripts
$ROOT/node_modules/.bin/coffee -c app
$ROOT/node_modules/.bin/coffee -c config

echo !- Run server
$ROOT/node_modules/.bin/croquis_start

echo !- Build documentation
cake doc > /dev/null &
