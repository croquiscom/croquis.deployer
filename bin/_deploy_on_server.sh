#!/bin/bash
PROJECT_NAME=$1
REF=$2
ROOT=~/running/$PROJECT_NAME
DATE=`date +'%Y-%m-%d,%H-%M'`
TARGET=versions/$DATE,$REF
CURRENT=current

SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`

NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

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
    "coffee-script": "^1.10.0",
    "@croquiscom/croquis.deployer": "^0.5.3",
    "forever": "^0.15.1",
    "js-yaml": "^3.4.2"
  }
}
EOF
npm install

echo !- Make live link
rm -f $CURRENT
ln -s $TARGET $CURRENT

echo !- Run server
export PROJECT_ROOT=$ROOT/$CURRENT
./node_modules/@croquiscom/croquis.deployer/bin/start

echo !- Install Cron jobs
./node_modules/.bin/coffee ./node_modules/@croquiscom/croquis.deployer/bin/install_cron_jobs.coffee
