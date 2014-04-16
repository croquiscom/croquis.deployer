#!/bin/bash
CONFIG=deploy.yaml

# from http://stackoverflow.com/a/21189044/3239514
function parse_yaml {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'", toupper(vn), toupper($2), $3);
      }
   }'
}

if [ ! -f "$CONFIG" ]; then
  echo $CONFIG not found
  exit 1
fi

eval $(parse_yaml $CONFIG "CONFIG_")

if [ -z "$CONFIG_SERVER" ]; then
  echo CONFIG server is empty
  exit 1
fi

if [ -z "$CONFIG_PROJECT" ]; then
  echo CONFIG project is empty
  exit 1
fi
