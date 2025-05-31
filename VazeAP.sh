#!/bin/bash

set -e

LOGFILE="$HOME/ubuntu-setup-$(date +%Y%m%d_%H%M%S).log"
SCRIPT_URL="https://raw.githubusercontent.com/weeeedddd/ubuntu-setup-scripts/main/VazeAP.sh"

function print_logo() {
cat << "EOF"
 __     ______  _    _   _      ____   _____ _____ 
 \ \   / / __ \| |  | | | |    / __ \ / ____|  __ \
  \ \_/ / |  | | |  | | | |   | |  | | (___ | |__) |
   \   /| |  | | |  | | | |   | |  | |\___ \|  ___/
    | | | |__| | |__| | | |___| |__| |____) | |    
    |_|  \____/ \____/  |______\____/|_____/|_|    
                                 Automated Setup Script
EOF
}

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

print_logo
check_update "$@"

exec > >(tee -a "$LOGFILE") 2>&1

sudo -v

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

INSTALL_PTERODACTYL=false
if whiptail --yesno "Do you want to install Pterodactyl Panel and Wings?" 10 60; then
  INSTALL_PTERODACTYL=true
fi

INSTALL_SECURITY=false
if whiptail --yesno "Do you want to apply DDOS protection and security tweaks?" 10 60; then
  INSTALL_SECURITY=true
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
  progress 20 "Installing Java 8,11,17,21..."
  sudo add-apt-repository ppa:openjdk-r/ppa -y
  sudo apt update
  sudo apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk openjdk-21-jdk
}

install_webdev() {
  progress 30 "Installing WebDev tools (Python3, Nodejs, Docker)..."
  sudo apt install -y python3 python3-pip nodejs npm docker.io docker-compose
  sudo usermod -aG docker $USER
}

install_datasci() {
  progress 40 "Fixing broken packages..."
  sudo apt-get update --fix-missing
  sudo apt-get install -f -y
  sudo dpkg --configure -a
  sudo apt-get -o Dpkg::Options::="--force-confnew" --fix-broken install -y
  sudo apt-get clean
  sudo apt-get autoremove -y

  progress 41 "Installing MariaDB server and client..."
  sudo apt install -y mariadb-server mariadb-client

  progress 42 "Installing Data Science tools (Python3, Jupyter, DBs)..."
  sudo apt install -y python3 python3-pip jupyter-notebook default-mysql-client postgresql sqlite3
}

install_media() {
  progress 50 "Installing Media & UI tools..."
  sudo apt install -y vlc gimp obs-studio qbittorrent gparted
}

install_perf() {
  progress 60 "Applying performance and RAM tweaks..."

  sudo apt install -y zram-tools
  sudo systemctl enable zramswap --now

  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
  echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
  echo 'vm.dirty_ratio=15' | sudo tee -a /etc/sysctl.conf
  echo 'vm.dirty_background_ratio=5' | sudo tee -a /etc/sysctl.conf

  sudo sysctl -p

  sudo ufw default deny incoming
  sudo ufw default allow outgoing
  sudo ufw allow ssh
  sudo ufw enable

  progress 65 "Performance tweaks applied."
}

install_vscode() {
  progress 70 "Installing Visual Studio Code..."
  sudo snap install code --classic || echo "?? VS Code installation failed"
}

install_pterodactyl() {
  progress 80 "Installing Pterodactyl Panel and Wings..."

  sudo apt install -y software-properties-common curl apt-transport-https ca-certificates gnupg

  sudo add-apt-repository ppa:ondrej/php -y
  sudo apt update
  sudo apt install -y php8.1 php8.1-cli php8.1-fpm php8.1-mysql php8.1-zip php8.1-mbstring php8.1-bcmath php8.1-curl php8.1-gd php8.1-pgsql php8.1-xml php8.1-tokenizer php8.1-opcache php8.1-redis

  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt install -y nodejs redis-server

  curl -sS https://getcomposer.org/installer | php
  sudo mv composer.phar /usr/local/bin/composer

  curl -L https://github.com/pterodactyl/wings/releases/latest/download/wings_linux_amd64 -o wings
  sudo mv wings /usr/local/bin/wings
  sudo chmod +x /usr/local/bin/wings

  sudo systemctl enable redis-server --now
  sudo systemctl enable wings --now

  progress 90 "Pterodactyl installed."
}

install_security() {
  progress 75 "Applying DDOS and security hardening..."

  sudo apt install -y iptables-persistent
  sudo iptables -F
  sudo iptables -X

  sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --set
  sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --ctstate NEW -m recent --update --seconds 60 --hitcount 4 -j DROP
  sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT
  sudo iptables -A INPUT -j DROP

  sudo netfilter-persistent save

  echo "net.ipv4.tcp_syncookies = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv4.conf.all.rp_filter = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv4.conf.default.rp_filter = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv4.icmp_echo_ignore_broadcasts = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv4.icmp_ignore_bogus_error_responses = 1" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv4.tcp_max_syn_backlog = 2048" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv4.tcp_synack_retries = 2" | sudo tee -a /etc/sysctl.conf
  echo "net.ipv4.tcp_syn_retries = 2" | sudo tee -a /etc/sysctl.conf

  sudo sysctl -p

  progress 85 "DDOS and security tweaks applied."
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

if [ "$INSTALL_PTERODACTYL" = true ]; then
  install_pterodactyl
fi

if [ "$INSTALL_SECURITY" = true ]; then
  install_security
fi

progress 100 "Setup complete!"

whiptail --title "Setup finished" --msgbox "? Setup for profile '$PROFILE' complete!\n\nLog saved to:\n$LOGFILE\n\nPlease reboot to apply all changes." 12 60
