#!/bin/bash

###############################################################################
# TaishanPi-3 Android14 SDK One-Click Install Script
# For: Ubuntu 22.04 LTS (Jammy Jellyfish)
# Usage: curl -fsSL <URL>/install.sh | bash -s -- -b android14/tspi-3-260416
# Note: Run as normal user. Script uses sudo internally for privileged ops.
###############################################################################

set -uo pipefail

# Ensure sbin directories are in PATH (needed for lsmod, modprobe, etc.)
export PATH="/usr/sbin:/sbin:$PATH"

# Ensure USER is set (may be unset in minimal environments or curl|bash)
: "${USER:=$(whoami)}"

LOG_FILE="/tmp/taishanpi3-install-$(date +%Y%m%d-%H%M%S).log"
touch "$LOG_FILE"

CLEANUP_FILES=()
BG_PIDS=()
cleanup() {
    for pid in "${BG_PIDS[@]}"; do
        kill "$pid" 2>/dev/null
        wait "$pid" 2>/dev/null
    done
    for f in "${CLEANUP_FILES[@]}"; do
        rm -rf "$f" 2>/dev/null
    done
}
trap cleanup EXIT

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

strip_ansi() { sed 's/\x1b\[[0-9;]*m//g'; }

log_info()  { echo -e "${GREEN}[OK] $* ${NC}"; echo "[OK] $*" | strip_ansi >> "$LOG_FILE"; }
log_warn()  { echo -e "${YELLOW}[!!] $* ${NC}"; echo "[!!] $*" | strip_ansi >> "$LOG_FILE"; }
log_error() { echo -e "${RED}[ERR] $* ${NC}"; echo "[ERR] $*" | strip_ansi >> "$LOG_FILE"; }
log_step()  { echo -e "${CYAN}${BOLD}>>> $* ${NC}"; echo ">>> $*" | strip_ansi >> "$LOG_FILE"; }
log_debug() { echo -e "${DIM}  -> $* ${NC}"; echo "  -> $*" | strip_ansi >> "$LOG_FILE"; }

# Extract and display key error lines from log when something fails
log_error_detail() {
    local context_msg="$1"
    local lines="${2:-10}"
    echo -e "${RED}[ERR] ${context_msg}${NC}"
    echo "[ERR] ${context_msg}" >> "$LOG_FILE"
    echo -e "${DIM}────────────────────────────────────────${NC}"
    grep -iE "(^E:|error:|fatal:)" "$LOG_FILE" \
        | grep -vE "(\[!!]|unable to resolve host|Name or service not known|non-critical)" \
        | tail -"$lines" \
        | while IFS= read -r line; do
            echo -e "  ${RED}${line}${NC}"
        done
    echo -e "${DIM}────────────────────────────────────────${NC}"
    echo -e "${YELLOW}  Full log: ${BOLD}${LOG_FILE}${NC}"
}

CURRENT_STAGE=""
fail_summary() {
    echo ""
    echo -e "${RED}${BOLD}╔══════════════════════════════════════════╗${NC}"
    echo -e "${RED}${BOLD}║            Install Failed                ║${NC}"
    echo -e "${RED}${BOLD}╚══════════════════════════════════════════╝${NC}"
    echo ""
    [[ -n "$CURRENT_STAGE" ]] && echo -e "${RED}  Failed stage: ${BOLD}${CURRENT_STAGE}${NC}"
    echo -e "${RED}  Error summary:${NC}"
    grep -iE "(^E:|error:|fatal:)" "$LOG_FILE" \
        | grep -vE "(\[!!]|unable to resolve host|Name or service not known|non-critical)" \
        | tail -5 \
        | while IFS= read -r line; do
            echo -e "    ${DIM}${line}${NC}"
        done
    echo ""
    echo -e "${YELLOW}  Full log: ${BOLD}${LOG_FILE}${NC}"
    echo -e "${YELLOW}  Troubleshoot: ${BOLD}cat ${LOG_FILE} | tail -50${NC}"
    echo ""
}

show_progress() {
    local current=$1 total=$2 message=$3 width=50
    local percentage=$((current * 100 / total))
    local completed=$((current * width / total))
    local remaining=$((width - completed))
    printf "\r${CYAN}[${NC}"
    printf "${GREEN}%${completed}s${NC}" | tr ' ' '#'
    printf "${DIM}%${remaining}s${NC}" | tr ' ' '-'
    printf "${CYAN}]${NC} ${BOLD}${percentage}%%${NC} ${message}"
    [ $current -eq $total ] && echo ""
}

