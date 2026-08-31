# ipify

A minimal private IP echo image for the Saltbox facts service. It runs Nginx
as a non-root user and returns the client address supplied by a trusted reverse
proxy.

## Image

Docker Hub: saltydk/ipify

Supported platforms:

- linux/amd64
- linux/arm64

Published tags:

- latest: most recently tagged release
- `<git-tag>`: the Git tag verbatim
- dev: latest main-branch build
- `sha-<commit>`: a commit-addressed main-branch build

## HTTP API

The container listens on port 80.

### GET /

The response is the first value from X-Forwarded-For:

~~~text
192.0.2.10
~~~

The response status is 400 when the header is absent or empty. The image does
not validate the value as an IP address.

### GET /healthz

Returns 200 and:

~~~text
ok
~~~

Other paths return 404.

## Trust boundary

This image assumes that only a trusted reverse proxy such as Traefik can reach
it. X-Forwarded-For is accepted without authentication or proxy-CIDR
validation. Do not publish port 80 directly to untrusted clients.

## Example

~~~sh
docker run --rm \
  --publish 127.0.0.1:80:80 \
  saltydk/ipify:dev

curl \
  --header 'X-Forwarded-For: 192.0.2.10' \
  http://127.0.0.1/
~~~

Production deployments should attach the container to Traefik's Docker network
without publishing a host port.

The image supports a read-only root filesystem when /tmp is writable:

~~~sh
docker run --rm \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=16m \
  saltydk/ipify:dev
~~~

## Development

Build and run all checks:

~~~sh
make check
~~~

Build only:

~~~sh
make build
~~~
