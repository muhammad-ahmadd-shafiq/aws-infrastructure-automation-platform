#!/usr/bin/env bash
# Generates ansible/inventory/hosts.ini from a server IP (normally the
# Terraform `server_public_ip` output) so no real IP or local file path is
# ever committed to the repo.
#
# Usage:
#   ./generate_inventory.sh <server_ip> [path_to_private_key]

set -euo pipefail

SERVER_IP="${1:?Usage: generate_inventory.sh <server_ip> [key_path]}"
KEY_PATH="${2:-$HOME/.ssh/id_ed25519}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

cat > "${SCRIPT_DIR}/hosts.ini" <<EOF
[aws]
${SERVER_IP} ansible_user=ubuntu ansible_ssh_private_key_file=${KEY_PATH}
EOF

echo "Wrote ${SCRIPT_DIR}/hosts.ini for ${SERVER_IP}"