show_spinner() {
    local pid=$1 message=$2
    local -a frames=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
    local i=0
    local start_ts=$SECONDS
    BG_PIDS+=("$pid")
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % ${#frames[@]} ))
        local elapsed=$(( SECONDS - start_ts ))
        printf "\r\033[K  %s %s... [%02d:%02d]" "${frames[$i]}" "$message" $((elapsed/60)) $((elapsed%60))
        sleep 0.1
    done
    wait $pid
    local ret=$?
    local new_pids=()
    for p in "${BG_PIDS[@]}"; do
        [[ "$p" != "$pid" ]] && new_pids+=("$p")
    done
    BG_PIDS=("${new_pids[@]}")
    local elapsed=$(( SECONDS - start_ts ))
    printf "\r\033[K"
    if [[ $ret -eq 0 ]]; then
        echo -e "${GREEN}[OK]${NC} ${message} ${DIM}($(printf '%02d:%02d' $((elapsed/60)) $((elapsed%60))))${NC}"
    else
        echo -e "${RED}[ERR]${NC} ${message} ${RED}Failed${NC} ${DIM}($(printf '%02d:%02d' $((elapsed/60)) $((elapsed%60))))${NC}"
    fi
    return $ret
}

wait_for_apt_lock() {
    local lock_holders
    lock_holders=$(ps -eo pid,comm 2>/dev/null | grep -E 'packagekitd|unattended-upgr|aptd' | grep -v grep)
    if [[ -n "$lock_holders" ]]; then
        log_warn "Stopping services that hold APT lock..."
        sudo systemctl stop packagekit.service 2>/dev/null && log_debug "Stopped packagekit"
        sudo systemctl stop unattended-upgrades.service 2>/dev/null && log_debug "Stopped unattended-upgrades"
        sleep 2
    fi

    local max_wait=30 waited=0
    while sudo fuser /var/lib/dpkg/lock-frontend /var/lib/apt/lists/lock /var/cache/apt/archives/lock 2>/dev/null; do
        if [[ $waited -eq 0 ]]; then
            log_warn "APT still locked, waiting for release..."
        fi
        sleep 2
        ((waited+=2))
        if [[ $waited -ge $max_wait ]]; then
            log_warn "Force releasing APT lock..."
            sudo kill -9 $(sudo fuser /var/lib/dpkg/lock-frontend 2>/dev/null) 2>/dev/null
            sudo kill -9 $(sudo fuser /var/lib/apt/lists/lock 2>/dev/null) 2>/dev/null
            sudo kill -9 $(sudo fuser /var/cache/apt/archives/lock 2>/dev/null) 2>/dev/null
            sleep 1
            if sudo fuser /var/lib/dpkg/lock-frontend 2>/dev/null; then
                log_error "Cannot release APT lock"
                return 1
            fi
            log_info "APT lock force released"
            break
        fi
    done
    [[ $waited -gt 0 && $waited -lt $max_wait ]] && log_info "APT lock released (waited ${waited}s)"
    return 0
}

print_box() {
    local message="$1" color="${2:-$CYAN}"
    local length=${#message} padding=4
    local total_length=$((length + padding * 2))
    echo ""
    printf "${color}+"; printf '%*s' "$total_length" '' | tr ' ' '='; printf "+${NC}\n"
    printf "${color}|"; printf "%*s" $padding ''; printf "${BOLD}${WHITE}%s${NC}" "$message"; printf "%*s" $padding ''; printf "${color}|${NC}\n"
    printf "${color}+"; printf '%*s' "$total_length" '' | tr ' ' '='; printf "+${NC}\n"
    echo ""
}

safe_read() {
    local prompt="$1" varname="$2"
    if [[ -t 0 ]]; then
        read -p "$prompt" -n 1 -r "$varname"
    else
        read -p "$prompt" -n 1 -r "$varname" </dev/tty
    fi
}

ALL_CHECKS_PASS=true
REGION=""
SDK_DIR="$PWD/TaishanPi-3-Android14"
STORAGE_WARNING=""

MANIFEST_BRANCH="android14/tspi-3-260416"
MANIFEST_URL="https://github.com/jlckfb/manifests.git"
REPO_DOWNLOAD_URL="https://cnb.cool/jlckfb/git-repo/-/git/raw/main/repo"

LFS_REPOS=()

detect_region() {
    if [[ -n "${TSPI_REGION:-}" ]]; then
        case "${TSPI_REGION}" in
            cn|CN|china|China) REGION="cn"; log_debug "Region: China (env)"; return 0 ;;
            global|GLOBAL|international) REGION="global"; log_debug "Region: International (env)"; return 0 ;;
        esac
    fi
    log_step "Detecting network environment"
    echo ""
    local cn_mirrors=("mirrors.cernet.edu.cn" "mirrors.tuna.tsinghua.edu.cn")
    local global_mirrors=("archive.ubuntu.com" "mirrors.kernel.org")
    local cn_latency=9999 global_latency=9999
    log_debug "Testing China mirror latency..."
    for mirror in "${cn_mirrors[@]}"; do
        local latency
        latency=$(curl -o /dev/null -s -w '%{time_total}\n' --connect-timeout 5 "http://${mirror}" 2>/dev/null | awk '{print int($1*1000)}') || true
        [[ -n "$latency" && "$latency" -lt "$cn_latency" ]] && cn_latency=$latency
    done
    log_debug "Testing international mirror latency..."
    for mirror in "${global_mirrors[@]}"; do
        local latency
        latency=$(curl -o /dev/null -s -w '%{time_total}\n' --connect-timeout 5 "http://${mirror}" 2>/dev/null | awk '{print int($1*1000)}') || true
        [[ -n "$latency" && "$latency" -lt "$global_latency" ]] && global_latency=$latency
    done
    log_debug "China: ${cn_latency}ms | International: ${global_latency}ms"
    if [[ $cn_latency -lt 9999 && $global_latency -lt 9999 ]]; then
        if [[ $cn_latency -lt $((global_latency / 2)) ]]; then
            REGION="cn"; log_info "Detected: China network"
        else
            REGION="global"; log_info "Detected: International network"
        fi
    elif [[ $cn_latency -lt 9999 ]]; then
        REGION="cn"; log_info "Detected: China network"
    elif [[ $global_latency -lt 9999 ]]; then
        REGION="global"; log_info "Detected: International network"
    else
        log_warn "Unable to auto-detect network environment"
        echo ""
        echo -e "${YELLOW}Please select your network environment:${NC}"
        echo -e "  ${CYAN}1)${NC} China (use China mirrors)"
        echo -e "  ${CYAN}2)${NC} International (use international mirrors)"
        echo ""
        local choice=""
        safe_read "Select [1/2]: " choice
        echo ""
        case $choice in
            1) REGION="cn"; log_info "Selected: China" ;;
            *) REGION="global"; log_info "Selected: International" ;;
        esac
    fi
    echo ""
    return 0
}

