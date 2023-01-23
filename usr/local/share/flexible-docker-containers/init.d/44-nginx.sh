#!/bin/bash
# Copyright (c) 2022-2023, AllWorldIT.
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to
# deal in the Software without restriction, including without limitation the
# rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
# sell copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
# FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
# IN THE SOFTWARE.


fdc_notice "Setting up Nginx permissions"

# Create nginx run directory
if [ ! -d /run/nginx ]; then
	mkdir /run/nginx
fi

# Make sure our cache directory exists with the right permissions
if [ ! -d /var/lib/nginx/cache ]; then
	mkdir /var/lib/nginx/cache
fi
chown nginx:nginx /var/lib/nginx/cache
chmod 0750 /var/lib/nginx/cache


fdc_notice "Initializing Nginx settings"

# Set the client max body size and default to 64m
if [ -n "$NGINX_CLIENT_MAX_BODY_SIZE" ]; then
	sed -i -e "s/client_max_body_size 64m;/client_max_body_size $NGINX_CLIENT_MAX_BODY_SIZE;/" /etc/nginx/nginx.conf
fi


# Check if we're enabling Brotli compression
if [ -z "$NGINX_ENABLE_BROTLI" ]; then
	sed -i -e 's/brotli off;/brotli on;/' /etc/nginx/http.d/20_fdc_brotli.conf
fi

# Check if we're enabling Gzip compression
if [ -z "$NGINX_ENABLE_GZIP" ]; then
	sed -i -e 's/gzip off;/gzip on;/' /etc/nginx/http.d/20_fdc_gzip.conf
fi

# Check if we're adding in the real IP of requests so we can properly report the client IP
if [ -n "$NGINX_SET_REAL_IP_FROM" ]; then
	while read -r i; do
		# Skip lines which are only whitespaces
		[ -z "${i/ /}" ] && continue
		# Add 'set_real_ip_from' after 'server_name'
		echo "set_real_ip_from $i;" >> /etc/nginx/http.d/20_fdc_set_real_ip_from.conf
	done <<< "$NGINX_SET_REAL_IP_FROM"
fi

# Check if we have a healthcheck URI
if [ -z "$NGINX_HEALTHCHECK_URI" ]; then
	export NGINX_HEALTHCHECK_URI="http://localhost"
fi



# If we have any SSL configuration we need to generate the Diffie-Hellman parameters for EDH ciphers
if grep -r ssl_certificate /etc/nginx/http.d; then
	openssl dhparam -out /etc/ssl/nginx/dh2048.pem 2048
fi
