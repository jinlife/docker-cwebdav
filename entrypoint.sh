#!/bin/sh

if [[  "x$DOMAIN" != "x" &&  "x$EMAIL" != "x"  &&  "x$TOKEN_KEY" != "x"  ]]
then

cat > /etc/Caddyfile << EOF
{
	order webdav before file_server
}

$DOMAIN {
    tls $EMAIL {
		dns cloudflare $TOKEN_KEY
	}
	basicauth { # optional auth
		$USERNAME $PASSWORD
	}
    webdav {
		root $SCOPE
	}
}
EOF

elif [[  "x$DOMAIN" != "x"  ]]
then

SERVER_ALIAS="`printf 'localhost,127.0.0.1,::1,%s' "$DOMAIN" | tr ',' ' '`"
/usr/local/bin/mkcert -install
/usr/local/bin/mkcert -cert-file /etc/caddy/selfsigned.crt -key-file /etc/caddy/selfsigned.key $SERVER_ALIAS

chown caddyuser:caddyuser /etc/caddy/selfsigned.crt
chown caddyuser:caddyuser /etc/caddy/selfsigned.key

cat > /etc/Caddyfile << EOF
{
	order webdav before file_server
}

:443 {
    tls /etc/caddy/selfsigned.crt /etc/caddy/selfsigned.key
	basicauth { # optional auth
		$USERNAME $PASSWORD
	}
    webdav {
		root $SCOPE
	}
}
EOF

else

cat > /etc/Caddyfile << EOF
{
	order webdav before file_server
}
:80 {
	basicauth { # optional auth
		$USERNAME $PASSWORD
	}
    webdav {
		root $SCOPE
	}
}
EOF

fi

# Defaults to caddyuser:caddyuser (99:99).
chown caddyuser:caddyuser /media
chown caddyuser:caddyuser /etc/caddy
chown caddyuser:caddyuser /etc/caddy/acme
chown caddyuser:caddyuser /etc/caddy/ocsp
chown caddyuser:caddyuser /home/caddyuser
exec su-exec caddyuser /usr/bin/caddy run --config /etc/Caddyfile --adapter caddyfile