check_sudo_available() {
    if [[ $EUID -eq 0 ]]; then
        log_error "Do NOT run this script as root!"
        echo -e "Run as normal user: ${GREEN}curl -fsSL <URL> | bash${NC}"
        exit 1
    fi
    if ! sudo -n true 2>/dev/null; then
        log_warn "sudo password required for system package installation"
        if [[ -t 0 ]]; then
            sudo -v || { log_error "Cannot obtain sudo"; exit 1; }
        else
            sudo -v </dev/tty || { log_error "Cannot obtain sudo"; exit 1; }
        fi
    fi
    log_info "Permission check passed (user: $USER, sudo: available)"
}

check_ubuntu_version() {
    local required_version="22.04" required_codename="jammy" is_supported=0
    log_step "Checking system version"
    echo ""
    if command -v lsb_release &> /dev/null; then
        local os_id=$(lsb_release -si) os_release=$(lsb_release -sr) os_codename=$(lsb_release -sc)
        [[ "$os_id" == "Ubuntu" && "$os_release" == "$required_version" && "$os_codename" == "$required_codename" ]] && is_supported=1
    elif [[ -f /etc/os-release ]]; then
        source /etc/os-release
        [[ "$ID" == "ubuntu" && "$VERSION_ID" == "$required_version" && "$UBUNTU_CODENAME" == "$required_codename" ]] && is_supported=1
    fi
    if [[ $is_supported -eq 1 ]]; then
        log_info "System: Ubuntu ${required_version} LTS"
        echo ""
        return 0
    else
        log_error "Incompatible system version!"
        log_debug "Required: Ubuntu ${required_version} LTS (Jammy Jellyfish)"
        echo ""
        ALL_CHECKS_PASS=false
        return 1
    fi
}

check_cpu() {
    log_step "Checking CPU architecture"
    echo ""
    if [[ $(uname -m) != "x86_64" ]]; then
        log_error "Only x86_64 architecture is supported"
        echo ""
        ALL_CHECKS_PASS=false
        return 1
    fi
    local arch_support=0
    grep -q -E 'vmx|svm' /proc/cpuinfo && arch_support=1
    if [[ $arch_support -eq 0 ]]; then
        log_warn "CPU virtualization not enabled (may affect performance)"
    else
        log_info "CPU: x86_64 (VT-x/AMD-V)"
    fi
    echo ""
    return 0
}

