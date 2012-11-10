#!/bin/bash

echo
echo "################################################"
echo "Interactive OpenVPN Install Script for OpenVZ VPS"
echo "Should work on various deb-based Linux distos."
echo "Tested on Debian 5, 6, and Ubuntu 10.10"
echo
echo "Make sure to message your provider and have them enable"
echo "TUN, IPtables, and NAT modules prior to setting up OpenVPN."
echo
echo "You need to set up the server before creating more client keys."
echo "A separate client keyset is required per connection or machine."
echo "################################################"
echo
echo
echo "################################################"
echo "Select on option:"
echo "1) Set up new OpenVPN server AND create one client"
echo "2) Create additional clients"
echo "################################################"
echo
read x
if test $x -eq 1; then
	echo "Specify server port number that you want the OpenVPN to use (eg. 1194):"
	read p
	echo "Enter client username that you want to create (eg. client1):"
	read c
	echo "Server IP Address:"
	read ip

# get the VPS IP
#ip=`grep address /etc/network/interfaces | grep -v 127.0.0.1  | awk '{print $2}'`

echo
echo "################################################"
echo "Downloading OpenVPN 2.2.0"
echo "################################################"
echo
#case $(lsb_release -is) in Debian) wget http://build.openvpn.net/downloads/releases/debian/5/openvpn_2.2.0-debian0_i386.deb;; Ubuntu) wget http://build.openvpn.net/downloads/releases/ubuntu/10.04/openvpn_2.2.0-ubuntu0_i386.deb;; *) echo "Unkown distribution";; esac

echo
echo "################################################"
echo "Downloading and Installing Dependencies"
echo "################################################"
echo
apt-get update
apt-get install liblzo2-2 libpkcs11-helper1 openvpn-blacklist openvpn
#case $(lsb_release -is) in Debian) dpkg -i openvpn_2.2.0-debian0_i386.deb;; Ubuntu) dpkg -i openvpn_2.2.0-ubuntu0_i386.deb;; *) echo "Unkown distribution";; esac

echo
echo "################################################"
echo "Creating Server Config"
echo "\"Common Name\" must be filled."
echo "Please insert : server"
echo "################################################"
echo
cp -R /usr/share/doc/openvpn/examples/easy-rsa/ /etc/openvpn

# creating server.conf file
echo ";local $ip" > /etc/openvpn/server.conf
echo "port $p" >> /etc/openvpn/server.conf
echo "proto udp" >> /etc/openvpn/server.conf
echo "dev tun" >> /etc/openvpn/server.conf
echo "ca /etc/openvpn/keys/ca.crt" >> /etc/openvpn/server.conf
echo "cert /etc/openvpn/keys/server.crt" >> /etc/openvpn/server.conf
echo "key /etc/openvpn/keys/server.key" >> /etc/openvpn/server.conf
echo "dh /etc/openvpn/keys/dh1024.pem" >> /etc/openvpn/server.conf
echo "server 10.8.0.0 255.255.255.0" >> /etc/openvpn/server.conf
echo "ifconfig-pool-persist ipp.txt" >> /etc/openvpn/server.conf
echo "push \"redirect-gateway def1 bypass-dhcp\"" >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS 8.8.8.8\"" >> /etc/openvpn/server.conf
echo "push \"dhcp-option DNS 8.8.4.4\"" >> /etc/openvpn/server.conf
echo "keepalive 5 30" >> /etc/openvpn/server.conf
echo "comp-lzo" >> /etc/openvpn/server.conf
echo "persist-key" >> /etc/openvpn/server.conf
echo "persist-tun" >> /etc/openvpn/server.conf
echo "status openvpn-status.log" >> /etc/openvpn/server.conf
echo "verb 3" >> /etc/openvpn/server.conf

cd /etc/openvpn/easy-rsa/2.0/
. ./vars
./clean-all

echo
echo "################################################"
echo "Building Certifcate Authority"
echo "\"Common Name\" must be filled."
echo "Please insert : <anything>"
echo "################################################"
echo
./build-ca

echo
echo "################################################"
echo "Building Server Certificate"
echo "\"Common Name\" must be filled."
echo "Please insert : server"
echo "################################################"
echo
./build-key-server server
./build-dh

cp -R /etc/openvpn/easy-rsa/2.0/keys /etc/openvpn/keys

echo
echo "################################################"
echo "Starting Server"
echo "################################################"
echo
/etc/init.d/openvpn start

echo
echo "################################################"
echo "Forwarding IPv4 and Enabling It On boot"
echo "################################################"
echo
echo 1 > /proc/sys/net/ipv4/ip_forward
# saves ipv4 forwarding and and enables it on-boot
cat >> /etc/sysctl.conf <<END
net.ipv4.ip_forward=1
END
sysctl -p

