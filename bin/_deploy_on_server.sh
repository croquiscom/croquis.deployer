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
# croquis.deployer는 deployer 모듈로 설치되므로 app 모듈에서는 제외한다.
# (두개가 있으면 forever가 server 프로세스를 다른 스크립트로 인식할 가능성이 있다)
rsync --exclude=croquis.deployer -az . $ROOT/$TARGET

echo !- Installing deployer node modules
cd $ROOT
cat <<EOF > package.json
{
  "dependencies": {
    "coffee-script": "^1.10.0",
    "@croquiscom/croquis.deployer": "^0.7.5",
    "forever": "^0.15.2",
    "js-yaml": "^3.6.1"
  }
}
EOF
npm install

echo !- Make live link
rm -f $CURRENT
ln -s $TARGET $CURRENT

echo !- Install logrotate
cat <<EOF > $CURRENT/logrotate.conf
$HOME/.croquis/$PROJECT_NAME.log {
    daily
    rotate 7
    missingok
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        $HOME/.nvm/nvm-exec cake logrotate
    endscript
}
EOF

echo !- Run server
export PROJECT_ROOT=$ROOT/$CURRENT
./node_modules/@croquiscom/croquis.deployer/bin/start

echo !- Install Cron jobs
./node_modules/.bin/coffee ./node_modules/@croquiscom/croquis.deployer/bin/install_cron_jobs.coffee