check_storage() {
    log_step "Checking disk space"
    echo ""
    local min_disk=500
    local available=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    local used=$(df -BG / | awk 'NR==2 {print $3}' | tr -d 'G')
    local total=$(df -BG / | awk 'NR==2 {print $2}' | tr -d 'G')
    show_progress $used $total "Disk usage (${available}GB available)"
    if [[ $available -lt $min_disk ]]; then
        log_warn "Disk space may be insufficient (recommended ${min_disk}GB, available ${available}GB)"
        STORAGE_WARNING="Disk space low: ${available}GB available, ${min_disk}GB recommended"
    else
        log_info "Storage OK (${available}GB available)"
    fi
    echo ""
    return 0
}

check_network() {
    log_step "Checking network connectivity"
    echo ""
    local check_passed=true current=0 total=2
    local MIRROR_URL MIRROR_NAME
    if [[ "$REGION" == "cn" ]]; then
        MIRROR_URL="http://mirrors.cernet.edu.cn/ubuntu/"
        MIRROR_NAME="CERNET Mirror"
    else
        MIRROR_URL="http://archive.ubuntu.com/ubuntu/"
        MIRROR_NAME="Ubuntu Official"
    fi
    ((current++))
    if curl --output /dev/null --silent --head --fail --connect-timeout 10 "$MIRROR_URL" 2>/dev/null; then
        show_progress $current $total "$MIRROR_NAME"
    else
        show_progress $current $total "$MIRROR_NAME (skipped)"
        check_passed=false
    fi
    ((current++))
    if curl --output /dev/null --silent --head --fail --connect-timeout 10 "http://security.ubuntu.com/ubuntu/" 2>/dev/null; then
        show_progress $current $total "Security Updates"
    else
        show_progress $current $total "Security Updates (skipped)"
    fi
    if $check_passed; then
        log_info "Network connectivity OK"
    else
        log_error "Network check failed"
    fi
    echo ""
    return 0
}

configure_apt_mirror() {
    log_step "Configuring APT mirror"
    echo ""

    wait_for_apt_lock || return 1

    if apt-cache show cmake > /dev/null 2>&1 && apt-cache show qemu-user-static > /dev/null 2>&1; then
        log_info "Current APT sources already have required packages, skipping mirror change"
        echo ""
        return 0
    fi

    log_warn "Current APT sources incomplete, configuring mirror..."
    sudo cp /etc/apt/sources.list /etc/apt/sources.list.bak 2>/dev/null || true

    local security_line="deb http://security.ubuntu.com/ubuntu/ jammy-security main restricted universe multiverse"
    if ! curl --output /dev/null --silent --head --fail --connect-timeout 5 "http://security.ubuntu.com/ubuntu/dists/jammy-security/Release" 2>/dev/null; then
        log_warn "security.ubuntu.com unreachable, will use mirror for security updates"
        security_line=""
    fi

    local -a MIRROR_LIST
    if [[ "$REGION" == "cn" ]]; then
        MIRROR_LIST=(
            "http://mirrors.tuna.tsinghua.edu.cn/ubuntu/|Tsinghua"
            "http://mirrors.aliyun.com/ubuntu/|Aliyun"
            "http://mirrors.cernet.edu.cn/ubuntu/|CERNET"
        )
    else
        MIRROR_LIST=(
            "http://archive.ubuntu.com/ubuntu/|Ubuntu Official"
        )
    fi

    local mirror_ok=false
    for entry in "${MIRROR_LIST[@]}"; do
        local MIRROR_URL="${entry%%|*}"
        local MIRROR_NAME="${entry##*|}"
        log_info "Trying mirror: $MIRROR_NAME"

        local sources_content="deb ${MIRROR_URL} jammy main restricted universe multiverse
deb ${MIRROR_URL} jammy-updates main restricted universe multiverse
deb ${MIRROR_URL} jammy-backports main restricted universe multiverse"
        if [[ -n "$security_line" ]]; then
            sources_content+=$'\n'"$security_line"
        else
            sources_content+=$'\n'"deb ${MIRROR_URL} jammy-security main restricted universe multiverse"
        fi

        echo "$sources_content" | sudo tee /etc/apt/sources.list > /dev/null

        wait_for_apt_lock || return 1
        sudo apt-get update -y >> "$LOG_FILE" 2>&1 &
        show_spinner $! "Updating package lists ($MIRROR_NAME)"
        local apt_ret=$?
        if [[ $apt_ret -ne 0 ]]; then
            log_warn "apt-get update failed with $MIRROR_NAME, trying next..."
            continue
        fi

        if apt-cache show cmake > /dev/null 2>&1 && apt-cache show qemu-user-static > /dev/null 2>&1; then
            log_info "APT mirror configured: $MIRROR_NAME"
            mirror_ok=true
            break
        else
            log_warn "Mirror $MIRROR_NAME package index incomplete, trying next..."
        fi
    done

    if ! $mirror_ok; then
        log_warn "All mirrors failed, restoring original sources.list"
        sudo cp /etc/apt/sources.list.bak /etc/apt/sources.list 2>/dev/null || true
        wait_for_apt_lock || return 1
        sudo apt-get update -y >> "$LOG_FILE" 2>&1 &
        show_spinner $! "Updating package lists (original)"
        if apt-cache show cmake > /dev/null 2>&1; then
            log_info "Using original APT sources"
        else
            log_error "APT package index is broken, cannot proceed"
            log_error_detail "APT sources are broken after all mirrors failed"
            return 1
      fi
    fi
    echo ""
}

