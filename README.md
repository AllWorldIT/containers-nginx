# Introduction

This is a Nginx container base image.

Check the [Postfix Base Image](https://gitlab.iitsp.com/allworldit/docker/postfix/README.md) for more settings.

This image has a health check which checks `http://localhost` for a response.


# Configuration

## Nginx

By default Nginx is configured to service files from `/var/www/html` in `/etc/nginx/conf.d/default.conf`.

You can bind mount over `/etc/nginx/conf.d/default.conf` to change the default behavior.

Additional configuration can be bind mounted to `/etc/nginx/conf.d/NAME.conf`.

An example of the default configuration can be found below...
```
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