echo
echo "################################################"
echo "Updating IPtables Routing and Enabling It On boot"
echo "################################################"
echo
iptables -t nat -A POSTROUTING -s 10.8.0.0/24 -j SNAT --to $ip
# saves iptables routing rules and enables them on-boot
iptables-save > /etc/iptables.conf
cat > /etc/network/if-up.d/iptables <<END
#!/bin/sh
iptables-restore < /etc/iptables.conf
END
chmod +x /etc/network/if-up.d/iptables

echo
echo "################################################"
echo "Building certificate for client $c"
echo "\"Common Name\" must be filled."
echo "Please insert like same cert : $c"
echo "################################################"
echo
./build-key $c

echo "client" > /etc/openvpn/keys/$c.ovpn
echo "dev tun" >> /etc/openvpn/keys/$c.ovpn
echo "proto udp" >> /etc/openvpn/keys/$c.ovpn
echo "remote $ip $p" >> /etc/openvpn/keys/$c.ovpn
echo "resolv-retry infinite" >> /etc/openvpn/keys/$c.ovpn
echo "nobind" >> /etc/openvpn/keys/$c.ovpn
echo "persist-key" >> /etc/openvpn/keys/$c.ovpn
echo "persist-tun" >> /etc/openvpn/keys/$c.ovpn
echo "ca ca.crt" >> /etc/openvpn/keys/$c.ovpn
echo "cert $c.crt" >> /etc/openvpn/keys/$c.ovpn
echo "key $c.key" >> /etc/openvpn/keys/$c.ovpn
echo "comp-lzo" >> /etc/openvpn/keys/$c.ovpn
echo "verb 3" >> /etc/openvpn/keys/$c.ovpn

cp /etc/openvpn/easy-rsa/2.0/keys/$c.crt /etc/openvpn/keys
cp /etc/openvpn/easy-rsa/2.0/keys/$c.key /etc/openvpn/keys

cd /etc/openvpn/keys/
tar -czf clientkeys.tgz ca.crt $c.crt $c.key $c.ovpn

echo
echo "################################################"
echo "One client keyset for $c generated."
echo "To connect:"
echo "1) Download /etc/openvpn/keys/clientkeys.tgz using a client such as WinSCP/FileZilla."
echo "2) Create a folder named VPN in C:\Program Files\OpenVPN\config directory."
echo "3) Extract the contents of clientkeys.tgz to the VPN folder."
echo "4) Start openvpn-gui, right click the tray icon and click Connect on your client name."
echo "To generate additonal client keysets, run the script again with option #2."
echo "################################################"
echo

# runs this if option 2 is selected
elif test $x -eq 2; then
	echo "Enter client username that you want to create (eg. client2):"
	read c
	echo "Server IP Address:"
	read ip

# get the VPS IP
#ip=`grep address /etc/network/interfaces | grep -v 127.0.0.1  | awk '{print $2}'`
p=`grep -n 'port' /etc/openvpn/server.conf | cut -d' ' -f2`

echo
echo "################################################"
echo "Building certificate for client $c"
echo "\"Common Name\" must be filled."
echo "Please insert like same cert : $c"
echo "################################################"
echo
cd /etc/openvpn/easy-rsa/2.0
source ./vars
. ./vars
./build-key $c

echo "client" > /etc/openvpn/keys/$c.ovpn
echo "dev tun" >> /etc/openvpn/keys/$c.ovpn
echo "proto udp" >> /etc/openvpn/keys/$c.ovpn
echo "remote $ip $p" >> /etc/openvpn/keys/$c.ovpn
echo "resolv-retry infinite" >> /etc/openvpn/keys/$c.ovpn
echo "nobind" >> /etc/openvpn/keys/$c.ovpn
echo "persist-key" >> /etc/openvpn/keys/$c.ovpn
echo "persist-tun" >> /etc/openvpn/keys/$c.ovpn
echo "ca ca.crt" >> /etc/openvpn/keys/$c.ovpn
echo "cert $c.crt" >> /etc/openvpn/keys/$c.ovpn
echo "key $c.key" >> /etc/openvpn/keys/$c.ovpn
echo "comp-lzo" >> /etc/openvpn/keys/$c.ovpn
echo "verb 3" >> /etc/openvpn/keys/$c.ovpn

cp /etc/openvpn/easy-rsa/2.0/keys/$c.crt /etc/openvpn/keys
cp /etc/openvpn/easy-rsa/2.0/keys/$c.key /etc/openvpn/keys

cd /etc/openvpn/keys/
tar -czf clientkeys.tgz ca.crt $c.crt $c.key $c.ovpn

echo
echo "################################################"
echo "One client keyset for $c generated."
echo "To connect:"
echo "1) Download /etc/openvpn/keys/clientkeys.tgz using a client such as WinSCP/FileZilla."
echo "2) Create a folder named VPN in C:\Program Files\OpenVPN\config directory."
echo "3) Extract the contents of clientkeys.tgz to the VPN folder."
echo "4) Start openvpn-gui, right click the tray icon and click Connect on your client name."
echo "################################################"
echo

else
echo "Invalid selection, quitting."
exit
fi