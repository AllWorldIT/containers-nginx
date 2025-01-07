#!/bin/bash
# Copyright (c) 2022-2025, AllWorldIT.
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

function join_by {
	local d=${1-} f=${2-}
	if shift 2; then
		printf %s "$f" "${@/#/$d}"
	fi
}


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


NGINX_HTTP_REDIRECT_CODE=${NGINX_HTTP_REDIRECT_CODE:-302}
# shellcheck disable=SC2016
NGINX_HTTP_REDIRECT_TARGET=${NGINX_HTTP_REDIRECT_TARGET:-'https://$host$request_uri'}

# If we don't have a default config, we need to sort one out
if [ ! -e /etc/nginx/http.d/50_vhost_default.conf ]; then

	# Set default to redirect HTTP to HTTPS if we're using Certbot
	if [ -n "$CERTBOT_DOMAINS" ]; then
		NGINX_HTTP_REDIRECT_HTTPS=${NGINX_HTTP_REDIRECT_HTTPS:-'^(::ffff:127|::1$)'}
	fi

	# Copy the HTTP config file
	cp /etc/nginx/http.d/50_vhost_default.conf.template /etc/nginx/http.d/50_vhost_default.conf

	# Check if we're redirecting to HTTPS
	if [ -n "$NGINX_HTTP_REDIRECT_HTTPS" ]; then
		fdc_notice "Redirecting HTTP to HTTPS"

		# Create temporary file with our block of config
		tmpfile=$(mktemp /tmp/44-nginx-init.XXXXXX)
		cat <<EOF > "$tmpfile"
	if (\$remote_addr !~ "$NGINX_HTTP_REDIRECT_HTTPS") {
		return @NGINX_HTTP_REDIRECT_CODE@ @NGINX_HTTP_REDIRECT_TARGET@;
	}
EOF
		# Inject file at the REDIRECT TAG
		sed -i -e "/@NGINX_HTTP_REDIRECT@/r $tmpfile" /etc/nginx/http.d/50_vhost_default.conf
		# Remove temp file
		rm "$tmpfile"

		sed -i -E \
			-e "s/@NGINX_HTTP_REDIRECT_CODE@/$NGINX_HTTP_REDIRECT_CODE/" \
			-e "s,@NGINX_HTTP_REDIRECT_TARGET@,$NGINX_HTTP_REDIRECT_TARGET," \
			/etc/nginx/http.d/50_vhost_default.conf
	fi

	# Remove redirect tag
	sed -i -e "/@NGINX_HTTP_REDIRECT@/d" /etc/nginx/http.d/50_vhost_default.conf
fi


#
# Step 1 - Check if we're going to create the SSL config file
#