install_dependencies() {
    log_step "Installing dependencies"
    echo ""

    local PACKAGES=(
        mount util-linux bash-completion vim sudo locales tzdata time rsync bc
        python3 python3-pip python2 python3-requests
        build-essential ccache
        git git-lfs ssh make gcc g++ ruby openjdk-11-jdk
        libssl-dev liblz4-tool expect patchelf chrpath gawk texinfo diffstat
        bison flex fakeroot cmake
        unzip device-tree-compiler ncurses-dev net-tools u-boot-tools dpkg-dev
        libgmp-dev libmpc-dev binutils libelf-dev curl pv
        devscripts equivs software-properties-common
        libncurses5 zip less
        fontconfig libxml2-utils gnupg
    )

    log_info "Installing ${#PACKAGES[@]} packages..."
    local apt_install_log
    apt_install_log=$(mktemp)
    CLEANUP_FILES+=("$apt_install_log")

    wait_for_apt_lock || return 1
    sudo apt-get update -y >> "$LOG_FILE" 2>&1 &
    show_spinner $! "Updating package lists"

    wait_for_apt_lock || return 1
    sudo apt-get install -y "${PACKAGES[@]}" >> "$LOG_FILE" 2>&1 &
    show_spinner $! "Installing system packages"
    local pkg_ret=$?
    echo "=== apt-get install END (exit=$pkg_ret) ===" >> "$LOG_FILE"

    # If install still failed with fetch errors, retry once with --fix-missing
    if [[ $pkg_ret -ne 0 ]]; then
        if grep -qE "(404|Failed to fetch)" "$LOG_FILE"; then
            log_warn "Some packages failed to fetch, retrying with --fix-missing..."
            wait_for_apt_lock || return 1
            sudo apt-get install -y --fix-missing "${PACKAGES[@]}" >> "$LOG_FILE" 2>&1 &
            show_spinner $! "Retrying package installation"
            pkg_ret=$?
            echo "=== apt-get install RETRY END (exit=$pkg_ret) ===" >> "$LOG_FILE"
        fi
    fi

    if [[ $pkg_ret -ne 0 ]]; then
        log_error_detail "Package installation failed" 15
        return 1
    fi
    log_info "System packages installed"

    if [[ "$REGION" == "cn" ]]; then
        pip3 install pyelftools -i https://pypi.tuna.tsinghua.edu.cn/simple >> "$LOG_FILE" 2>&1 \
            || pip3 install pyelftools --break-system-packages -i https://pypi.tuna.tsinghua.edu.cn/simple >> "$LOG_FILE" 2>&1 &
    else
        pip3 install pyelftools >> "$LOG_FILE" 2>&1 \
            || pip3 install pyelftools --break-system-packages >> "$LOG_FILE" 2>&1 &
    fi
    show_spinner $! "Installing pyelftools"
    if [[ $? -ne 0 ]]; then
        log_warn "pyelftools installation failed (non-fatal)"
    else
        log_info "pyelftools installed"
    fi

    if command -v python2 &>/dev/null && ! command -v python &>/dev/null; then
        sudo ln -sf /usr/bin/python2 /usr/bin/python
        log_info "Created symlink: python -> python2"
    fi

    log_info "All dependencies installed"
    echo ""
}

