#!/bin/bash

# Define log files
OPENCONNECT_LOG="/var/log/openconnect.log"

# Enable IP forwarding
echo 1 > /proc/sys/net/ipv4/ip_forward

# Set up iptables rules for masquerading
iptables -t nat -A POSTROUTING -o tun0 -j MASQUERADE
iptables -A FORWARD -i wg0 -o tun0 -j ACCEPT
iptables -A FORWARD -i tun0 -o wg0 -j ACCEPT

# Check if necessary environment variables are set
if [ -z "$VPN_SERVER" ] || [ -z "$VPN_USERNAME" ] || [ -z "$VPN_PASSWORD" ] || [ -z "$VPN_GROUP" ]; then
    echo "VPN_SERVER, VPN_USERNAME, VPN_PASSWORD, and VPN_GROUP environment variables must be set" >> "$OPENCONNECT_LOG" >&2 
    exit 1
fi

touch "$OPENCONNECT_LOG"

# Start OpenConnect and log output
echo "Starting OpenConnect..."
openconnect --user="$VPN_USERNAME" --usergroup="$VPN_GROUP" --passwd-on-stdin "$VPN_SERVER" >> "$OPENCONNECT_LOG" < <(echo "$VPN_PASSWORD") &
OC_PID=$!
tail -f "$OPENCONNECT_LOG"