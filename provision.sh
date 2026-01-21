#!/bin/bash
set -euo pipefail

#------------------------------------------------------------------------------
# provision.sh - Prepare system for Ansible workstation provisioning
#------------------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SUDOERS_FILE="/etc/sudoers.d/ansible-provision"
CURRENT_USER="${SUDO_USER:-$USER}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#------------------------------------------------------------------------------
# Helper Functions
#------------------------------------------------------------------------------

log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }
log_warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

die() {
    log_error "$*"
    exit 1
}

require_root() {
    if [[ $EUID -ne 0 ]]; then
        die "This script must be run with sudo or as root"
    fi
}

#------------------------------------------------------------------------------
# OS Detection
#------------------------------------------------------------------------------

detect_os() {
    if [[ ! -f /etc/os-release ]]; then
        die "Cannot detect OS: /etc/os-release not found"
    fi

    source /etc/os-release

    OS_ID="${ID:-unknown}"
    OS_ID_LIKE="${ID_LIKE:-}"
    OS_VERSION="${VERSION_ID:-}"
    OS_NAME="${PRETTY_NAME:-$OS_ID}"

    # Determine OS family
    case "$OS_ID" in
        ubuntu|pop|linuxmint|elementary|zorin)
            OS_FAMILY="debian"
            ;;
        debian)
            OS_FAMILY="debian"
            ;;
        fedora)
            OS_FAMILY="rhel"
            ;;
        rhel|centos|rocky|almalinux|oracle)
            OS_FAMILY="rhel"
            ;;
        arch|manjaro|endeavouros)
            OS_FAMILY="arch"
            ;;
        opensuse*|sles)
            OS_FAMILY="suse"
            ;;
        *)
            # Fallback to ID_LIKE
            if [[ "$OS_ID_LIKE" == *"debian"* || "$OS_ID_LIKE" == *"ubuntu"* ]]; then
                OS_FAMILY="debian"
            elif [[ "$OS_ID_LIKE" == *"rhel"* || "$OS_ID_LIKE" == *"fedora"* ]]; then
                OS_FAMILY="rhel"
            elif [[ "$OS_ID_LIKE" == *"arch"* ]]; then
                OS_FAMILY="arch"
            elif [[ "$OS_ID_LIKE" == *"suse"* ]]; then
                OS_FAMILY="suse"
            else
                die "Unsupported OS: $OS_ID (ID_LIKE: $OS_ID_LIKE)"
            fi
            ;;
    esac

    log_info "Detected OS: $OS_NAME"
    log_info "OS Family: $OS_FAMILY"
}

#------------------------------------------------------------------------------
# Package Installation
#------------------------------------------------------------------------------

install_packages_debian() {
    log_info "Updating apt cache..."
    apt-get update -qq

    log_info "Installing packages..."
    apt-get install -y \
        ansible \
        ansible-lint \
        git \
        python3 \
        python3-pip \
        python3-venv \
        curl \
        wget \
        jq \
        tree \
        sshpass \
        coreutils \
        ca-certificates \
        gnupg \
        lsb-release \
        software-properties-common
}

install_packages_rhel() {
    log_info "Installing EPEL repository (if needed)..."
    if [[ "$OS_ID" != "fedora" ]]; then
        dnf install -y epel-release || true
    fi

    log_info "Installing packages..."
    dnf install -y \
        ansible \
        ansible-lint \
        git \
        python3 \
        python3-pip \
        curl \
        wget \
        jq \
        tree \
        sshpass \
        coreutils \
        ca-certificates
}

install_packages_arch() {
    log_info "Updating pacman database..."
    pacman -Sy --noconfirm

    log_info "Installing packages..."
    pacman -S --noconfirm --needed \
        ansible \
        ansible-lint \
        git \
        python \
        python-pip \
        curl \
        wget \
        jq \
        tree \
        sshpass \
        coreutils \
        ca-certificates
}

install_packages_suse() {
    log_info "Refreshing zypper repositories..."
    zypper refresh

    log_info "Installing packages..."
    zypper install -y \
        ansible \
        git \
        python3 \
        python3-pip \
        curl \
        wget \
        jq \
        tree \
        sshpass \
        coreutils \
        ca-certificates
}

install_packages() {
    case "$OS_FAMILY" in
        debian) install_packages_debian ;;
        rhel)   install_packages_rhel ;;
        arch)   install_packages_arch ;;
        suse)   install_packages_suse ;;
        *)      die "Unknown OS family: $OS_FAMILY" ;;
    esac

    log_success "Packages installed successfully"
}

#------------------------------------------------------------------------------
# Sudoers Configuration
#------------------------------------------------------------------------------

configure_sudoers() {
    log_info "Configuring passwordless sudo for user: $CURRENT_USER"

    # Validate username
    if ! id "$CURRENT_USER" &>/dev/null; then
        die "User '$CURRENT_USER' does not exist"
    fi

    # Create sudoers entry
    echo "$CURRENT_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_FILE"
    chmod 0440 "$SUDOERS_FILE"

    # Validate sudoers syntax
    if ! visudo -c -f "$SUDOERS_FILE" &>/dev/null; then
        rm -f "$SUDOERS_FILE"
        die "Invalid sudoers syntax - file removed"
    fi

    log_success "Sudoers configured: $SUDOERS_FILE"
    log_warn "Remember to remove this after provisioning: sudo rm $SUDOERS_FILE"
}

