#!/bin/sh
WORKPATH="$(pwd)"

WARP_ACCOUNT="${WORKPATH}/warpsock-account.toml"
if [ ! -f "${WARP_ACCOUNT}" ]; then
    echo "Generating \"${WARP_ACCOUNT}\" file..."
    wgcf register --config "${WARP_ACCOUNT}" --accept-tos true || exit $?
else
    echo "Skipping generation of \"${WARP_ACCOUNT}\" file..."
fi

WARP_CONFIG="${WORKPATH}/warpsock-wireguard.conf"
if [ ! -f "${WARP_CONFIG}" ]; then
    echo "Generating \"${WARP_CONFIG}\" file..."
    wgcf generate --config "${WARP_ACCOUNT}" --profile "${WARP_CONFIG}" || exit $?
else
    echo "Skipping generation of \"${WARP_CONFIG}\" file..."
fi

SB_CONFIG_FILE="$(mktemp)"
echo "Generating \"${SB_CONFIG_FILE}\" file..."
cat "/opt/warpsock/sing-box.json.template" > "${SB_CONFIG_FILE}"
ADDR_ALL=$(grep -m1 '^Address' "$WARP_CONFIG" | cut -d'=' -f2- | tr -d ' ')
WG_IFACE_PRIVATE=$(grep -m1 '^PrivateKey' "$WARP_CONFIG" | cut -d'=' -f2- | tr -d ' ')
WG_IFACE_ADDR_V4=$(echo "$ADDR_ALL" | tr ',' '\n' | grep '/32')
WG_IFACE_ADDR_V6=$(echo "$ADDR_ALL" | tr ',' '\n' | grep '/128')
WG_PEER_PUBLIC=$(grep -m1 '^PublicKey' "$WARP_CONFIG" | cut -d'=' -f2- | tr -d ' ')
WG_PEER_ENDPOINT=$(grep -m1 '^Endpoint' "$WARP_CONFIG" | cut -d'=' -f2- | cut -d':' -f1 | tr -d ' ')
WG_PEER_PORT=$(grep -m1 '^Endpoint' "$WARP_CONFIG" | cut -d'=' -f2- | cut -d':' -f2- | tr -d ' ')
WG_MTU=$(grep -m1 '^MTU' "$WARP_CONFIG" | cut -d'=' -f2- | tr -d ' ')
escape_sed() {
    printf '%s' "$1" | sed -e 's/[\/&]/\\&/g'
}
sed -i "s|__WG_IFACE_PRIVATE__|$(escape_sed "$WG_IFACE_PRIVATE")|g" "$SB_CONFIG_FILE"
sed -i "s|__WG_IFACE_ADDR_V4__|$(escape_sed "$WG_IFACE_ADDR_V4")|g" "$SB_CONFIG_FILE"
sed -i "s|__WG_IFACE_ADDR_V6__|$(escape_sed "$WG_IFACE_ADDR_V6")|g" "$SB_CONFIG_FILE"
sed -i "s|__WG_PEER_PUBLIC__|$(escape_sed "$WG_PEER_PUBLIC")|g" "$SB_CONFIG_FILE"
sed -i "s|__WG_PEER_ENDPOINT__|$(escape_sed "$WG_PEER_ENDPOINT")|g" "$SB_CONFIG_FILE"
sed -i "s|__WG_PEER_PORT__|$(escape_sed "$WG_PEER_PORT")|g" "$SB_CONFIG_FILE"
sed -i "s|__WG_MTU__|$(escape_sed "$WG_MTU")|g" "$SB_CONFIG_FILE"

cat "$SB_CONFIG_FILE"

echo "Running sing-box..."
sing-box -c "${SB_CONFIG_FILE}" run || exit $?
