#!/bin/bash

echo
echo "######################################################"
echo "Interactive PoPToP Install Script for OpenVZ VPS"
echo "Should work on various deb-based Linux distos."
echo "Tested on Debian 5, 6, and Ubuntu 11.04"
echo
echo "Make sure to message your provider and have them enable"
echo "IPtables and ppp modules prior to setting up PoPToP."
echo
echo "You need to set up the server before creating more users."
echo "A separate user is required per connection or machine."
echo "######################################################"
echo
echo
echo "######################################################"
echo "Select on option:"
echo "1) Set up new PoPToP server AND create one user"
echo "2) Create additional users"
echo "######################################################"
echo
read x
if test $x -eq 1; then
	echo "Enter username that you want to create (eg. client1 or john):"
	read u
	echo "Specify password that you want the user to use:"
	read p
	echo "Server IP Address:"
	read ip

# get the VPS IP
#ip=`ifconfig venet0:0 | grep 'inet addr' | awk {'print $2'} | sed s/.*://` # OpenVZ
#ip=`grep address /etc/network/interfaces | grep -v 127.0.0.1 | awk '{print $2}'` # Xen/KVM

echo
echo "######################################################"
echo "Downloading and Installing PoPToP"
echo "######################################################"
echo
apt-get update
apt-get install pptpd

echo
echo "######################################################"
echo "Creating Server Config"
echo "######################################################"
echo
cat > /etc/ppp/pptpd-options <<END
name pptpd
refuse-pap
refuse-chap
refuse-mschap
require-mschap-v2
require-mppe-128
ms-dns 8.8.8.8
ms-dns 8.8.4.4
proxyarp
nodefaultroute
lock
nobsdcomp
END

# setting up pptpd.conf
echo "option /etc/ppp/pptpd-options" > /etc/pptpd.conf
echo "logwtmp" >> /etc/pptpd.conf
echo "localip $ip" >> /etc/pptpd.conf
echo "remoteip 10.1.0.1-100" >> /etc/pptpd.conf

# adding new user
echo "$u	*	$p	*" >> /etc/ppp/chap-secrets

echo
echo "######################################################"
echo "Forwarding IPv4 and Enabling it on boot"
echo "######################################################"
echo
cat >> /etc/sysctl.conf <<END
net.ipv4.ip_forward=1
END
sysctl -p

echo
echo "######################################################"
echo "Updating IPtables Routing and Enabling it on boot"
echo "######################################################"
echo
iptables -t nat -A POSTROUTING -j SNAT --to $ip
# saves iptables routing rules and enables them on-boot
iptables-save > /etc/iptables.conf
cat > /etc/network/if-up.d/iptables <<END
#!/bin/sh
iptables-restore < /etc/iptables.conf
END
chmod +x /etc/network/if-up.d/iptables

cat >> /etc/ppp/ip-up <<END
ifconfig ppp0 mtu 1400
END

echo
echo "######################################################"
echo "Restarting PoPToP"
echo "######################################################"
echo
/etc/init.d/pptpd restart

echo
echo "######################################################"
echo "Server setup complete!"
echo "Connect to your VPS at $ip with these credentials:"
echo "Username:$u ##### Password: $p"
echo "######################################################"
echo

# runs this if option 2 is selected
elif test $x -eq 2; then
	echo "Enter username that you want to create (eg. client1 or john):"
	read u
	echo "Specify password that you want the user to use:"
	read p
	echo "Server IP Address:"
	read ip
	
# get the VPS IP
#ip=`ifconfig venet0:0 | grep 'inet addr' | awk {'print $2'} | sed s/.*://` # OpenVZ
#ip=`grep address /etc/network/interfaces | grep -v 127.0.0.1 | awk '{print $2}'` # Xen/KVM

# adding new user
echo "$u	*	$p	*" >> /etc/ppp/chap-secrets

echo
echo "######################################################"
echo "Addtional user added!"
echo "Connect to your VPS at $ip with these credentials:"
echo "Username:$u ##### Password: $p"
echo "######################################################"
echo

else
echo "Invalid selection, quitting."
exit
fi