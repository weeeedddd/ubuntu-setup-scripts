#!/bin/bash

set -e

LOGFILE="$HOME/ubuntu-setup-$(date +%Y%m%d_%H%M%S).log"
SCRIPT_URL="https://raw.githubusercontent.com/weeeedddd/ubuntu-setup-scripts/main/VazeAP.sh"

# Fancy ASCII Art Banner for VazeAP
print_banner() {
  cat << "EOF"
__     ______  _    _   _      ____   _____ _____ 
\ \   / / __ \| |  | | | |    / __ \ / ____|  __ \
 \ \_/ / |  | | |  | | | |   | |  | | (___ | |__) |
  \   /| |  | | |  | | | |   | |  | |\___ \|  ___/
   | | | |__| | |__| | | |___| |__| |____) | |    
   |_|  \____/ \____/  |______\____/|_____/|_|    
                                                 
            VazeAP Setup Script
EOF
  echo
}

# Function for Update Check & Self-Update
check_update() {
  echo "Checking for updates..."
  TMPFILE=$(mktemp)
  curl -fsSL "$SCRIPT_URL" -o "$TMPFILE" || { echo "Failed to check update"; return 1; }

  DIFF=$(diff "$0" "$TMPFILE" || true)
  if [ -n "$DIFF" ]; then
    whiptail --yesno "A new version of this setup script is available. Update now?" 10 60
    if [ $? -eq 0 ]; then
      echo "Updating script..."
      chmod +x "$TMPFILE"
      exec "$TMPFILE" "$@"
      exit 0
    else
      echo "Continuing with current version."
    fi
  else
    echo "You have the latest version."
  fi

  rm -f "$TMPFILE"
}

# Progress bar helper
progress() {
  echo "XXX"
  echo "$1"
  echo "$2"
  echo "XXX"
}

# Fix MariaDB / MySQL dependency issues before installing
fix_mariadb_dependencies() {
  progress 5 "Fixing MariaDB/MySQL package dependencies..."

  sudo apt update

  # Repair broken dependencies
  sudo apt --fix-broken install -y
  sudo apt-get install -f -y
  sudo dpkg --configure -a

  # Remove conflicting MySQL packages that might cause issues
  sudo apt remove --purge -y mysql-client-core-8.0 mysql-client mysql-server mysql-common || true
  sudo apt autoremove -y

  # Unhold held packages if any
  HELD_PACKAGES=$(sudo apt-mark showhold)
  if [ -n "$HELD_PACKAGES" ]; then
    echo "Unholding packages: $HELD_PACKAGES"
    sudo apt-mark unhold $HELD_PACKAGES
  fi

  sudo apt update
  sudo apt upgrade -y

  progress 10 "Dependency fix completed."
}

install_minimal() {
  progress 15 "Updating system and installing core tools..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y curl wget git unzip zip htop net-tools software-properties-common build-essential neofetch ufw
}

install_java() {
  progress 30 "Installing Java 8, 11, 17, 21..."
  sudo add-apt-repository ppa:openjdk-r/ppa -y
  sudo apt update
  sudo apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk openjdk-21-jdk
}

install_webdev() {
  progress 50 "Installing Web Development tools (Python3, Node.js, Docker)..."
  sudo apt install -y python3 python3-pip nodejs npm docker.io docker-compose
  sudo usermod -aG docker $USER
}

install_datasci() {
  fix_mariadb_dependencies

  progress 70 "Installing Data Science tools (Python3, Jupyter, DBs)..."
  sudo apt install -y python3 python3-pip jupyter-notebook mariadb-server mariadb-client postgresql sqlite3 default-mysql-client
}

install_media() {
  progress 85 "Installing Media & UI tools..."
  sudo apt install -y vlc gimp obs-studio qbittorrent gparted
}

install_perf() {
  progress 95 "Applying performance tweaks..."
  sudo apt install -y zram-tools
  sudo systemctl enable zramswap --now
  echo 'vm.swappiness=20' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
}

install_vscode() {
  progress 99 "Installing Visual Studio Code..."
  sudo snap install code --classic || echo "?? VS Code installation failed"
}

install_pterodactyl() {
  whiptail --yesno "Do you want to install Pterodactyl Panel?" 8 60
  if [ $? -eq 0 ]; then
    progress 20 "Installing Pterodactyl Panel prerequisites..."
    sudo apt install -y nginx mariadb-server mariadb-client php php-fpm php-mysql php-redis php-cli php-curl php-mbstring php-zip php-bcmath unzip curl tar git redis-server
    # Add your full Pterodactyl install commands here or call an install script
    progress 40 "Pterodactyl Panel installation started..."
    # Placeholder: you can insert your actual Pterodactyl install steps here
    echo "Pterodactyl install logic goes here..."
  else
    echo "Skipping Pterodactyl installation."
  fi
}

main() {
  print_banner

  check_update "$@"

  exec > >(tee -a "$LOGFILE") 2>&1

  # Ask sudo password upfront
  sudo -v

  # Install required basic tools
  for pkg in whiptail dialog curl; do
    if ! command -v $pkg &> /dev/null; then
      echo "Installing $pkg..."
      sudo apt install -y $pkg
    fi
  done

  PROFILE=$(whiptail --title "Ubuntu Setup Profiles" --menu "Choose a profile to install:" 15 60 5 \
  "minimal" "Minimal - only essentials" \
  "webdev" "Web Development (Node, Python, Docker)" \
  "datasci" "Data Science (Python, Jupyter, DBs)" \
  "fullstack" "Full Stack (everything + media + performance tweaks)" \
  "pterodactyl" "Pterodactyl Panel Installer (optional)" 3>&1 1>&2 2>&3)

  if [ $? -ne 0 ]; then
    echo "Setup canceled."
    exit 1
  fi

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
    pterodactyl)
      install_pterodactyl
      ;;
    *)
      echo "Invalid option."
      exit 1
      ;;
  esac

  progress 100 "Setup complete!"

  whiptail --title "Setup finished" --msgbox "? Setup for profile '$PROFILE' complete!\n\nLog saved to:\n$LOGFILE\n\nPlease reboot to apply changes." 12 60
}

main "$@"
