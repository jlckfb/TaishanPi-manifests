#!/bin/bash

###############################################################################
# TaishanPi SDK Install Bootstrap
# Usage:
#   curl -fsSL <URL>/install.sh | bash -s -- -b android14/tspi-3-260416
#   curl -fsSL <URL>/install.sh | bash -s -- -b linux/tspi-3-260402
###############################################################################

set -uo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

MANIFEST_BRANCH=""
RAW_BASE="https://raw.githubusercontent.com/jlckfb/TaishanPi-manifests"

usage() {
    echo -e "${BOLD}TaishanPi SDK Install Bootstrap${NC}"
    echo ""
    echo "Usage: curl -fsSL <URL>/install.sh | bash -s -- -b <branch>"
    echo ""
    echo "Options:"
    echo "  -b <branch>   Manifest branch (required)"
    echo "  -h            Show this help"
    echo ""
    echo "Examples:"
    echo "  bash -s -- -b android14/tspi-3-260416"
    echo "  bash -s -- -b linux/tspi-3-260402"
    exit 0
}

while getopts "b:h" opt; do
    case $opt in
        b) MANIFEST_BRANCH="$OPTARG" ;;
        h) usage ;;
        *) usage ;;
    esac
done

if [[ -z "$MANIFEST_BRANCH" ]]; then
    echo -e "${RED}[ERR] Missing required option: -b <branch>${NC}"
    echo ""
    usage
fi

SETUP_URL="${RAW_BASE}/${MANIFEST_BRANCH}/setup.sh"

echo -e "${CYAN}${BOLD}>>> TaishanPi SDK Installer${NC}"
echo -e "  Branch: ${BOLD}${MANIFEST_BRANCH}${NC}"
echo -e "  Fetching setup script from: ${SETUP_URL}"
echo ""

SETUP_SCRIPT=$(curl -fsSL "$SETUP_URL" 2>&1)
if [[ $? -ne 0 ]]; then
    echo -e "${RED}[ERR] Failed to download setup script${NC}"
    echo -e "${RED}  URL: ${SETUP_URL}${NC}"
    echo -e "${RED}  Please check the branch name is correct${NC}"
    echo ""
    echo "Available branches: https://github.com/jlckfb/TaishanPi-manifests/branches"
    exit 1
fi

echo -e "${GREEN}[OK] Setup script downloaded, launching...${NC}"
echo ""

bash -c "$SETUP_SCRIPT"