if [ -n "$CERTBOT_DOMAINS" ]; then
	fdc_info "Enabling LetsEncrypt"

	# Make sure our lib directory exists with the right permissions
	if [ ! -d /var/lib/letsencrypt ]; then
		mkdir /var/lib/letsencrypt
	fi
	chown root:root /var/lib/letsencrypt
	chmod 0755 /var/lib/letsencrypt

	# Make sure the email addy is set
	if [ -z "$CERTBOT_EMAIL" ]; then
		fdc_error "Certbot 'CERTBOT_DOMAINS' was specified without 'CERTBOT_EMAIL'"
		false
	fi

	cert_common_name=""
	cert_san_names=()

	cp /etc/nginx/http.d/55_vhost_default-ssl-certbot.conf.template /etc/nginx/http.d/55_vhost_default-ssl.conf.dummy
	cp /etc/nginx/http.d/55_vhost_default-ssl-certbot.conf.template /etc/nginx/http.d/55_vhost_default-ssl.conf.new
	for server_name in $(echo "$CERTBOT_DOMAINS" | tr "," " "); do
		# Check if we're adding the first cert name or if we're adding additional SAN names
		if [ -z "$cert_common_name" ]; then
			cert_common_name="$server_name"
		else
			cert_san_names+=("DNS:$server_name")
		fi
		# Set certbot cert name to the first name encountered
		CERTBOT_CERT_NAME=${CERTBOT_CERT_NAME:-$server_name}

		# Add server names
		sed -i -E \
			-e "s/^(\tserver_name @SERVER_NAME@;)/\tserver_name $server_name;\n\1/" \
			-e "s/@CERTBOT_CERT_NAME@/$CERTBOT_CERT_NAME/" \
			/etc/nginx/http.d/55_vhost_default-ssl.conf.new

		# Add server names
		sed -i -E \
			-e "s/^(\tserver_name @SERVER_NAME@;)/\tserver_name $server_name;\n\1/" \
			-e "s,/live/@CERTBOT_CERT_NAME@,/dummy/$CERTBOT_CERT_NAME," \
			/etc/nginx/http.d/55_vhost_default-ssl.conf.dummy
	done

	# Remove template lines
	sed -i -E \
		-e "/server_name @SERVER_NAME@;/d" \
		/etc/nginx/http.d/55_vhost_default-ssl.conf.new \
		/etc/nginx/http.d/55_vhost_default-ssl.conf.dummy

	#
	# Step 2 - Check if we can activate SSL right now
	#

	if [ ! -e "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/fullchain.pem" ] || \
			[ ! -e "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/privkey.pem" ]; then

		fdc_info "Generating dummy self-signed fallback SSL certificate"

		# Make sure dummy cert dirs exists
		if [ ! -d "/etc/letsencrypt/dummy" ]; then
			mkdir -p /etc/letsencrypt/dummy
			chmod 0700 /etc/letsencrypt/dummy
		fi
		if [ ! -d "/etc/letsencrypt/dummy/$CERTBOT_CERT_NAME" ]; then
			mkdir "/etc/letsencrypt/dummy/$CERTBOT_CERT_NAME"
		fi

		# Create self-signed certificate
		openssl_args=()
		if [ "${#cert_san_names[@]}" -gt 0 ]; then
			san_names=$(join_by , "${cert_san_names[@]}")
			openssl_args+=("-addext" "subjectAltName = $san_names")
		fi
		openssl req -new -x509 -days 365 -nodes \
			-out "/etc/letsencrypt/dummy/$CERTBOT_CERT_NAME/fullchain.pem" \
			-keyout "/etc/letsencrypt/dummy/$CERTBOT_CERT_NAME/privkey.pem" \
			-subj "/CN=$cert_common_name" \
			"${openssl_args[@]}"

		# Try issue the certificate
		fdc_notice "Using Certbot to issue initial certificate for '$CERTBOT_DOMAINS'"
		if ! certbot --standalone \
				certonly \
				--agree-tos --keep --non-interactive  \
				--email "${CERTBOT_EMAIL}" --no-eff-email \
				--cert-name "${CERTBOT_CERT_NAME}" \
				--renew-with-new-domains \
				--debug \
				-d "$CERTBOT_DOMAINS"; then
			fdc_error "Failed to issue certificate for '$CERTBOT_DOMAINS', ignoring and continuing with self-signed certificate"
		fi

	# Cert exists, try renew it just to make sure its valid
	else
		run_certbot="no"

		# Check the domains match
		if [ -e /var/lib/letsencrypt/fdc_domains ]; then
			domain_list_current=$(cat /var/lib/letsencrypt/fdc_domains)
			if [ "$domain_list_current" != "$CERTBOT_DOMAINS" ]; then
				run_certbot=yes
			fi
		else
			run_certbot=yes
		fi
		# Next check the last time we did a renew
		if [ -e /var/lib/letsencrypt/fdc_lastcheck ]; then
			le_last_check=$(cat /var/lib/letsencrypt/fdc_lastcheck)
			now=$(date +%s)
			if [ "$((now - le_last_check))" -gt "$((86400 * 30))" ]; then
				run_certbot=yes
			fi
		else
			run_certbot=yes
		fi

		# Finally if we need to run certbot do it...
		if [ "$run_certbot" = "yes" ]; then
			# Try renew certificate to make sure it covers the correct set of domains and is up to date
			fdc_notice "Using Certbot to renewal certificate for '$CERTBOT_DOMAINS'"
			if ! certbot --standalone \
					certonly \
					--agree-tos --keep --non-interactive  \
					--email "${CERTBOT_EMAIL}" --no-eff-email \
					--cert-name "${CERTBOT_CERT_NAME}" \
					--renew-with-new-domains \
					--keep-until-expiring \
					--debug \
					-d "$CERTBOT_DOMAINS"; then
				fdc_error "Failed to renew certificate for '$CERTBOT_DOMAINS', ignoring and continuing with self-signed certificate"
			fi
			# Save domain list and current timestamp
			echo "$CERTBOT_DOMAINS" > /var/lib/letsencrypt/fdc_domains
			date +%s > /var/lib/letsencrypt/fdc_lastcheck
		fi
	fi

	#
	# Activate SSL config if the cert exists
	#
	if [ -e "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/fullchain.pem" ] && \
			[ -e "/etc/letsencrypt/live/$CERTBOT_CERT_NAME/privkey.pem" ]; then
		fdc_notice "Enabling production SSL certificate"
		cp /etc/nginx/http.d/55_vhost_default-ssl.conf.new /etc/nginx/http.d/55_vhost_default-ssl.conf
	else
		fdc_notice "No production SSL certificate, using dummy self-signed certificate"
		cp /etc/nginx/http.d/55_vhost_default-ssl.conf.dummy /etc/nginx/http.d/55_vhost_default-ssl.conf
	fi
fi


# If we have any SSL configuration we need to generate the Diffie-Hellman parameters for EDH ciphers
if [ -n "$(find /etc/nginx/http.d -name '*.conf' -print0 | xargs -0 grep ssl_certificate)" ]; then
	# Make sure our SSL directory exists
	if [ ! -d /etc/ssl/nginx ]; then
		mkdir /etc/ssl/nginx
	fi
	chmod 0700 /etc/ssl/nginx

	# Check if our dh2048.pem file exists, if not create it
	if [ ! -e /etc/ssl/nginx/dh2048.pem ]; then
		fdc_info "Generating '/etc/ssl/nginx/dh2048.pem'"
		openssl dhparam -out /etc/ssl/nginx/dh2048.pem 2048
	fi
	chmod 0640 /etc/ssl/nginx/dh2048.pem
	chown root:root /etc/ssl/nginx/dh2048.pem
fi


# Check if we have a healthcheck URI
if [ -z "$NGINX_HEALTHCHECK_URI" ]; then
	export NGINX_HEALTHCHECK_URI="http://localhost"
fi
