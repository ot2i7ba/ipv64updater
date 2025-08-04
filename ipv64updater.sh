#!/bin/bash

# Copyright (c) 2024 ot2i7ba
# https://github.com/ot2i7ba/
# This code is licensed under the MIT License (see LICENSE for details).

# ipv64.net Dynamic DNS Update Script for Synology NAS
# - Fallback logic: Tries local (IPv6) and checkip.synology.com (IPv4) first, then ifconfig.co (IPv4/IPv6)
# - Updates IPv4 and/or IPv6 addresses including IPv6 prefix
# - Compatible with Synology DSM Task Scheduler

# USER CONFIGURATION
KEY="CHANGEME"                                # Your ipv64.net update key
DOMAIN="CHANGEME"                             # Your ipv64.net domain

NET_IFACE="eth0"                              # Network interface for IPv6 (e.g., eth0, lan1)

AGE_MIN_H=3                                   # Min interval (in hours) between updates
RequestIPv4=true                              # Set to false to skip IPv4
RequestIPv6=true                              # Set to false to skip IPv6

LOG_NAME="/volume1/docker/ipv64updater.log"   # Path for persistent logfile
LOG_MAX_SIZE=$((512*1024))                    # Log rotation: max logfile size in Bytes (default: 512KB)
LOG_BACKUP_COUNT=1                            # Number of backup logfiles to keep

# Log Rotation: Rotate log if size exceeds limit
rotate_log() {
    if [ -f "$LOG_NAME" ]; then
        local size
        size=$(stat -c %s "$LOG_NAME")
        if [ "$size" -ge "$LOG_MAX_SIZE" ]; then
            for ((i=LOG_BACKUP_COUNT; i>1; i--)); do
                if [ -f "${LOG_NAME}.$((i-1))" ]; then
                    mv "${LOG_NAME}.$((i-1))" "${LOG_NAME}.$i"
                fi
            done
            mv "$LOG_NAME" "${LOG_NAME}.1"
            touch "$LOG_NAME"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Log rotated due to size limit." >> "$LOG_NAME"
        fi
    fi
}
rotate_log

# Calculate logfile age for abuse protection (integer hours)
if [ -f "$LOG_NAME" ]; then
    now=$(date +%s)
    filemod=$(stat -c %Y "$LOG_NAME")
    diff_seconds=$(( now - filemod ))
    AGE_H=$(( diff_seconds / 3600 ))
else
    AGE_H=9999
fi

LAST_RESPONSE_LINE=$(grep -E "Response:" "$LOG_NAME" | tail -n 1)

