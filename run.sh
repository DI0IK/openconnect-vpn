#!/bin/bash

# Define log files
OPENCONNECT_LOG="/var/log/openconnect.log"

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up iptables rules for masquerading
iptables -t nat -C POSTROUTING -o tun0 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -C FORWARD -i wg0 -o tun0 -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i wg0 -o tun0 -j ACCEPT
iptables -C FORWARD -i tun0 -o wg0 -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i tun0 -o wg0 -j ACCEPT

# Check for mandatory environment variables
if [ -z "$VPN_SERVER" ] || [ -z "$VPN_USERNAME" ] || [ -z "$VPN_PASSWORD" ] || [ -z "$VPN_GROUP" ] || [ -z "$VPN_TOKEN_SECRET" ]; then
    echo "ERROR: Missing required environment variables." >> "$OPENCONNECT_LOG"  
    exit 1
fi

touch "$OPENCONNECT_LOG"

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

echo "Starting OpenConnect using Form Replies..." >> "$OPENCONNECT_LOG"

# Using --form-reply for everything:
# 'main:group_list' matches the dropdown selection
# 'main:username' matches the username field
# 'main:password' matches the first password field
# 'main:secondary' matches the OTP/Passcode field
openconnect --protocol=anyconnect \
    --token-mode=totp \
    --token-secret="$VPN_TOKEN_SECRET" \
    --form-reply="main:group_list=$VPN_GROUP" \
    --form-reply="main:username=$VPN_USERNAME" \
    --form-reply="main:password=$VPN_PASSWORD" \
    --form-reply="main:secondary=TOKEN" \
    "$VPN_SERVER" >> "$OPENCONNECT_LOG" 2>&1 &

OC_PID=$!

# Stream the log and wait
tail -n +1 -F "$OPENCONNECT_LOG" &
TAIL_PID=$!

wait "$OC_PID"
EXIT_CODE=$?

sleep 1
kill "$TAIL_PID" 2>/dev/null || true

echo "OpenConnect exited with code $EXIT_CODE" >> "$OPENCONNECT_LOG"
exit $EXIT_CODE
