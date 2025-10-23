# Use the official Alpine base image
FROM alpine:latest
# Script to run OpenConnect and SSH
COPY run.sh /run.sh
# Install OpenConnect and vpnc helper scripts; ensure bash and iproute2 are available
RUN apk update && \
  apk add --no-cache bash openssl openssh openconnect vpnc openresolv iproute2 iptables && \
  chmod +x /run.sh
# Run the script with bash so process substitution and bash-specific features work
ENTRYPOINT ["/bin/bash", "/run.sh"]