#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

LOGFILE="$HOME/ubuntu-setup-$(date +%Y%m%d_%H%M%S).log"
SCRIPT_URL="https://raw.githubusercontent.com/weeeedddd/ubuntu-setup-scripts/main/VazeAP.sh"

# ASCII Art Logo (VazeAP) - fallback if figlet missing
print_logo() {
cat << "EOF"
 __     ______  _    _   _      ____   ___   ____  
 \ \   / / __ \| |  | | | |    / __ \ / _ \ / __ \ 
  \ \_/ / |  | | |  | | | |   | |  | | | | | |  | |
   \   /| |  | | |  | | | |   | |  | | | | | |  | |
    | | | |__| | |__| | | |___| |__| | |_| | |__| |
    |_|  \____/ \____/  |______\____/ \___/ \____/ 
                                                  
EOF
}

# Progress bar function
progress_bar() {
  local progress=$1
  local width=40
  local filled=$(( progress * width / 100 ))
  local empty=$(( width - filled ))
  local bar="$(printf "%${filled}s" | tr ' ' '#')$(printf "%${empty}s" | tr ' ' '-')"
  echo -ne "[${bar}] ${progress}%\r"
}

# Check for script update
check_update() {
  echo -e "${CYAN}Checking for updates...${NC}"
  TMPFILE=$(mktemp)
  curl -fsSL "$SCRIPT_URL" -o "$TMPFILE" || { echo -e "${RED}Failed to check update${NC}"; return 1; }

  DIFF=$(diff "$0" "$TMPFILE" || true)
  if [ -n "$DIFF" ]; then
    if whiptail --yesno "A new version of this script is available. Update now?" 10 60; then
      echo -e "${YELLOW}Updating script...${NC}"
      chmod +x "$TMPFILE"
      exec "$TMPFILE" "$@"
      exit 0
    else
      echo -e "${YELLOW}Continuing with current version...${NC}"
    fi
  else
    echo -e "${GREEN}You already have the latest version.${NC}"
  fi
  rm -f "$TMPFILE"
}

# Installation functions

install_minimal() {
  echo -e "${CYAN}\n[Minimal] Updating system & installing core tools...${NC}"
  progress_bar 10; sudo apt update && sudo apt upgrade -y
  progress_bar 30; sudo apt install -y curl wget git unzip zip htop net-tools software-properties-common build-essential neofetch ufw
  progress_bar 50
  echo -e "\n${GREEN}[Minimal] Done.${NC}"
}

install_java() {
  echo -e "${CYAN}\n[Java] Installing OpenJDK versions 8,11,17,21...${NC}"
  progress_bar 55; sudo add-apt-repository ppa:openjdk-r/ppa -y
  progress_bar 60; sudo apt update
  progress_bar 70; sudo apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk openjdk-21-jdk
  progress_bar 80
  echo -e "\n${GREEN}[Java] Done.${NC}"
}

install_webdev() {
  echo -e "${CYAN}\n[WebDev] Installing Python3, NodeJS, Docker...${NC}"
  progress_bar 60; sudo apt install -y python3 python3-pip nodejs npm docker.io docker-compose
  progress_bar 80; sudo usermod -aG docker $USER
  progress_bar 90
  echo -e "\n${GREEN}[WebDev] Done.${NC}"
}

install_datasci() {
  echo -e "${CYAN}\n[Data Science] Installing Python3, Jupyter & databases...${NC}"
  progress_bar 60; sudo apt install -y python3 python3-pip jupyter-notebook default-mysql-client mariadb-server postgresql sqlite3
  progress_bar 80
  echo -e "\n${GREEN}[Data Science] Done.${NC}"
}

install_media() {
  echo -e "${CYAN}\n[Media] Installing multimedia tools...${NC}"
  progress_bar 70; sudo apt install -y vlc gimp obs-studio qbittorrent gparted
  progress_bar 85
  echo -e "\n${GREEN}[Media] Done.${NC}"
}

