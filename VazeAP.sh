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
sudo apt install -y iptables-persistent netfilter-persistent
sudo DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent netfilter-persistent

# Ensure required packages
for pkg in whiptail dialog curl wget git; do
  if ! command -v $pkg &>/dev/null; then
    echo -e "?? Installing missing package: $pkg ..."
    sudo apt install -y $pkg
  APPLY_IPTABLES="yes"
if command -v whiptail &>/dev/null && tty -s; then
  if whiptail --yesno "Do you want to apply recommended iptables firewall rules (DDOS & SSH protection)?" 10 60; then
    APPLY_IPTABLES="yes"
  else
    APPLY_IPTABLES="no"
  fi
fi

if [[ "$APPLY_IPTABLES" == "yes" ]]; then
  install_iptables_rules
else
  echo "Skipping iptables rules setup."
fi
done

# -----------------------------------------------------------------------
# ?? Main Menu: Choose Profile or Features
# -----------------------------------------------------------------------
PROFILE=$(whiptail --title "?? VazeAP Setup Menu" --menu "Select profile or features to install:" 24 80 10 \
  "minimal"     "?? Minimal: Core essentials" \
  "webdev"      "?? WebDev: Node.js, Python, Docker" \
  "datasci"     "?? Data Science: Python, Jupyter, DBs" \
  "fullstack"   "?? Full Stack: Everything + Media & Performance" \
  "serveropt"   "??? Server Optimization: Sysctl, SSH, TCP, DNS, GRUB" \
  "texlive"     "?? TeX Live: Latest LaTeX distribution" \
  "benchmark"   "?? Benchmark & Speedtest Tools" \
  "monitoring"  "?? Monitoring Stack: Prometheus & Netdata" \
  "ultraperf"   "? Ultra Performance: CPU, I/O, NUMA, Kernel" 3>&1 1>&2 2>&3) \
  || { echo -e "? Setup canceled."; exit 1; }

# -----------------------------------------------------------------------
# Progress bar helper
# -----------------------------------------------------------------------
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
  # Use NodeSource for Node.js
  curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
  sudo apt install -y nodejs

  sudo apt install -y docker.io docker-compose
  sudo usermod -aG docker $USER
  progress 50
  echo -e "\n?? WebDev stack ready."
}

install_datasci() {
  progress 70 "Installing Data Science tools (Python3, Jupyter, DBs)..."
  sudo apt install -y python3 python3-pip jupyter-notebook mariadb-server postgresql sqlite3

  # Hier kommt unser neuer Block rein:
  echo "🛑 Checking for broken MySQL dependencies..."
  if ! sudo apt-get install -y default-mysql-client; then
    whiptail --title "MySQL Client Issue" --msgbox "default-mysql-client could not be installed (missing mysql-client-8.0).\nTrying to install mariadb-client instead..." 10 60
    if ! sudo apt-get install -y mariadb-client; then
      whiptail --title "MariaDB Client Warning" --msgbox "MariaDB client could also not be installed. Continuing the setup anyway..." 10 60
    else
      whiptail --title "MariaDB Client Installed" --msgbox "MariaDB client was installed successfully as a replacement." 10 60
    fi
  else
    echo "✅ default-mysql-client installed successfully."
  fi
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
  sudo DEBIAN_FRONTEND=noninteractive apt install -y iptables-persistent
  sudo apt install -y fail2ban
  sudo iptables -F && sudo iptables -X
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
  progress 50
  echo -e "Security hardening complete."
}

install_iptables_rules() {
  progress 10 "🛡️  Setting recommended iptables rules (DDOS & basic firewall)"
  sudo iptables -F
  sudo iptables -X
  sudo iptables -A INPUT -m conntrack --ctstate RELATED,ESTABLISHED -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 80 -j ACCEPT
  sudo iptables -A INPUT -p tcp --dport 443 -j ACCEPT
  sudo iptables -A INPUT -p icmp --icmp-type echo-request -m limit --limit 1/second -j ACCEPT
  sudo iptables -A INPUT -j DROP
  sudo netfilter-persistent save < /dev/null
  progress 60 "✅ iptables rules applied."
}

