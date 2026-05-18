#!/bin/sh
printf 'window.SLOT = "%s";\n' "${SLOT:-unknown}" > /usr/share/nginx/html/env.js
exec nginx -g 'daemon off;'