install_live_build() {
    log_step "Installing live-build"
    echo ""
    local LIVE_BUILD_DIR="/tmp/live-build-$$"
    CLEANUP_FILES+=("$LIVE_BUILD_DIR")
    git clone https://gitcode.com/TaishanPi-Rockchip/live-build.git -b "debian/1%20230131" "$LIVE_BUILD_DIR" >> "$LOG_FILE" 2>&1 &
    show_spinner $! "Cloning live-build"
    local clone_ret=$?
    if [[ $clone_ret -ne 0 ]]; then
        log_error_detail "Failed to clone live-build"
        return 1
    fi
    pushd "$LIVE_BUILD_DIR" > /dev/null
    rm -rf manpages/po/
    sudo make install >> "$LOG_FILE" 2>&1 &
    show_spinner $! "Installing live-build"
    local make_ret=$?
    popd > /dev/null
    rm -rf "$LIVE_BUILD_DIR"
    if [[ $make_ret -ne 0 ]]; then
        log_error_detail "Failed to install live-build (make install)"
        return 1
    fi
    log_info "live-build installed successfully"
    echo ""
}

load_kernel_modules() {
    log_step "Loading kernel modules"
    echo ""
    local modules=(overlay veth bridge)
    for mod in "${modules[@]}"; do
        if command -v lsmod &>/dev/null; then
            if lsmod | grep -q "^${mod}[[:space:]]"; then
                log_debug "Module already loaded: $mod"
                continue
            fi
        fi
        if ! sudo modprobe "$mod" 2>/dev/null; then
            log_debug "Module not available: $mod (non-critical)"
            continue
        fi
        log_debug "Module loaded: $mod"
    done
    log_info "Kernel modules checked"
    echo ""
}

configure_qemu() {
    log_step "Configuring QEMU for aarch64 emulation"
    echo ""
    if ! command -v update-binfmts &>/dev/null; then
        log_warn "binfmt-support not found, installing..."
        wait_for_apt_lock || return 1
        sudo apt-get install -y binfmt-support qemu-user-static >> "$LOG_FILE" 2>&1 &
        show_spinner $! "Installing binfmt-support"
    fi
    sudo update-binfmts --enable qemu-aarch64 2>/dev/null || true
    log_info "QEMU aarch64 binfmt enabled"
    echo ""
}

configure_timezone() {
    log_step "Configuring timezone"
    echo ""
    local current_tz
    current_tz=$(timedatectl show --property=Timezone --value 2>/dev/null || echo "unknown")
    log_debug "Current timezone: $current_tz"
    if [[ "$REGION" == "cn" ]]; then
        sudo ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
        log_info "Timezone set to Asia/Shanghai"
    else
        sudo ln -sf /usr/share/zoneinfo/UTC /etc/localtime
        log_info "Timezone set to UTC"
    fi
    echo ""
}

check_qemu() {
    log_step "Verifying QEMU setup"
    echo ""
    if [[ ! -f /usr/bin/qemu-aarch64-static ]]; then
        log_error "qemu-aarch64-static not found"
        return 1
    fi
    log_info "qemu-aarch64-static found"
    if [[ -d /proc/sys/fs/binfmt_misc ]]; then
        if [[ -f /proc/sys/fs/binfmt_misc/qemu-aarch64 ]]; then
            log_info "binfmt_misc: qemu-aarch64 registered"
        else
            log_warn "binfmt_misc: qemu-aarch64 not registered"
        fi
    else
        log_warn "binfmt_misc not mounted"
    fi
    echo ""
}

setup_repo_tool() {
    log_step "Setting up repo tool"
    echo ""
    mkdir -p "$HOME/.bin"

    if ! grep -q "TaishanPi-repo" "$HOME/.bashrc" 2>/dev/null; then
        cat >> "$HOME/.bashrc" <<'BASHRC_EOF'
# TaishanPi-repo - repo tool configuration
export PATH="$HOME/.bin:$PATH"
export REPO_URL="https://cnb.cool/jlckfb/git-repo"
export REPO_REV="main"
BASHRC_EOF
        log_info "Added repo config to ~/.bashrc"
    else
        log_debug "Repo config already in ~/.bashrc"
    fi

    export PATH="$HOME/.bin:$PATH"
    export REPO_URL="https://cnb.cool/jlckfb/git-repo"
    export REPO_REV="main"

    curl -fL "$REPO_DOWNLOAD_URL" -o "$HOME/.bin/repo" >> "$LOG_FILE" 2>&1 &
    show_spinner $! "Downloading repo tool"
    local dl_ret=$?
    if [[ $dl_ret -ne 0 ]]; then
        log_error "Failed to download repo tool"
        return 1
    fi
    if ! head -1 "$HOME/.bin/repo" | grep -q python; then
        log_error "Downloaded repo file is not a valid Python script"
        return 1
    fi
    chmod a+rx "$HOME/.bin/repo"
    log_info "Repo tool installed to ~/.bin/repo"
    echo ""
}

