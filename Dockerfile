FROM golang:1.15 AS builder
WORKDIR /src
RUN echo 'module caddy' > go.mod && \
    echo 'require github.com/caddyserver/caddy/v2 v2.3.0' >> go.mod && \
    echo 'require github.com/caddy-dns/cloudflare eda8e5aa' >> go.mod && \
    echo 'require github.com/mholt/caddy-webdav c949b322' >> go.mod
RUN echo 'package main' > caddy.go && \
    echo 'import caddycmd "github.com/caddyserver/caddy/v2/cmd"' >> caddy.go && \
    echo 'import _ "github.com/caddyserver/caddy/v2/modules/standard"' >> caddy.go && \
    echo 'import _ "github.com/mholt/caddy-webdav"' >> caddy.go && \
    echo 'import _ "github.com/caddy-dns/cloudflare"' >> caddy.go && \
    echo 'func main() { caddycmd.Main() }' >> caddy.go
RUN go env -w GOPROXY="https://goproxy.io,direct" && \
    CGO_ENABLED=0 go build -trimpath -tags netgo -ldflags '-extldflags "-static" -s -w' -o /usr/bin/caddy .



FROM alpine:3.13

LABEL maintainer "jinlife <glucose1e@tom.com>"
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
RUN chmod +x /usr/bin/caddy && /usr/bin/caddy version

ARG MKCERT_VERSION="1.4.3"
# Download mkcert to generate selfsigned cert, for SSL 443 usage. Won't run unless define DOMAIN and no EMAIL.
RUN wget -O /usr/local/bin/mkcert https://github.com/FiloSottile/mkcert/releases/download/v${MKCERT_VERSION}/mkcert-v${MKCERT_VERSION}-linux-amd64
RUN chmod +x /usr/local/bin/mkcert

# set up nsswitch.conf for Go's "netgo" implementation
# see: https://github.com/docker-library/golang/blob/1eb096131592bcbc90aa3b97471811c798a93573/1.14/alpine3.12/Dockerfile#L9
RUN [ ! -e /etc/nsswitch.conf ] && echo 'hosts: files dns' > /etc/nsswitch.conf

COPY Caddyfile /etc/Caddyfile

WORKDIR /opt
COPY entrypoint.sh /bin/entrypoint.sh
RUN chmod +x /bin/entrypoint.sh

# grab su-exec for easy step-down from root
RUN set -ex \
	&& addgroup -S -g 99 caddyuser \
	&& adduser -S -D -H -s /sbin/nologin -u 99 -G caddyuser caddyuser \
	&& apk add --update --no-cache ca-certificates su-exec libcap tzdata \
	&& setcap CAP_NET_BIND_SERVICE=+ep /usr/bin/caddy \
	&& mkdir -p /etc/caddy/acme \
	&& mkdir -p /etc/caddy/ocsp \
	&& chmod +x /etc/caddy \
	&& mkdir -p /home/caddyuser \
	&& mkdir -p /media \
	&& rm -rf /var/cache/apk/*

VOLUME /media

ENV TZ Asia/Shanghai

# Initial Password hash is 123123, after docker started, can open docker ssh and input command "caddy hash-password --algorithm bcrypt" to generate your custom password hash
ENV DOMAIN= \
    EMAIL= \
    TOKEN_KEY= \
    USERNAME=jinlife \
    PASSWORD=JDJhJDE0JGlsd1UwLllCdDVJckxMdFNodGdJUk9kUzQzUTV3bEEvbUZGMzBITUNmWW5qYmJUMUJnMHZp \
    SCOPE=/media

EXPOSE 80 443 2019

ENTRYPOINT ["/bin/entrypoint.sh"]
