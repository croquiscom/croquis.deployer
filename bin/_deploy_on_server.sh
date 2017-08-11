#!/bin/bash
COLOR_RED='\033[0;31m'
COLOR_BLUE='\033[0;34m'
COLOR_MAGENTA='\033[0;35m'
COLOR_RESET='\033[0m'

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

echo -e ${COLOR_BLUE}!- Installing project node modules${COLOR_RESET}
npm prune --production
npm install --production

echo -e ${COLOR_BLUE}!- Clean copy of repositories to ${COLOR_MAGENTA}$ROOT/$TARGET${COLOR_RESET}
mkdir -p $ROOT/$TARGET
# croquis.deployer는 deployer 모듈로 설치되므로 app 모듈에서는 제외한다.
# (두개가 있으면 forever가 server 프로세스를 다른 스크립트로 인식할 가능성이 있다)
rsync --exclude=croquis.deployer -az . $ROOT/$TARGET

echo -e ${COLOR_BLUE}!- Installing deployer node modules${COLOR_RESET}
cd $ROOT
cat <<EOF > package.json
{
  "dependencies": {
    "coffee-script": "^1.12.7",
    "@croquiscom/croquis.deployer": "0.8.5",
    "forever": "^0.15.3",
    "js-yaml": "^3.9.0"
  }
}
EOF
npm --loglevel=error install

echo -e ${COLOR_BLUE}!- Make live link${COLOR_RESET}
rm -f $CURRENT
ln -s $TARGET $CURRENT

echo -e ${COLOR_BLUE}!- Install logrotate${COLOR_RESET}
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

echo -e ${COLOR_BLUE}!- Run server${COLOR_RESET}
export PROJECT_ROOT=$ROOT/$CURRENT
./node_modules/@croquiscom/croquis.deployer/bin/start || echo -e ${COLOR_RED}'(((***** FAIL TO START *****)))'${COLOR_RESET}

echo -e ${COLOR_BLUE}!- Install Cron jobs${COLOR_RESET}
./node_modules/.bin/coffee ./node_modules/@croquiscom/croquis.deployer/bin/install_cron_jobs.coffee