clone_sdk() {
    log_step "Cloning TaishanPi-3 SDK"
    echo ""
    SDK_DIR="$PWD/TaishanPi-3-Android14"
    mkdir -p "$SDK_DIR"
    pushd "$SDK_DIR" > /dev/null

    echo -e "${CYAN}  SDK requires ~30GB disk space${NC}"
    echo -e "${CYAN}  Estimated time: 30-90 min depending on network speed${NC}"
    echo ""

    if ! git config --global user.name &>/dev/null; then
        git config --global user.name "TaishanPi Builder"
    fi
    if ! git config --global user.email &>/dev/null; then
        git config --global user.email "builder@taishanpi.local"
    fi

    echo "=== repo init START ===" >> "$LOG_FILE"
    "$HOME/.bin/repo" init -u "$MANIFEST_URL" -b "$MANIFEST_BRANCH" --manifest-depth=1 --depth=1 --no-clone-bundle < /dev/null >> "$LOG_FILE" 2>&1 &
    show_spinner $! "Initializing repo manifest"
    local init_ret=$?
    echo "=== repo init END ===" >> "$LOG_FILE"
    if [[ $init_ret -ne 0 ]]; then
        log_error_detail "repo init failed"
        popd > /dev/null
        return 1
    fi
    log_info "Repo initialized"

    # Count total projects from manifest
    local total_projects
    total_projects=$("$HOME/.bin/repo" list 2>/dev/null | wc -l)
    [[ -z "$total_projects" || "$total_projects" -eq 0 ]] && total_projects="unknown"
    log_info "Syncing SDK ($total_projects projects, this will take a while)..."

    local max_retries=3
    local sync_ret=1
    for attempt in $(seq 1 $max_retries); do
        echo "=== repo sync attempt $attempt/$max_retries START ===" >> "$LOG_FILE"

        "$HOME/.bin/repo" sync -c --no-clone-bundle -j$(nproc) >> "$LOG_FILE" 2>&1 &
        show_spinner $! "Syncing SDK repositories (attempt $attempt/$max_retries)"
        sync_ret=$?

        echo "=== repo sync attempt $attempt END (exit=$sync_ret) ===" >> "$LOG_FILE"

        if [[ $sync_ret -eq 0 ]]; then
            break
        else
            if [[ $attempt -lt $max_retries ]]; then
                local wait_secs=$((attempt * 10))
                log_warn "Sync failed (attempt $attempt/$max_retries), retrying in ${wait_secs}s..."
                sleep $wait_secs
            fi
        fi
    done

    popd > /dev/null
    if [[ $sync_ret -ne 0 ]]; then
        log_error_detail "repo sync failed after $max_retries attempts"
        return 1
    fi
    log_info "SDK cloned to $SDK_DIR"
    echo ""
}

