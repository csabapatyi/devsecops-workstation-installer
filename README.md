# DevSecOps Workstation Installer

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

A ready-to-use installer for provisioning DevSecOps workstations using the [csabapatyi.devsecops_workstation](https://github.com/csabapatyi/ansible-role-devsecops-workstation) Ansible role.

This repository provides example configurations for multiple Linux distributions, making it easy to bootstrap a fully-featured development workstation with a single command.

## Supported Platforms

| Platform | Configuration File | Status |
|----------|-------------------|--------|
| Ubuntu 24.04 LTS | `os_vars/ubuntu_24.04_extra-vars.yml` | ✅ Tested |
| Ubuntu 25.10 | `os_vars/ubuntu_25.10_extra-vars.yml` | ✅ Tested |
| Fedora 42 | `os_vars/fedora_42_extra-vars.yml` | ✅ Tested |
| Fedora 43 | `os_vars/fedora_43_extra-vars.yml` | ✅ Tested |
| Arch Linux | `os_vars/archlinux_extra-vars.yml` | ✅ Tested |
| openSUSE Tumbleweed | `os_vars/opensuse_tumbleweed_extra-vars.yml` | ✅ Tested |
| WSL Ubuntu | `os_vars/wsl_ubuntu_extra-vars.yml` | ✅ Tested |

## Quick Start

### Prerequisites

- A fresh Linux installation (or WSL2)
- `sudo` access
- Internet connection

### Installation

#### Option 1: Automated Setup (Recommended)

The `provision.sh` script handles everything automatically:

```bash
# Clone this repository
git clone https://github.com/csabapatyi/devsecops-workstation-installer.git
cd devsecops-workstation-installer

# Run the provisioning script with your OS configuration
sudo ./provision.sh -e os_vars/ubuntu_24.04_extra-vars.yml
```

The script will:
1. Detect your operating system
2. Install Ansible and required dependencies
3. Configure temporary passwordless sudo
4. Install the Ansible role from GitHub
5. Run the playbook with your configuration
6. Clean up temporary sudo access

#### Option 2: Manual Setup

If you prefer more control, follow these steps:

```bash
# 1. Install Ansible (example for Ubuntu/Debian)
sudo apt update
sudo apt install -y ansible git python3-pip

# 2. Clone this repository
git clone https://github.com/csabapatyi/devsecops-workstation-installer.git
cd devsecops-workstation-installer

# 3. Install the Ansible role and collections
ansible-galaxy install -r requirements.yml

# 4. Copy and customize the configuration for your OS
cp os_vars/ubuntu_24.04_extra-vars.yml os_vars/my_config.yml
# Edit os_vars/my_config.yml with your preferences

# 5. Run the playbook
ansible-playbook -i inventory.yml setup.yml -e "@os_vars/my_config.yml" --ask-become-pass
```

## Installing the Ansible Role

The role is installed from GitHub. To install it manually:

```bash
# Install role and required collections
ansible-galaxy install -r requirements.yml

# Or install the role directly
ansible-galaxy install git+https://github.com/csabapatyi/ansible-role-devsecops-workstation.git,main
```

The `requirements.yml` file specifies:
- The `csabapatyi.devsecops_workstation` role from GitHub
- Required Ansible collections (`community.general`, `ansible.posix`)

## Configuration

### Customizing Your Setup

1. Copy the example configuration for your OS:
   ```bash
   cp os_vars/ubuntu_24.04_extra-vars.yml os_vars/my_workstation.yml
   ```

2. Edit the file to customize:
   - Username and shell preference
   - Container engine (Docker/Podman)
   - Virtualization provider (libvirt/VirtualBox)
   - System packages to install
   - Flatpak applications
   - VS Code extensions
   - Cloud CLI tools (AWS, Azure, GCP)
   - And much more...

3. Run the playbook with your configuration:
   ```bash
   ansible-playbook -i inventory.yml setup.yml -e "@os_vars/my_workstation.yml" --ask-become-pass
   ```

### Key Configuration Options

| Category | Variables | Description |
|----------|-----------|-------------|
| **User** | `workstation_user`, `workstation_user_shell` | User account configuration |
| **Containers** | `container_engine` | `docker`, `podman`, or `none` |
| **Virtualization** | `virtualization_provider` | `libvirt`, `virtualbox`, or `none` |
| **Packages** | `system_packages`, `flatpak_packages` | Software to install |
| **VS Code** | `vscode_install_method`, `vscode_extensions` | Editor configuration |
| **Cloud CLIs** | `install_aws_cli`, `install_azure_cli`, etc. | Cloud tool installation |
| **Shell** | `install_starship`, `custom_shell_content` | Shell customization |
| **Dotfiles** | `dotfiles_repo`, `dotfiles_dest` | Dotfiles management |

For a complete list of variables, see the [role documentation](https://github.com/csabapatyi/ansible-role-devsecops-workstation#role-variables).

## Repository Structure

```
.
├── ansible.cfg          # Ansible configuration
├── inventory.yml        # Inventory file (localhost)
├── LICENSE              # MIT License
├── os_vars/             # OS-specific configuration examples
│   ├── archlinux_extra-vars.yml
│   ├── fedora_42_extra-vars.yml
│   ├── fedora_43_extra-vars.yml
│   ├── opensuse_tumbleweed_extra-vars.yml
│   ├── ubuntu_24.04_extra-vars.yml
│   ├── ubuntu_25.10_extra-vars.yml
│   └── wsl_ubuntu_extra-vars.yml
├── provision.sh         # Automated provisioning script
├── README.md            # This file
├── requirements.yml     # Ansible Galaxy requirements
└── setup.yml            # Main playbook
```

## WSL (Windows Subsystem for Linux)

For WSL users, there are some special considerations:

- **No GPU drivers**: WSL uses Windows GPU drivers via WSLg
- **Docker**: Use Docker Desktop for Windows with WSL2 backend (recommended)
- **VS Code**: Install VS Code on Windows and use the "Remote - WSL" extension
- **No virtualization**: VirtualBox/libvirt are not supported inside WSL
- **Fonts**: Install Nerd Fonts on Windows, not in WSL

See `os_vars/wsl_ubuntu_extra-vars.yml` for a WSL-optimized configuration.

## Troubleshooting

### Permission Denied Errors

Ensure you're running with `--ask-become-pass` or have passwordless sudo configured:

```bash
ansible-playbook -i inventory.yml setup.yml -e "@os_vars/my_config.yml" --ask-become-pass
```

### Role Not Found

Install the role first:

```bash
ansible-galaxy install -r requirements.yml --force
```

### Package Not Found

Some packages have different names across distributions. Check the OS-specific example files for correct package names.

### Cleanup After Provisioning

If you used `provision.sh`, temporary sudo access was automatically removed. To manually remove it:

```bash
sudo rm /etc/sudoers.d/ansible-provision
```

## Contributing

1. Fork this repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Author

Created by **Csaba Patyi** - DevSecOps Consultant and Cloud Solution Architect.

## Related Projects

- [ansible-role-devsecops-workstation](https://github.com/csabapatyi/ansible-role-devsecops-workstation) - The Ansible role used by this installer