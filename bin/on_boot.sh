#!/bin/bash

SELF="${BASH_SOURCE[0]}"
cd `dirname "$SELF"`

$HOME/.nvm/nvm-exec cake start