fetch_lfs_objects() {
    log_step "Fetching Git LFS objects"
    echo ""
    SDK_DIR="$PWD/TaishanPi-3-Android14"
    local total=${#LFS_REPOS[@]}
    local current=0
    for lfs_path in "${LFS_REPOS[@]}"; do
        ((current++))
        local full_path="$SDK_DIR/$lfs_path"
        if [[ ! -d "$full_path" ]]; then
            log_warn "LFS path not found: $lfs_path"
            show_progress $current $total "$lfs_path (skipped)"
            continue
        fi
        pushd "$full_path" > /dev/null
        git lfs install --local >> "$LOG_FILE" 2>&1

        # Stream LFS progress to user while logging
        local lfs_progress_file
        lfs_progress_file=$(mktemp)
        CLEANUP_FILES+=("$lfs_progress_file")

        git lfs pull 2>&1 | tee -a "$LOG_FILE" > "$lfs_progress_file" &
        local lfs_pid=$!
        local -a lframes=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
        local si=0
        local start_ts=$SECONDS
        BG_PIDS+=("$lfs_pid")
        while kill -0 $lfs_pid 2>/dev/null; do
            si=$(( (si+1) % ${#lframes[@]} ))
            local elapsed=$(( SECONDS - start_ts ))
            local lfs_status
            lfs_status=$(tail -1 "$lfs_progress_file" 2>/dev/null | tr -d '\r' | sed 's/\x1b\[[0-9;]*m//g' | head -c 60)
            if [[ -n "$lfs_status" && "$lfs_status" == *"%"* ]]; then
                printf "\r\033[K  %s LFS (%d/%d) %s: %s [%02d:%02d]" "${lframes[$si]}" "$current" "$total" "$lfs_path" "$lfs_status" $((elapsed/60)) $((elapsed%60))
            else
                printf "\r\033[K  %s LFS (%d/%d) %s... [%02d:%02d]" "${lframes[$si]}" "$current" "$total" "$lfs_path" $((elapsed/60)) $((elapsed%60))
            fi
            sleep 0.3
        done
        wait $lfs_pid
        local lfs_ret=$?
        local new_pids=()
        for p in "${BG_PIDS[@]}"; do
            [[ "$p" != "$lfs_pid" ]] && new_pids+=("$p")
        done
        BG_PIDS=("${new_pids[@]}")
        rm -f "$lfs_progress_file"

        local elapsed=$(( SECONDS - start_ts ))
        printf "\r\033[K"
        if [[ $lfs_ret -ne 0 ]]; then
            echo -e "${RED}[ERR]${NC} LFS ($current/$total) ${lfs_path} ${RED}Failed${NC} ${DIM}($(printf '%02d:%02d' $((elapsed/60)) $((elapsed%60))))${NC}"
            log_warn "LFS pull failed: $lfs_path"
        else
            echo -e "${GREEN}[OK]${NC} LFS ($current/$total) ${lfs_path} ${DIM}($(printf '%02d:%02d' $((elapsed/60)) $((elapsed%60))))${NC}"
        fi
        popd > /dev/null
    done
    log_info "Git LFS objects fetched"
    echo ""
}

format_duration() {
    local secs=$1
    if [[ $secs -ge 3600 ]]; then
        printf "%dh%02dm%02ds" $((secs/3600)) $(((secs%3600)/60)) $((secs%60))
    elif [[ $secs -ge 60 ]]; then
        printf "%dm%02ds" $((secs/60)) $((secs%60))
    else
        printf "%ds" "$secs"
    fi
}

main() {
    local MAIN_START=$SECONDS

    print_box "TaishanPi-3 Android14 SDK Installer" "$MAGENTA"
    echo -e "${DIM}  Log file: ${LOG_FILE}${NC}"
    echo ""

    local stage_start=$SECONDS
    CURRENT_STAGE="Stage 1/5: Network Detection"
    print_box "$CURRENT_STAGE" "$BLUE"
    detect_region || return 1
    log_debug "Stage completed in $(format_duration $((SECONDS - stage_start)))"

    stage_start=$SECONDS
    CURRENT_STAGE="Stage 2/5: System Check"
    print_box "$CURRENT_STAGE" "$BLUE"
    check_sudo_available || return 1
    check_ubuntu_version || return 1
    check_cpu || return 1
    check_storage
    log_debug "Stage completed in $(format_duration $((SECONDS - stage_start)))"

    stage_start=$SECONDS
    CURRENT_STAGE="Stage 3/5: Install Dependencies"
    print_box "$CURRENT_STAGE" "$BLUE"
    configure_apt_mirror || return 1
    check_network || return 1
    install_dependencies || return 1
    log_debug "Stage completed in $(format_duration $((SECONDS - stage_start)))"

    stage_start=$SECONDS
    CURRENT_STAGE="Stage 4/5: Setup Repo"
    print_box "$CURRENT_STAGE" "$BLUE"
    setup_repo_tool || return 1
    log_debug "Stage completed in $(format_duration $((SECONDS - stage_start)))"

    stage_start=$SECONDS
    CURRENT_STAGE="Stage 5/5: Clone SDK"
    print_box "$CURRENT_STAGE" "$BLUE"
    local do_clone=""
    safe_read "Clone TaishanPi-3 Android14 SDK now? [y/N]: " do_clone
    echo ""
    if [[ "$do_clone" =~ ^[Yy]$ ]]; then
        clone_sdk || return 1
    else
        log_warn "SDK clone skipped by user"
        echo ""
    fi
    log_debug "Stage completed in $(format_duration $((SECONDS - stage_start)))"

    local total_duration=$(format_duration $((SECONDS - MAIN_START)))
    if $ALL_CHECKS_PASS; then
        print_box "Installation Complete! All stages passed." "$GREEN"
        log_info "SDK location: $SDK_DIR"
        log_info "To start building, cd into the SDK directory"
    else
        print_box "Installation finished with warnings." "$YELLOW"
        log_warn "Some checks did not pass. Review the output above."
    fi
    log_info "Total time: $total_duration"
    log_info "Full log: $LOG_FILE"
    if [[ -n "$STORAGE_WARNING" ]]; then
        log_warn "$STORAGE_WARNING"
    fi
    return 0
}

ALL_CHECKS_PASS=true
main "$@"
main_ret=$?
if [[ $main_ret -ne 0 ]]; then
    fail_summary
fi
exit $main_ret