#!/bin/sh
# Substitute only our two vars — leaves nginx's own $host, $remote_addr, etc. untouched
envsubst '$CALC_API_HOST $HISTORY_API_HOST' \
  < /etc/nginx/conf.d/default.conf.template \
  > /etc/nginx/conf.d/default.conf
exec nginx -g 'daemon off;'
