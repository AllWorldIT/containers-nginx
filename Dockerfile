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


FROM registry.conarx.tech/containers/postfix/3.17


ARG VERSION_INFO=
LABEL org.opencontainers.image.authors   = "Nigel Kukard <nkukard@conarx.tech>"
LABEL org.opencontainers.image.version   = "3.17"
LABEL org.opencontainers.image.base.name = "registry.conarx.tech/containers/postfix/3.17"


RUN set -eux; \
	true "Nginx"; \
	apk add --no-cache \
		nginx \
		nginx-mod-http-brotli \
		nginx-mod-http-cache-purge \
		nginx-mod-http-fancyindex \
		curl \
		openssl; \
	true "Users"; \
	adduser -u 82 -D -S -H -h /var/www/html -G www-data www-data; \
	true "Web root"; \
	mkdir -p /var/www/html; \
	chown www-data:www-data \
		/var/www/html; \
	chmod 0755 \
		/var/www/html; \
	true "Nginx"; \
	ln -sf /dev/stdout /var/log/nginx/access.log; \
	ln -sf /dev/stderr /var/log/nginx/error.log; \
	mkdir \
		/etc/nginx/conf.d \
		/etc/nginx/http-extra.d; \
	rm -f /etc/nginx/http.d/default.conf; \
	rm -rf /var/www/localhost; \
	true "Cleanup"; \
	rm -f /var/cache/apk/*


# Nginx
COPY etc/nginx/nginx.conf /etc/nginx/nginx.conf
COPY etc/nginx/http.d/20_fdc_brotli.conf /etc/nginx/http.d/
COPY etc/nginx/http.d/20_fdc_gzip.conf /etc/nginx/http.d/
COPY etc/nginx/http.d/20_fdc_logging.conf /etc/nginx/http.d/
COPY etc/nginx/http.d/20_fdc_proxy_buffering.conf /etc/nginx/http.d/
COPY etc/nginx/http.d/20_fdc_proxy_cache.conf /etc/nginx/http.d/
COPY etc/nginx/http.d/20_fdc_ssl.conf /etc/nginx/http.d/
COPY etc/nginx/http.d/50_vhost_default.conf /etc/nginx/http.d/
COPY etc/supervisor/conf.d/nginx.conf /etc/supervisor/conf.d/nginx.conf
COPY usr/local/share/flexible-docker-containers/init.d/44-nginx.sh /usr/local/share/flexible-docker-containers/init.d
COPY usr/local/share/flexible-docker-containers/pre-init-tests.d/44-nginx.sh /usr/local/share/flexible-docker-containers/pre-init-tests.d
COPY usr/local/share/flexible-docker-containers/tests.d/44-nginx.sh /usr/local/share/flexible-docker-containers/tests.d
COPY usr/local/share/flexible-docker-containers/healthcheck.d/44-nginx.sh /usr/local/share/flexible-docker-containers/healthcheck.d
RUN set -eux; \
	true "Flexible Docker Containers"; \
	if [ -n "$VERSION_INFO" ]; then echo "$VERSION_INFO" >> /.VERSION_INFO; fi; \
	true "Permissions"; \
	chown root:root \
		/etc/nginx/nginx.conf \
		/etc/nginx/http-extra.d \
		/etc/nginx/http.d/20_fdc_brotli.conf \
		/etc/nginx/http.d/20_fdc_gzip.conf \
		/etc/nginx/http.d/20_fdc_logging.conf \
		/etc/nginx/http.d/20_fdc_proxy_buffering.conf \
		/etc/nginx/http.d/20_fdc_proxy_cache.conf \
		/etc/nginx/http.d/20_fdc_ssl.conf \
		/etc/nginx/http.d/50_vhost_default.conf; \
	chmod 0755 \
		/etc/nginx/http-extra.d; \
	chmod 0644 \
		/etc/nginx/nginx.conf \
		/etc/nginx/http.d/20_fdc_brotli.conf \
		/etc/nginx/http.d/20_fdc_gzip.conf \
		/etc/nginx/http.d/20_fdc_logging.conf \
		/etc/nginx/http.d/20_fdc_proxy_buffering.conf \
		/etc/nginx/http.d/20_fdc_proxy_cache.conf \
		/etc/nginx/http.d/20_fdc_ssl.conf \
		/etc/nginx/http.d/50_vhost_default.conf; \
	fdc set-perms


VOLUME ["/var/www/html", "/var/lib/nginx/cache"]

EXPOSE 80
