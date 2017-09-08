#!/bin/bash

SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`

export NODE_ENV=production

nice -n 15 $HOME/.nvm/nvm-exec node -r coffee-script/register -r ts-node/register ./app/jobs/$1