#------------------------------------------------------------------------------
# Ansible Galaxy Requirements
#------------------------------------------------------------------------------

install_ansible_requirements() {
    local requirements_file="$SCRIPT_DIR/requirements.yml"

    if [[ -f "$requirements_file" ]]; then
        log_info "Installing Ansible Galaxy requirements..."
        sudo -u "$CURRENT_USER" ansible-galaxy install -r "$requirements_file" --force
        log_success "Ansible Galaxy requirements installed"
    else
        log_warn "No requirements.yml found, skipping Galaxy install"
    fi
}

#------------------------------------------------------------------------------
# Run Ansible Playbook
#------------------------------------------------------------------------------

run_playbook() {
    local extra_vars_file="$1"
    local playbook="$SCRIPT_DIR/setup.yml"
    local inventory="$SCRIPT_DIR/inventory.yml"

    # Validate files exist
    [[ -f "$playbook" ]] || die "Playbook not found: $playbook"
    [[ -f "$inventory" ]] || die "Inventory not found: $inventory"
    [[ -f "$extra_vars_file" ]] || die "Extra vars file not found: $extra_vars_file"

    log_info "Running Ansible playbook..."
    log_info "  Playbook: $playbook"
    log_info "  Inventory: $inventory"
    log_info "  Extra vars: $extra_vars_file"

    # Run as the original user, not root
    sudo -u "$CURRENT_USER" ansible-playbook \
        -i "$inventory" \
        "$playbook" \
        -e "@$extra_vars_file" \
        -v

    log_success "Playbook completed successfully"
}

#------------------------------------------------------------------------------
# Cleanup
#------------------------------------------------------------------------------

cleanup_sudoers() {
    if [[ -f "$SUDOERS_FILE" ]]; then
        rm -f "$SUDOERS_FILE"
        log_success "Removed temporary sudoers file: $SUDOERS_FILE"
    fi
}

#------------------------------------------------------------------------------
# Usage
#------------------------------------------------------------------------------

usage() {
    cat <<EOF
Usage: sudo $(basename "$0") [OPTIONS]

Prepare system for Ansible workstation provisioning.

OPTIONS:
    -h, --help              Show this help message
    -e, --extra-vars FILE   Run playbook with specified extra-vars file
    -c, --cleanup           Remove temporary sudoers file and exit
    -s, --skip-packages     Skip package installation
    -n, --no-sudoers        Skip sudoers configuration

EXAMPLES:
    # Just install dependencies and configure sudoers
    sudo ./$(basename "$0")

    # Install deps and run playbook with extra vars
    sudo ./$(basename "$0") -e os_vars/kubuntu_25.10_extra-vars.yml

    # Cleanup after provisioning
    sudo ./$(basename "$0") --cleanup

AVAILABLE EXTRA-VARS FILES:
EOF
    if [[ -d "$SCRIPT_DIR/os_vars" ]]; then
        for f in "$SCRIPT_DIR/os_vars"/*.yml; do
            [[ -f "$f" ]] && echo "    - os_vars/$(basename "$f")"
        done
    fi
}

#------------------------------------------------------------------------------
# Main
#------------------------------------------------------------------------------

main() {
    local extra_vars_file=""
    local skip_packages=false
    local skip_sudoers=false
    local cleanup_only=false

    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -h|--help)
                usage
                exit 0
                ;;
            -e|--extra-vars)
                [[ -z "${2:-}" ]] && die "Missing argument for $1"
                extra_vars_file="$2"
                shift 2
                ;;
            -c|--cleanup)
                cleanup_only=true
                shift
                ;;
            -s|--skip-packages)
                skip_packages=true
                shift
                ;;
            -n|--no-sudoers)
                skip_sudoers=true
                shift
                ;;
            *)
                die "Unknown option: $1 (use -h for help)"
                ;;
        esac
    done

    require_root

    # Cleanup mode
    if [[ "$cleanup_only" == true ]]; then
        cleanup_sudoers
        exit 0
    fi

    echo ""
    echo "=========================================="
    echo "  Workstation Provisioning Setup"
    echo "=========================================="
    echo ""

    # Detect OS
    detect_os

    # Install packages
    if [[ "$skip_packages" == false ]]; then
        install_packages
    else
        log_info "Skipping package installation"
    fi

    # Configure sudoers
    if [[ "$skip_sudoers" == false ]]; then
        configure_sudoers
    else
        log_info "Skipping sudoers configuration"
    fi

    # Install Galaxy requirements
    # install_ansible_requirements

    # Run playbook if extra-vars provided
    if [[ -n "$extra_vars_file" ]]; then
        # Convert relative path to absolute
        if [[ ! "$extra_vars_file" = /* ]]; then
            extra_vars_file="$SCRIPT_DIR/$extra_vars_file"
        fi
        run_playbook "$extra_vars_file"
        cleanup_sudoers
    else
        echo ""
        log_info "Setup complete. To run the playbook manually:"
        echo ""
        echo "    ansible-playbook -i inventory.yml setup.yml -e \"@os_vars/<your-os>_extra-vars.yml\""
        echo ""
        log_warn "Don't forget to cleanup after provisioning:"
        echo ""
        echo "    sudo rm $SUDOERS_FILE"
        echo ""
    fi
}

main "$@"
