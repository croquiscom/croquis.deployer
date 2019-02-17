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

NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"

echo -e ${COLOR_BLUE}!- Installing pm2${COLOR_RESET}
npm explore -g pm2 || npm install -g pm2
(cd ~ ; pm2 ping)

echo -e ${COLOR_BLUE}!- Installing project node modules${COLOR_RESET}
cd `dirname "$SELF"`
npm prune --production
npm install --production

echo -e ${COLOR_BLUE}!- Clean copy of repositories to ${COLOR_MAGENTA}$ROOT/$TARGET${COLOR_RESET}
mkdir -p $ROOT/$TARGET
rsync -az . $ROOT/$TARGET

echo -e ${COLOR_BLUE}!- Installing deployer node modules${COLOR_RESET}
cd $ROOT
cat <<EOF > package.json
{
  "dependencies": {
    "@croquiscom/croquis.deployer": "0.11.0-alpha.1",
    "js-yaml": "^3.12.1",
    "pm2": "^3.2.9"
  }
}
EOF
npm --loglevel=error install

echo -e ${COLOR_BLUE}!- Check server${COLOR_RESET}
export PROJECT_ROOT=$ROOT/$TARGET
./node_modules/@croquiscom/croquis.deployer/bin/check
if [ $? -ne 0 ]; then
  echo -e ${COLOR_RED}'(((***** FAIL TO START *****)))'${COLOR_RESET}
  exit 1
fi

echo -e ${COLOR_BLUE}!- Make live link${COLOR_RESET}
rm -f $CURRENT
ln -s $TARGET $CURRENT

echo -e ${COLOR_BLUE}!- Install logrotate${COLOR_RESET}
cat <<EOF > $HOME/running/logrotate.conf
$HOME/.croquis/*.log {
    daily
    maxsize 1G
    rotate 7
    missingok
    compress
    delaycompress
    notifempty
    sharedscripts
    postrotate
        pm2 reloadLogs
    endscript
}
EOF

echo -e ${COLOR_BLUE}!- Run server${COLOR_RESET}
export PROJECT_ROOT=$ROOT/$CURRENT
./node_modules/@croquiscom/croquis.deployer/bin/start

echo -e ${COLOR_BLUE}!- Install Cron jobs${COLOR_RESET}
node ./node_modules/@croquiscom/croquis.deployer/bin/install_cron_jobs

echo -e ${COLOR_BLUE}!- Remove old versions${COLOR_RESET}
CURRENT_VERSION=`readlink $CURRENT | awk -F / '{ print $2 }'`
cd $ROOT/versions
OLD_DATE=`date --date="14 day ago" +%Y-%m-%d`
for FILE in *; do
  FILE_DATE=${FILE:0:10}
  if [[ "$FILE_DATE" < "$OLD_DATE" ]]; then
    if [[ "$CURRENT_VERSION" = "$FILE" ]]; then
      echo Skip current - $FILE
    else
      echo Removing - $FILE
      rm -rf $FILE
    fi
  fi
done
