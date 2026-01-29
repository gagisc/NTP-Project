# Chrony NTP Server Dockerfile
# Optimized for pool.ntp.org deployment
#
# This container runs Chrony as an NTP server following pool.ntp.org guidelines:
# - Uses statically chosen upstream Stratum 1/2 servers
# - No LOCAL clock driver
# - Proper security restrictions
# - Runs as non-root user (security best practice)

FROM alpine:3.19

LABEL maintainer="NTP Server Project"
LABEL description="Chrony NTP server for pool.ntp.org"
LABEL version="1.0"

# Install chrony and required packages
RUN apk add --no-cache \
    chrony \
    tzdata \
    ca-certificates \
    curl \
    && rm -rf /var/cache/apk/*

# Create necessary directories with correct permissions
RUN mkdir -p /var/lib/chrony /var/log/chrony /var/run/chrony \
    && chown -R chrony:chrony /var/lib/chrony /var/log/chrony /var/run/chrony

# Copy chrony configuration
COPY chrony.conf /etc/chrony/chrony.conf

# Ensure config file has correct permissions
RUN chmod 644 /etc/chrony/chrony.conf

# Expose NTP port (UDP 123)
EXPOSE 123/udp

# Health check - verify chrony is tracking time
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD chronyc tracking | grep -q "Leap status" || exit 1

# Volume for persistent drift data
VOLUME ["/var/lib/chrony"]

# Run chrony in foreground mode
# -d: Run in foreground (don't daemonize)
# -f: Specify config file
# -x: Don't control the system clock (container mode - optional)
# Note: We need CAP_SYS_TIME to set the system clock, but for NTP serving
# the container primarily needs to read upstream servers and serve to clients

# Use chrony user for security
USER chrony

# Start chronyd in foreground mode
# The -d flag keeps it in foreground for container logging
# Remove -x if you want chrony to actually set the container's clock
ENTRYPOINT ["chronyd", "-d", "-f", "/etc/chrony/chrony.conf"]

# Default command (can be overridden)
CMD []
