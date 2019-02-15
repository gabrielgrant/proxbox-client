#! /bin/bash

set -e
set -u
set -x

PROXBOX_BASE_HOST=${PROXBOX_BASE_HOST:-"proxbox.gabrielgrant.ca"}
PROXBOX_HOST="www.${PROXBOX_BASE_HOST}"
PROXBOX="${PROXBOX_HOST}:8000"

if [ ! -f ~/.ssh/id_rsa ]; then
    ssh-keygen -t rsa -N "" -f ~/.ssh/id_rsa
    openssl rsa -in ~/.ssh/id_rsa -pubout -out ~/.ssh/id_rsa.openssl.pub
fi

PUBKEY=$(cat ~/.ssh/id_rsa.pub)

if [ ! -f cluster_id.txt ]; then
    # register cluster
    CONFIG=$(curl --data-urlencode "pubkey=$PUBKEY" "$PROXBOX/cluster/")
    CLUSTER_ID=$(echo $CONFIG | jq -r .cluster_id)  # -r removes quotes from output
    echo $CLUSTER_ID > cluster_id.txt
else
    # load cluster info

    # encrypt the cluster ID with the SSH private key as a signature
    CLUSTER_ID=$(cat cluster_id.txt)
    SIG=$(openssl rsautl -sign -inkey ~/.ssh/id_rsa -in cluster_id.txt)
    CONFIG=$(curl --data-urlencode "pubkey=$PUBKEY" --data-urlencode "signature=$SIG" "$PROXBOX/cluster/${CLUSTER_ID}")
fi

echo "Access your cluster at http://${CLUSTER_ID}-ui.${PROXBOX_BASE_HOST}?host=${CLUSTER_ID}-grpc.${PROXBOX_BASE_HOST}&port=80"

OUTER_UI_PORT=$(echo $CONFIG | jq .ui_port)
OUTER_GRPC_PORT=$(echo $CONFIG | jq .grpc_port)

INNER_UI_HOST=$DASH_SERVICE_HOST
INNER_UI_PORT=$DASH_SERVICE_PORT
INNER_GRPC_HOST=$DASH_SERVICE_HOST
INNER_GRPC_PORT=$DASH_SERVICE_PORT_GRPC_PROXY_HTTP

#TODO bind only on Docker network interface, rather than globally
GRPC_TUNNEL="0.0.0.0:${OUTER_GRPC_PORT}:${INNER_GRPC_HOST}:${INNER_GRPC_PORT}"
UI_TUNNEL="0.0.0.0:${OUTER_UI_PORT}:${INNER_UI_HOST}:${INNER_UI_PORT}"

# -N  SSH connection without remote command
# -T  disable pseudo-tty allocation

# add the proxbox server to known_hosts the first time it's seen
# note: this only works on OpenSSH >= 7.6 (Ubuntu 18.04)
# could do this ourselves with ssh-keyscan to work on older versions, but not
# really needed -- just updated the docker image to use Ubuntu 18.04
ACCEPT_NEW_HOSTS='-oStrictHostKeyChecking=accept-new'
# this may cause problems if we change the IP of the proxbox host
# alternatively, we could use `-oStrictHostKeyChecking=no` to never
# fail (but warn if there's a change) or `-oUserKnownHostsFile=/dev/null`
# to never even bother saving (ie no warning on change)

ssh -N -T $ACCEPT_NEW_HOSTS -R $GRPC_TUNNEL -R $UI_TUNNEL proxbox@$PROXBOX_HOST
