#!/bin/bash
PROJECT_NAME=$1
REF=$2
ROOT=~/running/$PROJECT_NAME
DATE=`date +'%F,%R'`
TARGET=versions/$DATE,$REF
CURRENT=current

SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`

echo !- Installing project node modules
npm install --production

echo !- Clean copy of repositories to $ROOT/$TARGET
mkdir -p $ROOT/$TARGET
rsync -az . $ROOT/$TARGET

echo !- Installing deployer node modules
cd $ROOT
cat <<EOF > package.json
{
  "dependencies": {
    "coffee-script": "~1.7.1",
    "croquis.deployer": "git+https://github.com/croquiscom/croquis.deployer.git",
    "forever": "~0.11.0",
    "js-yaml": "~3.0.2"
  }
}
EOF
npm install

echo !- Make live link
rm -f $CURRENT
ln -s $TARGET $CURRENT
cd $CURRENT

echo !- Compile CoffeeScripts
$ROOT/node_modules/.bin/coffee -c app
$ROOT/node_modules/.bin/coffee -c config

echo !- Run server
export PROJECT_ROOT=$ROOT/$CURRENT
$DEPLOYER_ROOT/bin/start

echo !- Build documentation
cake doc > /dev/null &
