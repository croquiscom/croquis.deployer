#!/bin/bash
SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`
ROOT_DIR=`cd $(dirname $(readlink -f "$SELF")) && cd ../.. && pwd`
$HOME/.nvm/nvm-exec $ROOT_DIR/node_modules/.bin/croquis_start
