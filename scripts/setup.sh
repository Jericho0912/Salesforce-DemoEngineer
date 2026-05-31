#!/usr/bin/env bash
# NTO Demo — one-command setup (macOS / Linux)
# Deploys all metadata, assigns the permission set, and loads seed data.
# Usage:  ./scripts/setup.sh [orgAlias]
set -euo pipefail

ORG_ALIAS="${1:-Demo-Org}"

echo "==> NTO Demo setup against org '${ORG_ALIAS}'"

echo ""
echo "[1/3] Deploying metadata..."
sf project deploy start -d force-app -o "${ORG_ALIAS}"

echo ""
echo "[2/3] Assigning permission set NTO_Demo_Access..."
sf org assign permset -n NTO_Demo_Access -o "${ORG_ALIAS}" || true  # non-fatal if already assigned

echo ""
echo "[3/3] Loading seed data..."
sf apex run -f scripts/apex/seed.apex -o "${ORG_ALIAS}"

echo ""
echo "==> Automated setup complete."
cat <<'EOF'

NEXT (one-time manual steps — see README for details):
  1. Activate Lightning pages:
       - Contact -> 'Contact Customer 360'  (org default or app default)
       - Case    -> 'Case Workspace 360'    (assign in 'NTO Service Console' app)
  2. Agentforce: build the agent in Agent Builder and attach the
     'Get NTO Order Status' action and 'NTO Create Return' flow (README > Agentforce Setup).
  3. Experience Cloud: enable Digital Experiences, create the LWR site,
     add the 'My Account (Customer Portal)' component (README > Experience Cloud Setup).
EOF
