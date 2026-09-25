#!/bin/bash
set -e
set -x

# ==============================
# All the Mons Configuration
# ==============================

SERVER_VERSION="1.3.0"
SERVER_FILE_ID=8822160
SERVER_FILE_NAME="ServerFiles-${SERVER_VERSION}.zip"

# Extract prefix/suffix from file ID dynamically
SERVER_FILE_ID_PREFIX="${SERVER_FILE_ID:0:4}"
# ForgeCDN drops leading zeros in the suffix (e.g. 8916064 -> 8916/64)
SERVER_FILE_ID_SUFFIX="$((10#${SERVER_FILE_ID: -3}))"

FORGE_CDN_URL="https://mediafilez.forgecdn.net/files/${SERVER_FILE_ID_PREFIX}/${SERVER_FILE_ID_SUFFIX}/${SERVER_FILE_NAME}"

cd /data || exit 1

# ==============================
# EULA Check
# ==============================

if ! [[ "$EULA" = "false" ]]; then
    echo "eula=true" > eula.txt
else
    echo "You must accept the EULA to install."
    exit 99
fi

# ==============================
# Install Server Files (First Run Only)
# ==============================

if ! [[ -f "$SERVER_FILE_NAME" ]]; then
    echo "First run detected. Installing All the Mons..."

    rm -fr config defaultconfigs kubejs local mods packmenu libraries ServerFiles-* neoforge*

    echo "Downloading from ForgeCDN..."
    curl -L -o "$SERVER_FILE_NAME" "$FORGE_CDN_URL" || exit 9

    echo "Extracting server files..."
    unzip -u -o "$SERVER_FILE_NAME" -d /data

    DIR_TEST="ServerFiles-${SERVER_VERSION}"

    if [[ -d "$DIR_TEST" ]]; then
        cd "$DIR_TEST" || exit 1
        find . -type d -exec chmod 755 {} +
        mv -f * /data
        cd /data || exit 1
        rm -fr "$DIR_TEST"
    fi
fi

# ==============================
# Install NeoForge (without starting the server)
# ==============================

# startserver.sh installs NeoForge and writes a default server.properties on first run.
# Running it in install-only mode here means the settings below apply on the very first boot.
if [[ ! -f startserver.sh ]]; then
    echo "ERROR: startserver.sh not found."
    ls -la
    exit 1
fi
chmod +x startserver.sh
ATM10_INSTALL_ONLY=true ./startserver.sh

# ==============================
# JVM Options (if file exists)
# ==============================

if [[ -n "$JVM_OPTS" ]] && [[ -f user_jvm_args.txt ]]; then
    sed -i '/-Xm[s,x]/d' user_jvm_args.txt
    # The pack ships this file without a trailing newline; add one so appended flags land on their own line
    sed -i -e '$a\' user_jvm_args.txt
    for j in ${JVM_OPTS}; do
        echo "$j" >> user_jvm_args.txt
    done
fi

# ==============================
# Server Properties
# ==============================

# Set key=value, adding the key if the file doesn't have it yet
set_prop() {
    local key="$1" value="$2"
    value=$(printf '%s' "$value" | sed -e 's/[\\/&]/\\&/g')
    if grep -q "^${key}=" server.properties; then
        sed -i "s/^${key}=.*/${key}=${value}/" server.properties
    else
        echo "${key}=${value}" >> server.properties
    fi
}

touch server.properties
sed -i -e '$a\' server.properties

[[ -n "$MOTD" ]] && set_prop motd "$MOTD"
[[ -n "$ENABLE_WHITELIST" ]] && set_prop white-list "$ENABLE_WHITELIST"
[[ -n "$ENABLE_WHITELIST" ]] && set_prop enforce-whitelist "$ENABLE_WHITELIST"
[[ -n "$ALLOW_FLIGHT" ]] && set_prop allow-flight "$ALLOW_FLIGHT"
[[ -n "$MAX_PLAYERS" ]] && set_prop max-players "$MAX_PLAYERS"
[[ -n "$ONLINE_MODE" ]] && set_prop online-mode "$ONLINE_MODE"
set_prop server-port 25565

# ==============================
# Whitelist Setup
# ==============================

if [[ ! -f whitelist.json ]]; then
    echo "[]" > whitelist.json
fi

IFS=',' read -ra USERS <<< "$WHITELIST_USERS"
for raw_username in "${USERS[@]}"; do
    username=$(echo "$raw_username" | xargs)

    if [[ -z "$username" ]] || ! [[ "$username" =~ ^[a-zA-Z0-9_]{3,16}$ ]]; then
        echo "Whitelist: Invalid username '$username'. Skipping..."
        continue
    fi

    UUID=$(curl -s "https://playerdb.co/api/player/minecraft/$username" | jq -r '.data.player.id')

    if [[ "$UUID" != "null" ]]; then
        if jq -e ".[] | select(.uuid == \"$UUID\")" whitelist.json > /dev/null; then
            echo "Whitelist: $username already added."
        else
            jq ". += [{\"uuid\": \"$UUID\", \"name\": \"$username\"}]" whitelist.json > tmp.json && mv tmp.json whitelist.json
            echo "Whitelist: Added $username"
        fi
    fi
done

# ==============================
# Ops Setup
# ==============================

if [[ ! -f ops.json ]]; then
    echo "[]" > ops.json
fi

IFS=',' read -ra OPS <<< "$OP_USERS"
for raw_username in "${OPS[@]}"; do
    username=$(echo "$raw_username" | xargs)

    if [[ -z "$username" ]] || ! [[ "$username" =~ ^[a-zA-Z0-9_]{3,16}$ ]]; then
        echo "Ops: Invalid username '$username'. Skipping..."
        continue
    fi

    UUID=$(curl -s "https://playerdb.co/api/player/minecraft/$username" | jq -r '.data.player.id')

    if [[ "$UUID" != "null" ]]; then
        if jq -e ".[] | select(.uuid == \"$UUID\")" ops.json > /dev/null; then
            echo "Ops: $username already added."
        else
            jq ". += [{\"uuid\": \"$UUID\", \"name\": \"$username\", \"level\": 4, \"bypassesPlayerLimit\": false}]" ops.json > tmp.json && mv tmp.json ops.json
            echo "Ops: Added $username"
        fi
    fi
done

# ==============================
# Start Server
# ==============================

# Run Java directly instead of startserver.sh: the pack's script loops and doesn't pass signals on.
# On `docker stop` (SIGTERM), type "stop" into the server console so the world saves before exit.
NEOFORGE_VERSION=$(sed -n 's/^NEOFORGE_VERSION=//p' startserver.sh)
CONSOLE=/tmp/mc-console
rm -f "$CONSOLE"
mkfifo "$CONSOLE"

echo "Starting All the Mons server (NeoForge ${NEOFORGE_VERSION})..."
java @user_jvm_args.txt "@libraries/net/neoforged/neoforge/${NEOFORGE_VERSION}/unix_args.txt" nogui < "$CONSOLE" &
SERVER_PID=$!
exec 3> "$CONSOLE"  # hold the write end open so the server never sees end-of-input

trap 'echo "Stop requested, saving world..."; echo stop >&3' TERM INT

set +e
while kill -0 "$SERVER_PID" 2>/dev/null; do
    wait "$SERVER_PID"
    STATUS=$?
done
exit "$STATUS"
