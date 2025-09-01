#!/bin/bash
set -ex

# 1. Install all prerequisites, including development tools for the C++ version
yum update -y
yum install -y git gcc gcc-c++ make wget tar cmake3 iptables-services aws-cli
yum groupinstall -y "Development Tools"

# 2. Disable Source/Dest Check
INSTANCE_ID=$(curl -s http://169.254.169.254/latest/meta-data/instance-id)
REGION=$(curl -s http://169.254.169.254/latest/meta-data/placement/region)
aws ec2 modify-instance-attribute --no-source-dest-check --instance-id $INSTANCE_ID --region $REGION

# 3. Enable IP Forwarding
echo "net.ipv4.ip_forward = 1" > /etc/sysctl.d/99-ip-forward.conf
sysctl -p /etc/sysctl.d/99-ip-forward.conf

# --- THE CRITICAL FIX IS HERE ---
# 4. Add the firewall rule BEFORE starting the firewall service
iptables -I INPUT -p udp --dport 6081 -j ACCEPT
# --------------------------------

# 5. Build Boost library
cd /opt
wget https://archives.boost.io/release/1.83.0/source/boost_1_83_0.tar.gz
tar -xzf boost_1_83_0.tar.gz
cd boost_1_83_0
./bootstrap.sh
./b2 install

# 6. Build the C++ version of gwlbtun
cd /opt
git clone https://github.com/aws-samples/aws-gateway-load-balancer-tunnel-handler.git
cd aws-gateway-load-balancer-tunnel-handler
# Apply compilation fixes for newer compilers/kernels
sed -i '1i #include <sys/syscall.h>\n#include <unistd.h>' TunInterface.cpp
sed -i 's/gettid()/syscall(SYS_gettid)/g' TunInterface.cpp
sed -i '1i #include <sys/syscall.h>\n#include <unistd.h>' UDPPacketReceiver.cpp
sed -i 's/gettid()/syscall(SYS_gettid)/g' UDPPacketReceiver.cpp
sed -i 's|lm = (struct LoggingMessage){.ls = ls, .ll = ll, .msg = stringFormat(fmt_str, ap), .ts = std::chrono::system_clock::now(), .thread = "" };|lm = LoggingMessage{ls, ll, stringFormat(fmt_str, ap), std::chrono::system_clock::now(), ""};|' Logger.cpp
# Create build directory and compile
mkdir build && cd build
cmake3 -DBOOST_ROOT=/usr/local ..
make
cp gwlbtun /usr/local/bin/
# 7. Create the NAT "hook script" that gwlbtun will call dynamically
cat <<'EOT' > /opt/create-nat.sh
#!/bin/bash
# This script is called by gwlbtun AFTER it creates the interfaces.
# It implements the "2-arm NAT" example from the official documentation.
# $1 = Action (e.g., CREATE)
# $2 = Ingress Interface (e.g., gwi-xxxxx)

INGRESS_INT=$2

if [ "$1" == "CREATE" ]; then
  # Apply NAT to all traffic leaving the main (eth0) interface
  iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

  # Allow traffic to be forwarded from the tunnel interface to the main interface
  iptables -A FORWARD -i $INGRESS_INT -o eth0 -j ACCEPT
  
  # Allow return traffic to be forwarded from the main interface back to the tunnel
  iptables -A FORWARD -i eth0 -o $INGRESS_INT -m state --state RELATED,ESTABLISHED -j ACCEPT

  # Critical kernel setting from the documentation to prevent dropped packets
  echo 0 > /proc/sys/net/ipv4/conf/$INGRESS_INT/rp_filter

  # Save the new dynamic rules so they persist
  service iptables save
fi
EOT
chmod +x /opt/create-nat.sh

# 8. Create the systemd service file
cat <<'EOT' > /etc/systemd/system/gwlbtun.service
[Unit]
Description=Gateway LB Tunnel Handler
After=network-online.target iptables.service
Wants=network-online.target

[Service]
ExecStart=/usr/local/bin/gwlbtun -c /opt/create-nat.sh -p 80
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOT

# 9. Start services in the correct order
service iptables save
systemctl daemon-reload
systemctl enable --now iptables
systemctl enable --now gwlbtun.service

echo "User data script finished successfully."