install_texlive() {
  progress 10 "Installing TeX Live (latest version)"
  TLROOT="/usr/local/texlive"
  mkdir -p "$TLROOT"
  cd /tmp
  echo -e "?? Finding fastest CTAN mirror..."
  MIRROR=$(wget -qO- http://mirrors.ctan.org/README | grep -m1 '^http' || echo "http://mirror.ctan.org/systems/texlive/tlnet")
  echo -e "Using mirror: \$MIRROR"
  wget "${MIRROR}/install-tl-unx.tar.gz" -O install-tl.tar.gz
  tar -xf install-tl.tar.gz
  cd install-tl-*/

  ./install-tl --profile <<EOF
selected_scheme scheme-full
TEXDIR \$TLROOT/2025
TEXMFCONFIG ~/.texlive2025/texmf-config
TEXMFHOME ~/texmf
TEXMFVAR ~/.texlive2025/texmf-var
binary_x86_64-linux 1
collection-basic 1
collection-latex 1
collection-latexrecommended 1
collection-latexextra 1
collection-fontrecommended 1
collection-langenglish 1
collection-langother 1
option_doc 0
option_src 0
EOF

  echo -e "export PATH=\"\$TLROOT/2025/bin/x86_64-linux:\$PATH\"" | sudo tee /etc/profile.d/texlive.sh
  source /etc/profile.d/texlive.sh
  sudo apt-mark hold texlive-* || true
  sudo mktexlsr
  echo -e "? Adding TeX Live fonts system-wide..."
  sudo tlmgr install collection-fontsrecommended
  sudo mktexlsr
  sudo bash -c 'echo "/usr/local/texlive/** r," >> /etc/apparmor.d/usr.bin.evince'
  sudo apparmor_parser -r /etc/apparmor.d/usr.bin.evince

  progress 60
  echo -e "\n?? TeX Live installation complete."
}

install_benchmark() {
  progress 10 "Installing speedtest & benchmark tools"
  sudo apt install -y speedtest-cli sysbench
  progress 40
  echo -e "? Running quick CPU benchmark "
  sysbench cpu --cpu-max-prime=20000 run
  progress 70
  echo -e "? Running quick memory benchmark "
  sysbench memory run
  progress 100
  echo -e "\n?? Benchmarking complete. Results above."
}

install_monitoring() {
  progress 10 "Installing Node Exporter & Netdata"
  # Node Exporter
  sudo useradd --no-create-home --shell /bin/false node_exporter
  wget https://github.com/prometheus/node_exporter/releases/download/v1.6.1/node_exporter-1.6.1.linux-amd64.tar.gz
  tar xvfz node_exporter-*.linux-amd64.tar.gz
  sudo mv node_exporter-*/node_exporter /usr/local/bin/
  cat <<EOF | sudo tee /etc/systemd/system/node_exporter.service
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
User=node_exporter
ExecStart=/usr/local/bin/node_exporter

[Install]
WantedBy=default.target
EOF
  sudo systemctl daemon-reload
  sudo systemctl enable node_exporter --now

  # Netdata
  bash <(curl -Ss https://my-netdata.io/kickstart.sh) --dont-wait

  progress 60
  echo -e "\n?? Monitoring stack installed."
}

install_backup() {
  progress 10 "Installing BorgBackup & SSHpass"
  sudo apt install -y borgbackup sshpass
  progress 40
  echo -e "?? Initializing Borg repository (example)"
  borg init --encryption=repokey user@backupserver:/path/to/repo
  progress 70
  echo -e "?? Running first backup (example)"
  borg create user@backupserver:/path/to/repo::"$(hostname)-$(date +%Y-%m-%d)" /etc /var/www /home
  borg prune --keep-daily=7 --keep-weekly=4 --keep-monthly=6
  progress 100
  echo -e "\n? BorgBackup setup complete."
}

install_serveropt() {
  progress 10 "Optimizing sysctl (BBR, queue disciplines)"
  echo 'net.ipv4.tcp_congestion_control = bbr' | sudo tee -a /etc/sysctl.conf
  echo 'net.core.default_qdisc = fq_codel'         | sudo tee -a /etc/sysctl.conf
  echo 'net.core.rmem_max = 16777216'              | sudo tee -a /etc/sysctl.conf
    echo 'net.core.wmem_max = 16777216'              | sudo tee -a /etc/sysctl.conf
  echo 'net.ipv4.tcp_rmem = 4096 87380 16777216'    | sudo tee -a /etc/sysctl.conf
  echo 'net.ipv4.tcp_wmem = 4096 65536 16777216'    | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  progress 30

  echo -e "\n?? Optimizing SSH (disable root login, max auth attempts)"
  sudo sed -i 's/^#*PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
  sudo sed -i 's/^#*MaxAuthTries.*/MaxAuthTries 3/' /etc/ssh/sshd_config
  sudo systemctl restart sshd
  progress 50

  echo -e "\n?? DNS tuning: installing resolvconf & setting Google DNS"
  sudo apt install -y resolvconf
  sudo bash -c 'cat <<EOF > /etc/resolvconf/resolv.conf.d/head
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF'
  sudo resolvconf -u
  progress 70

  echo -e "\n?? GRUB tuning: choose profile"
  GRUB_OPT=$(whiptail --title "GRUB Profile" --menu "Select GRUB tuning profile:" 15 60 4 \
    "mobile" "? Mobile / Low power" \
    "audio"  "?? Audio production" \
    "virt"   "??? Virtualization" \
    "gaming" "?? Gaming" 3>&1 1>&2 2>&3)
  case $GRUB_OPT in
    mobile)
      sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash intel_pstate=disable"/' /etc/default/grub
      ;;
    audio)
      sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash threadirqs"/' /etc/default/grub
      ;;
    virt)
      sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash kvm_intel.directio=1"/' /etc/default/grub
      ;;
    gaming)
      sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash zswap.enabled=1"/' /etc/default/grub
      ;;
  esac
  sudo update-grub
  progress 90

  echo -e "\n?? Creating swap file and setting swappiness"
  SWAPSIZE=$(awk '/MemTotal/ {printf "%.0f", $2/1024/1024 * 1}' /proc/meminfo)
  SWAPFILE="/swapfile"
  sudo fallocate -l ${SWAPSIZE}G "$SWAPFILE"
  sudo chmod 600 "$SWAPFILE"
  sudo mkswap "$SWAPFILE"
  sudo swapon "$SWAPFILE"
  echo "$SWAPFILE none swap sw 0 0" | sudo tee -a /etc/fstab
  sudo sysctl vm.swappiness=10
  progress 100
  echo -e "\n?? Swap setup complete across ${SWAPSIZE}G."
}