install_perf() {
  echo -e "${CYAN}\n[Performance] Applying performance tweaks...${NC}"
  progress_bar 80; sudo apt install -y zram-tools
  sudo systemctl enable zramswap --now
  echo 'vm.swappiness=20' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  progress_bar 95
  echo -e "\n${GREEN}[Performance] Done.${NC}"
}

install_vscode() {
  echo -e "${CYAN}\n[VS Code] Installing...${NC}"
  if sudo snap install code --classic; then
    progress_bar 100
    echo -e "\n${GREEN}[VS Code] Done.${NC}"
  else
    echo -e "\n${RED}[VS Code] Installation failed.${NC}"
  fi
}

install_pterodactyl() {
  echo -e "${CYAN}\n[Pterodactyl] Installing Panel and Wings...${NC}"
  progress_bar 0

  # System update & dependencies
  sudo apt update && sudo apt upgrade -y
  progress_bar 20

  sudo apt install -y php php-cli php-fpm php-mysql php-zip php-gd php-mbstring php-curl php-bcmath php-xml php-tokenizer php-json mariadb-server nginx redis-server unzip git curl
  progress_bar 40

  # Example Panel install (customize needed!)
  cd /var/www || exit
  sudo git clone https://github.com/pterodactyl/panel.git pterodactyl
  cd pterodactyl || exit
  sudo cp .env.example .env
  # Note: Configure your .env, create database etc.
  progress_bar 60

  # Wings installation
  curl -Lo wings.tar.gz https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64.tar.gz
  tar -xzf wings.tar.gz -C /usr/local/bin wings
  sudo chmod +x /usr/local/bin/wings
  progress_bar 90

  echo -e "${GREEN}\n[Pterodactyl] Installation complete!${NC}"
  progress_bar 100
  echo
}

# Script start

clear
print_logo

check_update "$@"

exec > >(tee -a "$LOGFILE") 2>&1

sudo -v

# Ensure required tools installed
for pkg in whiptail dialog curl figlet; do
  if ! command -v $pkg &> /dev/null; then
    echo -e "${YELLOW}Installing $pkg...${NC}"
    sudo apt install -y $pkg
  fi
done

# Profile selection
PROFILE=$(whiptail --title "Ubuntu Setup Profiles" --menu "Choose a profile:" 15 60 5 \
"minimal" "Minimal - essentials only" \
"webdev" "Web Development (Node, Python, Docker)" \
"datasci" "Data Science (Python, Jupyter, DBs)" \
"fullstack" "Full Stack (everything + media + performance)" \
"custom" "Custom (with Pterodactyl option)" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo -e "${RED}Setup cancelled.${NC}"
  exit 1
fi

# Ask if user wants Pterodactyl installed
if whiptail --title "Pterodactyl Installation" --yesno "Do you want to install Pterodactyl Panel and Wings?" 8 60; then
  INSTALL_PTERODACTYL=true
else
  INSTALL_PTERODACTYL=false
fi

# Run install functions per profile
case $PROFILE in
  minimal)
    install_minimal
    install_java
    install_vscode
    ;;
  webdev)
    install_minimal
    install_java
    install_webdev
    install_vscode
    ;;
  datasci)
    install_minimal
    install_java
    install_datasci
    install_vscode
    ;;
  fullstack)
    install_minimal
    install_java
    install_webdev
    install_datasci
    install_media
    install_perf
    install_vscode
    ;;
  custom)
    # Custom profile: minimal + optional modules
    install_minimal
    install_java
    if whiptail --yesno "Install Web Development tools?" 8 50; then
      install_webdev
    fi
    if whiptail --yesno "Install Data Science tools?" 8 50; then
      install_datasci
    fi
    if whiptail --yesno "Install Media tools?" 8 50; then
      install_media
    fi
    if whiptail --yesno "Apply Performance tweaks?" 8 50; then
      install_perf
    fi
    install_vscode
    ;;
  *)
    echo -e "${RED}Invalid option.${NC}"
    exit 1
    ;;
esac

# Optional Pterodactyl installation
if [ "$INSTALL_PTERODACTYL" = true ]; then
  install_pterodactyl
fi

echo -e "\n${GREEN}? Setup for profile '$PROFILE' completed! Log saved at:\n$LOGFILE${
