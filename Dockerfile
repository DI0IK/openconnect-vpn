# Use the official Alpine base image
FROM alpine:latest
# Script to run OpenConnect and SSH
COPY run.sh /run.sh
# Install OpenConnect
RUN apk update && \
  apk add --no-cache openssl openssh openconnect iptables && \
  chmod +x /run.sh
# Set the entrypoint to the script
ENTRYPOINT ["/bin/sh", "/run.sh"]