#!/bin/bash

SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`

export NODE_ENV=production

$HOME/.nvm/nvm-exec coffee ./app/jobs/$1.coffee
