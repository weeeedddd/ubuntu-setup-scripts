#!/bin/bash

set -e

LOGFILE="$HOME/ubuntu-setup-$(date +%Y%m%d_%H%M%S).log"
SCRIPT_URL="https://raw.githubusercontent.com/weeeedddd/ubuntu-setup-scripts/main/VazeAP.sh"

# Funktion für Update prüfen und ggf. laden
check_update() {
  echo "Checking for updates..."
  TMPFILE=$(mktemp)
  curl -fsSL "$SCRIPT_URL" -o "$TMPFILE" || { echo "Failed to check update"; return 1; }

  # Compare current script with downloaded one
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

# Check for update
check_update "$@"

exec > >(tee -a "$LOGFILE") 2>&1

# sudo einmal abfragen
sudo -v

# Check whiptail und dialog
for pkg in whiptail dialog curl; do
  if ! command -v $pkg &> /dev/null; then
    echo "Installing $pkg..."
    sudo apt install -y $pkg
  fi
done

PROFILE=$(whiptail --title "Ubuntu Setup Profiles" --menu "Choose a profile to install:" 15 60 4 \
"minimal" "Minimal - only essentials" \
"webdev" "Web Development (Node, Python, Docker)" \
"datasci" "Data Science (Python, Jupyter, DBs)" \
"fullstack" "Full Stack (everything + media + performance tweaks)" 3>&1 1>&2 2>&3)

if [ $? -ne 0 ]; then
  echo "Setup canceled."
  exit 1
fi

function progress() {
  echo "XXX"
  echo "$1"
  echo "$2"
  echo "XXX"
}

install_minimal() {
  progress 10 "Updating system and installing core tools..."
  sudo apt update && sudo apt upgrade -y
  sudo apt install -y curl wget git unzip zip htop net-tools software-properties-common build-essential neofetch ufw
}

install_java() {
  progress 30 "Installing Java 8,11,17,21..."
  sudo add-apt-repository ppa:openjdk-r/ppa -y
  sudo apt update
  sudo apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk openjdk-21-jdk
}

install_webdev() {
  progress 50 "Installing WebDev tools (Python3, Nodejs, Docker)..."
  sudo apt install -y python3 python3-pip nodejs npm docker.io docker-compose
  sudo usermod -aG docker $USER
}

install_datasci() {
  progress 70 "Installing Data Science tools (Python3, Jupyter, DBs)..."
  sudo apt install -y python3 python3-pip jupyter-notebook default-mysql-client mariadb-server postgresql sqlite3
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
  sudo snap install code --classic || echo "⚠️ VS Code installation failed"
}

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
  *)
    echo "Invalid option."
    exit 1
    ;;
esac

progress 100 "Setup complete!"

whiptail --title "Setup finished" --msgbox "✅ Setup for profile '$PROFILE' complete!\n\nLog saved to:\n$LOGFILE\n\nPlease reboot to apply changes." 12 60
