#!/bin/bash

# =======================================================================
# ?? VazeAP - Automated Ubuntu Setup & Optimization ??
# =======================================================================

set -e

LOGFILE="$HOME/VazeAP-setup-$(date +%Y%m%d_%H%M%S).log"
REPO_USER="weeeedddd"
REPO_NAME="ubuntu-setup-scripts"
SCRIPT_NAME="VazeAP.sh"
SCRIPT_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/main/$SCRIPT_NAME"

# -----------------------------------------------------------------------
# ?? Fancy Banner & Self-Update
# -----------------------------------------------------------------------
print_logo() {
  echo -e "\n"
  echo -e "\e[95m?????????????????????????\e[0m"
  echo -e "\e[95m?   \e[96m_VazeAP_ - Automated Ubuntu Setup Script   \e[95m?\e[0m"
  echo -e "\e[95m?  \e[93m?? Powered by VazeAP - Efficiency & Magic! ??  \e[95m?\e[0m"
  echo -e "\e[95m?????????????????????????\e[0m"
  echo -e "\n"
}

check_for_update() {
  echo -e "?? Checking for script updates..."
  LOCAL_SCRIPT="$0"
  TMP_SCRIPT=$(mktemp)
  if curl -fsSL "$SCRIPT_URL" -o "$TMP_SCRIPT"; then
    if ! diff -q "$LOCAL_SCRIPT" "$TMP_SCRIPT" > /dev/null; then
      echo -e "? New version found! Updating..."
      chmod +x "$TMP_SCRIPT"
      exec "$TMP_SCRIPT" "$@"
      exit 0
    else
      echo -e "? Script is already up to date."
    fi
  else
    echo -e "??  Failed to check for updates (network issue?)."
  fi
  rm -f "$TMP_SCRIPT"
}

# -----------------------------------------------------------------------
# ?? Begin Execution
# -----------------------------------------------------------------------
print_logo
check_for_update "$@"

# Start logging
exec > >(tee -a "$LOGFILE") 2>&1

# Ask for sudo upfront
sudo -v

# Ensure required packages
for pkg in whiptail dialog curl wget git; do
  if ! command -v $pkg &>/dev/null; then
    echo -e "?? Installing missing package: $pkg ..."
    sudo apt install -y $pkg
  fi
done

# -----------------------------------------------------------------------
# ?? Main Menu: Choose Profile or Features
# -----------------------------------------------------------------------
PROFILE=$(whiptail --title "?? VazeAP Setup Menu" --menu "Select profile or features to install:" 24 80 9 \
  "minimal"     "?? Minimal: Core essentials" \
  "webdev"      "?? WebDev: Node.js, Python, Docker" \
  "datasci"     "?? Data Science: Python, Jupyter, DBs" \
  "fullstack"   "?? Full Stack: Everything + Media & Performance" \
  "serveropt"   "??? Server Optimization: Sysctl, SSH, TCP, DNS, GRUB" \
  "texlive"     "?? TeX Live: Latest LaTeX distribution" \
  "benchmark"   "?? Benchmark & Speedtest Tools" \
  "monitoring"  "?? Monitoring Stack: Prometheus & Netdata" \
  "ultraperf"   "? Ultra Performance: CPU, I/O, NUMA, Kernel" 3>&1 1>&2 2>&3) || { echo -e "? Setup canceled."; exit 1; }

# Initialize flags
INSTALL_SECURITY=false
INSTALL_TEXLIVE=false
INSTALL_SERVEROPT=false
INSTALL_BENCHMARK=false
INSTALL_MONITORING=false
INSTALL_BACKUP=false
INSTALL_ULTRAPERF=false

# Ask optional installs if using custom or all
if [ "$PROFILE" == "all" ] || [ "$PROFILE" == "custom" ]; then
  if whiptail --yesno "??? Apply DDOS & Security Hardening?" 10 60; then
    INSTALL_SECURITY=true
  fi
  if whiptail --yesno "?? Install TeX Live?" 10 60; then
    INSTALL_TEXLIVE=true
  fi
  if whiptail --yesno "?? Apply server optimization features?" 10 60; then
    INSTALL_SERVEROPT=true
  fi
  if whiptail --yesno "?? Install benchmarking & speedtest?" 10 60; then
    INSTALL_BENCHMARK=true
  fi
  if whiptail --yesno "?? Install monitoring stack?" 10 60; then
    INSTALL_MONITORING=true
  fi
  if whiptail --yesno "? Apply Ultra Performance Tweaks?" 10 60; then
    INSTALL_ULTRAPERF=true
  fi
