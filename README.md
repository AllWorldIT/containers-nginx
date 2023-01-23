[![pipeline status](https://gitlab.conarx.tech/containers/nginx/badges/main/pipeline.svg)](https://gitlab.conarx.tech/containers/nginx/-/commits/main)

# Container Information

[Container Source](https://gitlab.conarx.tech/containers/nginx) - [GitHub Mirror](https://github.com/AllWorldIT/containers-nginx)

This is the Conarx Containers Nginx image, it provides the Nginx webserver for serving basic static content. It can be used
standalone for a basic webserver or as a base image.

Generally apps running on webservers require some way to send email, this is why this image is based on the [Conarx Containers
Postfix image](https://gitlab.conarx.tech/containers/postfix). Email support is only enabled when the relevant environment variable
configuration is present.

Additional Nginx modules included:

- mod-http-brotli
- mod-http-cache-purge
- mod-http-fancyindex



# Mirrors

|  Provider  |  Repository                           |
|------------|---------------------------------------|
| DockerHub  | allworldit/nginx                      |
| Conarx     | registry.conarx.tech/containers/nginx |



# Conarx Containers

All our Docker images are part of our Conarx Containers product line. Images are generally based on Alpine Linux and track the
Alpine Linux major and minor version in the format of `vXX.YY`.

Images built from source track both the Alpine Linux major and minor versions in addition to the main software component being
built in the format of `vXX.YY-AA.BB`, where `AA.BB` is the main software component version.

Our images are built using our Flexible Docker Containers framework which includes the below features...

- Flexible container initialization and startup
- Integrated unit testing
- Advanced multi-service health checks
- Native IPv6 support for all containers
- Debugging options



# Community Support

Please use the project [Issue Tracker](https://gitlab.conarx.tech/containers/nginx/-/issues).



# Commercial Support

Commercial support for all our Docker images is available from [Conarx](https://conarx.tech).

We also provide consulting services to create and maintain Docker images to meet your exact needs.



# Environment Variables

Additional environment variables are available from...
* [Conarx Containers Postfix image](https://gitlab.conarx.tech/containers/postfix)
* [Conarx Containers Alpine image](https://gitlab.conarx.tech/containers/alpine).


## NGINX_CLIENT_MAX_BODY_SIZE

Maximum client request body size, defaults to `64m`.


## NGINX_ENABLE_BROTLI

Enable Brotli compressed responses, this is generally only enabled for reverse proxies or if the Docker container is exposed
directly to the internet without a revserse proxy.

This is safe to enable in conjunction with Gzip compression below.


## NGINX_ENABLE_GZIP

Enable Gzip compressed responses, this is generally only enabled for reverse proxies or if the Docker container is exposed
directly to the internet without a revserse proxy.


## NGINX_SET_REAL_IP_FROM

This can be a multi-line configuration option containing one IP address or IP address range per line which will result in the
generation of Nginx configuration lines in the format of `set_real_ip_from xxxxx;`.


## NGINX_HEALTHCHECK_URI

Defaults to "http://localhost", it must be IPv4 and IPv6 compatible, the `User-Agent` header in health checks is set to
`Health Check`.



# Volumes


## /var/www/html

Document root.


## /var/lib/nginx/cache

A volume can be mount to this location if using reverse proxying to have a persistent cache.


## /etc/ssl/nginx

Diffie-Huffman parameters are written to this directory if SSL is used.



# Exposed Ports

Postfix port 25 is exposed by the [Conarx Containers Postfix image](https://gitlab.conarx.tech/containers/postfix) layer.

Nginx port 80 is exposed.



# Configuration

Configuration files of note can be found below...

| Path                                           | Description                                        |
|------------------------------------------------|----------------------------------------------------|
| /etc/nginx/http.d/20_fdc_brotli.conf           | Brotli configuration                               |
| /etc/nginx/http.d/20_fdc_gzip.conf             | Gzip configuration                                 |
| /etc/nginx/http.d/20_fdc_logging.conf          | Logging configuration                              |
| /etc/nginx/http.d/20_fdc_proxy_buffering.conf  | Proxy buffering configuration, for reverse proxies |
| /etc/nginx/http.d/20_fdc_proxy_cache.conf      | Proxy caching configuration, for reverse proxies   |
| /etc/nginx/http.d/20_fdc_set_real_ip_from.conf | Configuration created from $NGINX_SET_REAL_IP_FROM |
| /etc/nginx/http.d/20_fdc_ssl.conf              | SSL configuration                                  |
| /etc/nginx/http-extra.d/                       | Mountable volume for specifying multiple configs   |


## Virtual hosts

Virtual host files can be configured in the `/etc/nginx/http.d`, the default virtual host configured is
`localhost` in `/etc/nginx/http.d/50_vhost_default.conf`.

There is also a directory that can be mounted instead of single virtual host configuration files, this is generally used when
cert-bot is required to issue SSL certificates and creates additional configuration files which would not normally persist. For
this purpose `/etc/nginx/http-extra.d` is available.


An example of the default vhost configuration can be found below...

```nginx
server {
	listen 80;
	server_name localhost;
	set_real_ip_from 172.16.0.0/12;

	root /var/www/html;

	location = /favicon.ico {
		log_not_found off;
		access_log off;
	}

	location = /robots.txt {
		allow all;
		log_not_found off;
		access_log off;
	}

	location ~* \.(js|css|gif|ico|jpg|jpeg|png)$ {
		expires max;
	}
}
```



# SSL Configuration

SSL can be used in virtual hosts, on a side note to this, Diffie-Huffman paramters will be generated on container startup.

Diffie-Huffman parameters can be persisted by using a volume mount on `/etc/ssl/nginx`, see below.

