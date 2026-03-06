#!/bin/bash

# Define log files
OPENCONNECT_LOG="/var/log/openconnect.log"

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up iptables rules for masquerading (ignore errors if rules already exist)
# This allows your WireGuard (wg0) clients to reach DHBW via tun0
iptables -t nat -C POSTROUTING -o tun0 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -C FORWARD -i wg0 -o tun0 -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i wg0 -o tun0 -j ACCEPT
iptables -C FORWARD -i tun0 -o wg0 -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i tun0 -o wg0 -j ACCEPT

# Check for mandatory environment variables
if [ -z "$VPN_SERVER" ] || [ -z "$VPN_USERNAME" ] || [ -z "$VPN_PASSWORD" ] || [ -z "$VPN_GROUP" ] || [ -z "$VPN_TOKEN_SECRET" ]; then
    echo "ERROR: VPN_SERVER, VPN_USERNAME, VPN_PASSWORD, VPN_GROUP, and VPN_TOKEN_SECRET must be set." >> "$OPENCONNECT_LOG"  
    exit 1
fi

touch "$OPENCONNECT_LOG"

# Ensure vpnc-script exists
if [ ! -x "/etc/vpnc/vpnc-script" ]; then
    echo "CRITICAL: /etc/vpnc/vpnc-script missing or not executable." >> "$OPENCONNECT_LOG"
fi

# Forward signals to OpenConnect and clean up
term_handler() {
    echo "Stopping OpenConnect gateway..." >> "$OPENCONNECT_LOG"
    if [ -n "$OC_PID" ] && kill -0 "$OC_PID" 2>/dev/null; then
        kill -TERM "$OC_PID" 2>/dev/null
        wait "$OC_PID"
    fi
    exit 0
}

trap term_handler TERM INT

echo "Starting OpenConnect with Automated 2FA..." >> "$OPENCONNECT_LOG"

# Logic Breakdown:
# 1. --token-mode=totp: Uses the internal OATH generator.
# 2. --token-secret: Uses your Base32 key from DHBW.
# 3. --form-reply: Explicitly maps the generated token to the 'secondary' field 
#    often used by Cisco for 2FA challenges.
openconnect --protocol=anyconnect \
    --user="$VPN_USERNAME" \
    --authgroup="$VPN_GROUP" \
    --token-mode=totp \
    --token-secret="$VPN_TOKEN_SECRET" \
    --form-reply="main:secondary=TOKEN" \
    --passwd-on-stdin \
    "$VPN_SERVER" $VPW_EXTRA_ARGS >> "$OPENCONNECT_LOG" 2>&1 < <(echo "$VPN_PASSWORD") &

OC_PID=$!

# Stream the log to stdout (so 'docker logs' works) and wait
tail -n +1 -F "$OPENCONNECT_LOG" &
TAIL_PID=$!

wait "$OC_PID"
EXIT_CODE=$?

# Cleanup
sleep 1
kill "$TAIL_PID" 2>/dev/null || true

echo "OpenConnect exited with code $EXIT_CODE" >> "$OPENCONNECT_LOG"
exit $EXIT_CODE
