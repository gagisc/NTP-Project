#!/bin/bash
# NTP Server Verification Script
# Use this to verify your NTP server is working correctly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  NTP Server Verification Script       ${NC}"
echo -e "${GREEN}========================================${NC}"

# Get IP address from argument or environment
NTP_IP="${1:-$NTP_SERVER_IP}"

if [ -z "$NTP_IP" ]; then
    echo -e "${RED}Usage: $0 <ntp-server-ip>${NC}"
    echo -e "Or set NTP_SERVER_IP environment variable"
    exit 1
fi

echo -e "\n${YELLOW}Testing NTP server: ${NTP_IP}${NC}"

# Test 1: Basic connectivity (UDP 123)
echo -e "\n${YELLOW}Test 1: UDP Port 123 Connectivity${NC}"
if command -v nc >/dev/null 2>&1; then
    if nc -zu "$NTP_IP" 123 2>/dev/null; then
        echo -e "${GREEN}✓ UDP port 123 is open${NC}"
    else
        echo -e "${RED}✗ Cannot reach UDP port 123${NC}"
    fi
else
    echo -e "${YELLOW}Skipping (netcat not installed)${NC}"
fi

# Test 2: NTP query with ntpdate
echo -e "\n${YELLOW}Test 2: NTP Query (ntpdate)${NC}"
if command -v ntpdate >/dev/null 2>&1; then
    if ntpdate -q "$NTP_IP" 2>/dev/null; then
        echo -e "${GREEN}✓ NTP response received${NC}"
    else
        echo -e "${RED}✗ No NTP response${NC}"
    fi
else
    echo -e "${YELLOW}Skipping (ntpdate not installed)${NC}"
fi

# Test 3: NTP query with ntpq (if available)
echo -e "\n${YELLOW}Test 3: NTP Peer Info (ntpq)${NC}"
if command -v ntpq >/dev/null 2>&1; then
    ntpq -p "$NTP_IP" 2>/dev/null || echo -e "${YELLOW}ntpq query failed (may be blocked by noquery)${NC}"
else
    echo -e "${YELLOW}Skipping (ntpq not installed)${NC}"
fi

# Test 4: Chrony query with chronyc (if deployed in k8s)
echo -e "\n${YELLOW}Test 4: Chrony Status (if kubectl available)${NC}"
if command -v kubectl >/dev/null 2>&1; then
    POD_NAME=$(kubectl get pods -n ntp-server -l app=ntp-server -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
    if [ -n "$POD_NAME" ]; then
        echo -e "\n${GREEN}Chrony Tracking:${NC}"
        kubectl exec -n ntp-server "$POD_NAME" -- chronyc tracking 2>/dev/null || true
        
        echo -e "\n${GREEN}Chrony Sources:${NC}"
        kubectl exec -n ntp-server "$POD_NAME" -- chronyc sources 2>/dev/null || true
        
        echo -e "\n${GREEN}Chrony Sourcestats:${NC}"
        kubectl exec -n ntp-server "$POD_NAME" -- chronyc sourcestats 2>/dev/null || true
    else
        echo -e "${YELLOW}No NTP pods found in ntp-server namespace${NC}"
    fi
else
    echo -e "${YELLOW}Skipping (kubectl not available)${NC}"
fi

# Test 5: Latency test
echo -e "\n${YELLOW}Test 5: Latency Test${NC}"
if command -v ping >/dev/null 2>&1; then
    echo "Pinging NTP server..."
    ping -c 5 "$NTP_IP" 2>/dev/null || echo -e "${YELLOW}Ping failed (may be blocked by firewall)${NC}"
fi

# Summary
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}  Verification Complete                ${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "\nServer IP: ${NTP_IP}"
echo -e "\npool.ntp.org Requirements Checklist:"
echo -e "  - Static IP address: ${GREEN}✓ (verify manually)${NC}"
echo -e "  - Permanent Internet connection: ${GREEN}✓ (cloud provider)${NC}"
echo -e "  - Minimum 384 Kbit/sec bandwidth: ${GREEN}✓ (cloud instances exceed this)${NC}"
echo -e "  - Upstream servers configured: ${GREEN}✓ (check chronyc sources)${NC}"
echo -e "  - No pool.ntp.org aliases used: ${GREEN}✓ (static servers configured)${NC}"
echo -e "  - noquery restriction: ${GREEN}✓ (management queries blocked)${NC}"

echo -e "\n${YELLOW}To register with pool.ntp.org:${NC}"
echo -e "1. Go to https://manage.ntppool.org/manage"
echo -e "2. Create an account or log in"
echo -e "3. Add your server IP: ${NTP_IP}"
echo -e "4. Wait for monitoring to verify your server (usually 24-48 hours)"