install_ultraperf() {
  progress 5 "Setting CPU governor to performance"
  sudo apt install -y cpufrequtils
  echo 'GOVERNOR="performance"' | sudo tee /etc/default/cpufrequtils
  sudo systemctl enable cpufrequtils --now
  progress 20

  echo -e "\n?? Configuring IRQ affinity for network interfaces"
  for iface in $(ls /sys/class/net | grep -v lo); do
    for irq in $(grep "$iface" /proc/interrupts | awk '{print $1}' | sed 's/://'); do
      echo 6 | sudo tee /proc/irq/"$irq"/smp_affinity
    done
  done
  progress 35

  echo -e "\n?? Enabling zswap (LZ4) and zram"
  echo 1 | sudo tee /sys/module/zswap/parameters/enabled
  echo lz4 | sudo tee /sys/module/zswap/parameters/compressor
  echo 20 | sudo tee /sys/module/zswap/parameters/max_pool_percent
  echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf
  echo 'vm.vfs_cache_pressure=50' | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  progress 50

  echo -e "\n?? Configuring filesystem mount options (noatime, nodiratime)"
  sudo sed -i 's/\(defaults\)/\1,noatime,nodiratime,commit=600/' /etc/fstab
  progress 65

  echo -e "\n?? Reserving HugePages"
  TOTAL_RAM_MB=$(awk '/MemTotal/ {print int($2/1024)}' /proc/meminfo)
  HUGEPAGES=$(( TOTAL_RAM_MB / 2 / 1024 ))
  echo $HUGEPAGES | sudo tee /proc/sys/vm/nr_hugepages
  echo "vm.nr_hugepages = $HUGEPAGES" | sudo tee -a /etc/sysctl.conf
  sudo sysctl -p
  progress 80

  echo -e "\n?? Applying NUMA interleave"
  sudo sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash numa=interleave=all"/' /etc/default/grub
  sudo update-grub
  progress 90

  echo -e "\n?? (Optional) You can install XanMod kernel manually later"
  progress 100
  echo -e "\n?? Ultra performance tweaks applied."
}

# -----------------------------------------------------------------------
# Execute based on Profile
# -----------------------------------------------------------------------
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
    install_security
    install_vscode
    ;;
  datasci)
    install_minimal
    install_java
    install_datasci
    install_security
    install_vscode
    ;;
  fullstack)
    install_minimal
    install_java
    install_webdev
    install_datasci
    install_media
    install_perf
    install_security
    install_vscode
    ;;
  serveropt)
    install_serveropt
    ;;
  texlive)
    install_texlive
    ;;
  benchmark)
    install_benchmark
    ;;
  monitoring)
    install_monitoring
    ;;
  ultraperf)
    install_ultraperf
    ;;
  *)
    echo -e "? Invalid option. Please rerun script."
    exit 1
    ;;
esac

# -----------------------------------------------------------------------
# Final message
# -----------------------------------------------------------------------
echo
progress 100 "All done! ??"
echo -e "\n? Setup complete! Profile '$PROFILE' installed. Log saved to: $LOGFILE"

