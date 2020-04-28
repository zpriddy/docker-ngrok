#!/bin/sh -e

if [ -n "$@" ]; then
  exec "$@"
fi

# Legacy compatible:
if [ -z "$NGROK_PORT" ]; then
  if [ -n "$HTTPS_PORT" ]; then
    NGROK_PORT="$HTTPS_PORT"
  elif [ -n "$HTTPS_PORT" ]; then
    NGROK_PORT="$HTTP_PORT"
  elif [ -n "$APP_PORT" ]; then
    NGROK_PORT="$APP_PORT"
  fi
fi


ARGS="ngrok"

# Set the protocol.
if [ "$NGROK_PROTOCOL" = "TCP" ]; then
  ARGS="$ARGS tcp"
elif [ "$NGROK_PROTOCOL" = "TLS" ]; then
    ARGS="$ARGS tls "
    NGROK_PORT="${NGROK_PORT:-80}"
else
  ARGS="$ARGS http"
  NGROK_PORT="${NGROK_PORT:-80}"
fi

# Set the key and cert if passed in
if [ -n "$NGROK_CERT" ] && [ -n "$NGROK_KEY" ]; then
    ARGS="$ARGS -key=$NGROK_KEY -crt=$NGROK_CERT "
fi

# User lets encrypt cert and key if passed in
if [ -n "$URL" ] && [ -n "$LETS_ENCRYPT" ]; then
    if [ -f "$LETS_ENCRYPT/etc/letsencrypt/live/$URL/privkey.pem" ] && [ -f "$LETS_ENCRYPT/etc/letsencrypt/live/$URL/cert.pem" ]; then
        ARGS="$ARGS -key=$LETS_ENCRYPT/etc/letsencrypt/live/$URL/privkey.pem -crt=$LETS_ENCRYPT/etc/letsencrypt/live/$URL/cert.pem -hostname=$URL "
    else
        echo "Missing lets encrypt cert or key. Using standard cert. Restart after getting new cert."
        ARGS="$ARGS -hostname=$URL "
    fi
fi

# Set the TLS binding flag
if [ -n "$NGROK_BINDTLS" ]; then
  ARGS="$ARGS -bind-tls=$NGROK_BINDTLS "
fi

# Set the authorization token.
if [ -n "$NGROK_AUTH" ]; then
  echo "authtoken: $NGROK_AUTH" >> ~/.ngrok2/ngrok.yml
fi

# Set the subdomain or hostname, depending on which is set
if [ -n "$NGROK_HOSTNAME" ] && [ -n "$NGROK_AUTH" ]; then
  ARGS="$ARGS -hostname=$NGROK_HOSTNAME "
elif [ -n "$NGROK_SUBDOMAIN" ] && [ -n "$NGROK_AUTH" ]; then
  ARGS="$ARGS -subdomain=$NGROK_SUBDOMAIN "
elif [ -n "$NGROK_HOSTNAME" ] || [ -n "$NGROK_SUBDOMAIN" ]; then
  if [ -z "$NGROK_AUTH" ]; then
    echo "You must specify an authentication token after registering at https://ngrok.com to use custom domains."
    exit 1
  fi
fi

# Set the remote-addr if specified
if [ -n "$NGROK_REMOTE_ADDR" ]; then
  if [ -z "$NGROK_AUTH" ]; then
    echo "You must specify an authentication token after registering at https://ngrok.com to use reserved ip addresses."
    exit 1
  fi
  ARGS="$ARGS -remote-addr=$NGROK_REMOTE_ADDR "
fi

# Set a custom region
if [ -n "$NGROK_REGION" ]; then
  ARGS="$ARGS -region=$NGROK_REGION "
fi

if [ -n "$NGROK_HEADER" ]; then
  ARGS="$ARGS -host-header=$NGROK_HEADER "
fi

if [ -n "$NGROK_USERNAME" ] && [ -n "$NGROK_PASSWORD" ] && [ -n "$NGROK_AUTH" ]; then
  ARGS="$ARGS -auth=$NGROK_USERNAME:$NGROK_PASSWORD "
elif [ -n "$NGROK_USERNAME" ] || [ -n "$NGROK_PASSWORD" ]; then
  if [ -z "$NGROK_AUTH" ]; then
    echo "You must specify a username, password, and Ngrok authentication token to use the custom HTTP authentication."
    echo "Sign up for an authentication token at https://ngrok.com"
    exit 1
  fi
fi

if [ -n "$NGROK_DEBUG" ]; then
    ARGS="$ARGS -log stdout"
fi

# Set the port.
if [ -z "$NGROK_PORT" ]; then
  echo "You must specify a NGROK_PORT to expose."
  exit 1
fi

if [ -n "$NGROK_LOOK_DOMAIN" ]; then
  ARGS="$ARGS `echo $NGROK_LOOK_DOMAIN:$NGROK_PORT | sed 's|^tcp://||'`"
else
  ARGS="$ARGS `echo $NGROK_PORT | sed 's|^tcp://||'`"
fi

set -x
exec $ARGS