# IPv4 detection: Synology first, then ifconfig.co as fallback
get_ipv4() {
    # Try Synology service first (returns pure IPv4)
    ipv4=$(curl -4 -s --max-time 10 https://checkip.synology.com | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}')
    if [[ "$ipv4" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
        echo "$ipv4"
        return 0
    fi
    # Fallback to ifconfig.co
    ipv4=$(curl -4 -s --max-time 10 https://ifconfig.co)
    if [[ "$ipv4" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
        echo "$ipv4"
        return 0
    fi
    return 1
}

if [ "$RequestIPv4" = true ]; then
    IPV4=$(get_ipv4)
    if ! [[ "$IPV4" =~ ^[0-9]+(\.[0-9]+){3}$ ]]; then
        echo "Error: Could not determine a valid public IPv4 address!"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Invalid public IPv4 address." >> "$LOG_NAME"
        exit 10
    fi
else
    IPV4=""
fi

# IPv6 detection: local first, then ifconfig.co as fallback
get_ipv6() {
    local ipv6
    ipv6=$(ip -6 addr show "$NET_IFACE" scope global | grep 'inet6' | awk '{print $2}' | cut -d/ -f1 | grep -Ev '^fe80|^fd00|::1' | head -n 1)
    if [[ -n "$ipv6" ]] && echo "$ipv6" | grep -Eq '^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$'; then
        echo "$ipv6"
        return 0
    fi
    # Fallback to ifconfig.co via IPv6
    ipv6=$(curl -6 -s --max-time 10 https://ifconfig.co)
    if [[ "$ipv6" =~ : ]] && echo "$ipv6" | grep -Eq '^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$'; then
        echo "$ipv6"
        return 0
    fi
    return 1
}

if [ "$RequestIPv6" = true ]; then
    IPV6=$(get_ipv6)
    if [[ -n "$IPV6" ]]; then
        if ! echo "$IPV6" | grep -Eq '^([0-9a-fA-F]{0,4}:){2,7}[0-9a-fA-F]{0,4}$'; then
            echo "Error: Invalid global IPv6 address syntax: $IPV6"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Invalid global IPv6 address syntax: $IPV6" >> "$LOG_NAME"
            IPV6=""
            IPV6PREFIX=""
        else
            IPV6PREFIX=$(echo "$IPV6" | awk -F: '{print tolower($1) ":" tolower($2) ":" tolower($3) ":" tolower($4) "::/64"}')
        fi
    else
        IPV6PREFIX=""
    fi
else
    IPV6=""
    IPV6PREFIX=""
fi

if [ "$RequestIPv6" = true ] && [ -z "$IPV6" ]; then
    ip -6 addr show "$NET_IFACE" &>/dev/null
    if [ $? -ne 0 ]; then
        echo "Error: Network interface $NET_IFACE not found or inaccessible."
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: Network interface $NET_IFACE not found." >> "$LOG_NAME"
        exit 11
    fi
fi

if [ "$RequestIPv4" = true ] && [ -z "$IPV4" ]; then
    echo "Error: Could not reach the service to determine IPv4 address (no internet?)."
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Error: No IPv4 address (service unreachable)." >> "$LOG_NAME"
    exit 12
fi

# Check for IP changes (skip update if unchanged)
UNCHANGED="false"
if [ "$RequestIPv4" = true ] && [[ "$LAST_RESPONSE_LINE" == *"$IPV4"* ]]; then
    if [ "$RequestIPv6" = true ]; then
        if [[ -n "$IPV6" && "$LAST_RESPONSE_LINE" == *"$IPV6"* ]]; then
            UNCHANGED="true"
        elif [[ -z "$IPV6" ]]; then
            UNCHANGED="true"
        fi
    else
        UNCHANGED="true"
    fi
fi

if [ "$AGE_H" -ge "$AGE_MIN_H" ] || [ "$UNCHANGED" = "false" ]; then
    UPDATE_URL="https://ipv64.net/update.php?key=${KEY}&domain=${DOMAIN}"
    if [ "$RequestIPv4" = true ] && [[ -n "$IPV4" ]]; then
        UPDATE_URL="${UPDATE_URL}&ip=${IPV4}"
    fi
    if [ "$RequestIPv6" = true ] && [[ -n "$IPV6" ]]; then
        UPDATE_URL="${UPDATE_URL}&ip6=${IPV6}"
    fi
    if [ "$RequestIPv6" = true ] && [[ -n "$IPV6PREFIX" ]]; then
        UPDATE_URL="${UPDATE_URL}&ipv6prefix=${IPV6PREFIX}"
    fi

    RESPONSE=$(curl -s -A "Mozilla/5.0 (X11; Linux x86_64)" --max-time 20 "${UPDATE_URL}")

    {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')]"
        echo "Update URL: $UPDATE_URL"
        echo "Response: $RESPONSE"
    } >> "$LOG_NAME"

    if [[ "$RESPONSE" == good* ]] || [[ "$RESPONSE" == nochg* ]]; then
        echo "$RESPONSE"
        exit 0
    else
        echo "$RESPONSE"
        exit 20
    fi
else
    echo "nochg $IPV4 $IPV6"
    exit 0
fi