fi

# Profiles override flags
case $PROFILE in
  minimal)
    ;;
  webdev)
    INSTALL_SECURITY=false
    ;;
  datasci)
    INSTALL_SECURITY=false
    ;;
  fullstack)
    INSTALL_SECURITY=false
    ;;
  serveropt)
    ;;
  texlive)
    ;;
  benchmark)
    ;;
  monitoring)
    ;;
  ultraperf)
    ;;
  custom)
    ;;
  *)
    echo -e "? Invalid option. Please rerun script."
    exit 1
    ;;
esac

# Progress helper
env PROG=0
progress() {
  local percent="$1"; shift
  local message="$*"
  PROG=$percent
  local filled=$(( percent * 40 / 100 ))
  local empty=$(( 40 - filled ))
  local bar=$(printf "%${filled}s" | tr ' ' '#')$(printf "%${empty}s" | tr ' ' '-')
  echo -ne "?? ${message}... [${bar}] ${percent}%\r"
}

echo

# -----------------------------------------------------------------------
# ?? Installation Functions
# -----------------------------------------------------------------------
install_minimal() {
  progress 10 "Updating system & installing core tools"
  sudo apt update && sudo apt upgrade -y
  progress 30
  sudo apt install -y curl wget git unzip zip htop net-tools ufw build-essential neofetch
  progress 60
  echo -e "\n?? Minimal setup complete."
}

install_java() {
  progress 10 "Installing Java (8,11,17,21)"
  sudo add-apt-repository ppa:openjdk-r/ppa -y && sudo apt update
  sudo apt install -y openjdk-8-jdk openjdk-11-jdk openjdk-17-jdk openjdk-21-jdk
  progress 50
  echo -e "\n? Java installed."
}

install_webdev() {
  progress 10 "Installing WebDev tools (Python3, Node.js via NodeSource, Docker)"
  sudo apt install -y python3 python3-pip
  # Use NodeSource for Node.js (avoids apt nodejs/npm conflicts)
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt install -y nodejs

  sudo apt install -y docker.io docker-compose
  sudo usermod -aG docker $USER
  progress 50
  echo -e "
?? WebDev stack ready."
}

install_datasci() {
  progress 10 "Fixing packages & installing Data Science tools"
  sudo apt-get update --fix-missing
  sudo apt-get install -f -y
  sudo dpkg --configure -a
  sudo apt-get -o Dpkg::Options::="--force-confnew" --fix-broken install -y
  sudo apt-get clean && sudo apt-get autoremove -y
  progress 30
  sudo apt install -y mariadb-server mariadb-client python3-pip jupyter-notebook default-mysql-client postgresql sqlite3
  progress 70
  echo -e "\n?? Data Science tools installed."
}

install_media() {
  progress 10 "Installing multimedia & UI tools"
  sudo apt install -y vlc gimp obs-studio qbittorrent gparted
  progress 50
  echo -e "\n?? Media tools installed."
}

install_perf() {
  progress 10 "Applying performance & RAM tweaks"
  sudo apt install -y zram-tools preload
  sudo systemctl enable zramswap --now
  echo 'vm.swappiness = 10' | sudo tee -a /etc/sysctl.conf
  echo 'vm.vfs_cache_pressure = 50' | sudo tee -a /etc/sysctl.conf
  echo 'vm.dirty_ratio = 15' | sudo tee -a /etc/sysctl.conf
  echo 'vm.dirty_background_ratio = 5' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  progress 60
  echo -e "\n?? Performance optimizations applied."
}

install_vscode() {
  progress 10 "Installing Visual Studio Code"
  sudo snap install code --classic || echo -e "?? VS Code install failed"
  progress 50
  echo -e "\n??? VS Code installed."
}

install_security() {
  progress 10 "Applying DDOS & security hardening"
  sudo apt install -y iptables-persistent fail2ban
  sudo iptables -F && sudo iptables -X
  sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 22 -m conntrack --"))
]}
