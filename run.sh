#!/bin/bash

# Define log files
OPENCONNECT_LOG="/var/log/openconnect.log"

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up iptables rules for masquerading (ignore errors if rules already exist)
iptables -t nat -C POSTROUTING -o tun0 -j MASQUERADE 2>/dev/null || \
    iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -C FORWARD -i wg0 -o tun0 -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i wg0 -o tun0 -j ACCEPT
iptables -C FORWARD -i tun0 -o wg0 -j ACCEPT 2>/dev/null || \
    iptables -A FORWARD -i tun0 -o wg0 -j ACCEPT

# Check if necessary environment variables are set
if [ -z "$VPN_SERVER" ] || [ -z "$VPN_USERNAME" ] || [ -z "$VPN_PASSWORD" ] || [ -z "$VPN_GROUP" ]; then
        echo "VPN_SERVER, VPN_USERNAME, VPN_PASSWORD, and VPN_GROUP environment variables must be set" >> "$OPENCONNECT_LOG"  
        exit 1
fi

touch "$OPENCONNECT_LOG"

# Ensure vpnc-script exists and is executable
if [ ! -x "/etc/vpnc/vpnc-script" ]; then
    echo "/etc/vpnc/vpnc-script missing or not executable. This may cause vpnc-script errors." >> "$OPENCONNECT_LOG"
fi

# Forward signals to OpenConnect and clean up
term_handler() {
    echo "Stopping OpenConnect..." >> "$OPENCONNECT_LOG"
    if [ -n "$OC_PID" ] && kill -0 "$OC_PID" 2>/dev/null; then
        kill -TERM "$OC_PID" 2>/dev/null
        wait "$OC_PID"
    fi
    exit 0
}

trap term_handler TERM INT

echo "Starting OpenConnect..." >> "$OPENCONNECT_LOG"
openconnect --user="$VPN_USERNAME" --usergroup="$VPN_GROUP" --passwd-on-stdin "$VPN_SERVER" >> "$OPENCONNECT_LOG" 2>&1 < <(echo "$VPN_PASSWORD") &
OC_PID=$!

# Stream the log and wait for openconnect to exit
tail -n +1 -F "$OPENCONNECT_LOG" &
TAIL_PID=$!

wait "$OC_PID"
EXIT_CODE=$?

# Give tail a moment then kill it
sleep 1
kill "$TAIL_PID" 2>/dev/null || true

echo "OpenConnect exited with code $EXIT_CODE" >> "$OPENCONNECT_LOG"
exit $EXIT_CODE