# VazeAP Ubuntu Setup Script

![VazeAP Banner](https://raw.githubusercontent.com/weeeedddd/ubuntu-setup-scripts/main/banner.png)

## English Version

This script automates the setup of your Ubuntu server with profiles tailored for various use cases:

- **Minimal**: Basic essentials only
- **WebDev**: Node.js, Python, Docker, etc.
- **Data Science**: Python, Jupyter, MariaDB, PostgreSQL
- **Fullstack**: Everything + media apps + performance & security tweaks

### Features

- Installs multiple Java versions (8,11,17,21)
- Optional Pterodactyl Panel & Wings installer
- Optional DDOS protection & security hardening (iptables, sysctl)
- Performance tweaks: zRAM, kernel tuning, memory optimizations
- Interactive menu with progress bar and professional ASCII art banner

### How to Use

```bash
curl -o setup.sh https://raw.githubusercontent.com/weeeedddd/ubuntu-setup-scripts/main/VazeAP.sh
chmod +x setup.sh
./setup.sh
