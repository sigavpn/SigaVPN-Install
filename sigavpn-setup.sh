#!/bin/bash
# Backend code of https://sigavpn.com/
if [[ -e /etc/debian_version ]]; then
	OS="debian"
	VERSION_ID=$(cat /etc/os-release | grep "VERSION_ID")
	IPTABLES='/etc/iptables/iptables.rules'
	SYSCTL='/etc/sysctl.conf'
	if [[ "$VERSION_ID" != 'VERSION_ID="7"' ]] && [[ "$VERSION_ID" != 'VERSION_ID="8"' ]] && [[ "$VERSION_ID" != 'VERSION_ID="9"' ]] && [[ "$VERSION_ID" != 'VERSION_ID="12.04"' ]] && [[ "$VERSION_ID" != 'VERSION_ID="14.04"' ]] && [[ "$VERSION_ID" != 'VERSION_ID="16.04"' ]] && [[ "$VERSION_ID" != 'VERSION_ID="16.10"' ]] && [[ "$VERSION_ID" != 'VERSION_ID="17.04"' ]]; then
		echo "Your version of Debian/Ubuntu is not supported."
		echo "This can't install a recent version of OpenVPN on your system."
		echo ""
		echo "However, if you're using Debian unstable/testing, or Ubuntu beta,"
		echo "then you can continue, a recent version of OpenVPN is available on these."
		echo "Keep in mind they are not supported, though."
		while [[ $CONTINUE != "y" && $CONTINUE != "n" ]]; do
			read -p "Continue ? [y/n]: " -e CONTINUE
		done
		if [[ "$CONTINUE" = "n" ]]; then
			echo "Ok, bye !"
			exit 4
		fi
	fi
elif [[ -e /etc/centos-release || -e /etc/redhat-release && ! -e /etc/fedora-release ]]; then
	OS=centos
	IPTABLES='/etc/iptables/iptables.rules'
	SYSCTL='/etc/sysctl.conf'
elif [[ -e /etc/arch-release ]]; then
	OS=arch
	IPTABLES='/etc/iptables/iptables.rules'
	SYSCTL='/etc/sysctl.d/openvpn.conf'
elif [[ -e /etc/fedora-release ]]; then
	OS=fedora
	IPTABLES='/etc/iptables/iptables.rules'
	SYSCTL='/etc/sysctl.d/openvpn.conf'
else
	echo "Looks like you aren't running this installer on a Debian, Ubuntu, CentOS or ArchLinux system"
	exit 4
fi

newclient () {
	if [ -e /home/$1 ]; then 
		homeDir="/home/$1"
	elif [ ${SUDO_USER} ]; then   
		homeDir="/home/${SUDO_USER}"
	else  
		homeDir="/root"
	fi
	cp /etc/openvpn/client-template.txt $homeDir/$1.ovpn
	echo "<ca>" >> $homeDir/$1.ovpn
	cat /etc/openvpn/easy-rsa/pki/ca.crt >> $homeDir/$1.ovpn
	echo "</ca>" >> $homeDir/$1.ovpn
	echo "<cert>" >> $homeDir/$1.ovpn
	cat /etc/openvpn/easy-rsa/pki/issued/$1.crt >> $homeDir/$1.ovpn
	echo "</cert>" >> $homeDir/$1.ovpn
	echo "<key>" >> $homeDir/$1.ovpn
	cat /etc/openvpn/easy-rsa/pki/private/$1.key >> $homeDir/$1.ovpn
	echo "</key>" >> $homeDir/$1.ovpn
	echo "key-direction 1" >> $homeDir/$1.ovpn
	echo "<tls-auth>" >> $homeDir/$1.ovpn
	cat /etc/openvpn/tls-auth.key >> $homeDir/$1.ovpn
	echo "</tls-auth>" >> $homeDir/$1.ovpn
}
IP=$(ip addr | grep 'inet' | grep -v inet6 | grep -vE '127\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | grep -o -E '[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}' | head -1)
if [[ "$IP" = "" ]]; then
	IP=$(wget -qO- ipv4.icanhazip.com)
fi
NIC=$(ip -4 route ls | grep default | grep -Po '(?<=dev )(\S+)' | head -1)
	clear
	PORT="443"
  PROTOCOL="TCP"
  DNS="1"
  CIPHER="cipher AES-128-CBC"
	DH_KEY_SIZE="3072"
	RSA_KEY_SIZE="4096"
  CLIENT="testuser"
	if [[ "$OS" = 'debian' ]]; then
		apt-get install ca-certificates -y
		if [[ "$VERSION_ID" = 'VERSION_ID="7"' ]]; then
			echo "deb http://build.openvpn.net/debian/openvpn/stable wheezy main" > /etc/apt/sources.list.d/openvpn.list
			wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
			apt-get update
		fi
		if [[ "$VERSION_ID" = 'VERSION_ID="8"' ]]; then
			echo "deb http://build.openvpn.net/debian/openvpn/stable jessie main" > /etc/apt/sources.list.d/openvpn.list
			wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
			apt update
		fi
		if [[ "$VERSION_ID" = 'VERSION_ID="12.04"' ]]; then
			echo "deb http://build.openvpn.net/debian/openvpn/stable precise main" > /etc/apt/sources.list.d/openvpn.list
			wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
			apt-get update
		fi
		if [[ "$VERSION_ID" = 'VERSION_ID="14.04"' ]]; then
			echo "deb http://build.openvpn.net/debian/openvpn/stable trusty main" > /etc/apt/sources.list.d/openvpn.list
			wget -O - https://swupdate.openvpn.net/repos/repo-public.gpg | apt-key add -
			apt-get update
		fi
		apt-get install openvpn iptables openssl wget ca-certificates curl -y
		if [[ ! -e /etc/systemd/system/iptables.service ]]; then
			mkdir /etc/iptables
			iptables-save > /etc/iptables/iptables.rules
			echo "#!/bin/sh
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT" > /etc/iptables/flush-iptables.sh
			chmod +x /etc/iptables/flush-iptables.sh
			echo "[Unit]
Description=Packet Filtering Framework
DefaultDependencies=no
Before=network-pre.target
Wants=network-pre.target
[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/iptables.rules
ExecReload=/sbin/iptables-restore /etc/iptables/iptables.rules
ExecStop=/etc/iptables/flush-iptables.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/iptables.service
			systemctl daemon-reload
			systemctl enable iptables.service
		fi
	elif [[ "$OS" = 'centos' || "$OS" = 'fedora' ]]; then
		if [[ "$OS" = 'centos' ]]; then
			yum install epel-release -y
		fi
		yum install openvpn iptables openssl wget ca-certificates curl -y
		if [[ ! -e /etc/systemd/system/iptables.service ]]; then
			mkdir /etc/iptables
			iptables-save > /etc/iptables/iptables.rules
			echo "#!/bin/sh
iptables -F
iptables -X
iptables -t nat -F
iptables -t nat -X
iptables -t mangle -F
iptables -t mangle -X
iptables -P INPUT ACCEPT
iptables -P FORWARD ACCEPT
iptables -P OUTPUT ACCEPT" > /etc/iptables/flush-iptables.sh
			chmod +x /etc/iptables/flush-iptables.sh
			echo "[Unit]
Description=Packet Filtering Framework
DefaultDependencies=no
Before=network-pre.target
Wants=network-pre.target
[Service]
Type=oneshot
ExecStart=/sbin/iptables-restore /etc/iptables/iptables.rules
ExecReload=/sbin/iptables-restore /etc/iptables/iptables.rules
ExecStop=/etc/iptables/flush-iptables.sh
RemainAfterExit=yes
[Install]
WantedBy=multi-user.target" > /etc/systemd/system/iptables.service
			systemctl daemon-reload
			systemctl enable iptables.service
			systemctl disable firewalld
			systemctl mask firewalld
		fi
	else
		echo "Not doing that could cause problems between dependencies, or missing files in repositories."
		echo ""
		echo "Continuing will update your installed packages and install needed ones."
		while [[ $CONTINUE != "y" && $CONTINUE != "n" ]]; do
			read -p "Continue ? [y/n]: " -e -i y CONTINUE
		done
		if [[ "$CONTINUE" = "n" ]]; then
			exit 4
		fi
		if [[ "$OS" = 'arch' ]]; then
			pacman -Syu openvpn iptables openssl wget ca-certificates curl --needed --noconfirm
			iptables-save > /etc/iptables/iptables.rules # iptables won't start if this file does not exist
			systemctl daemon-reload
			systemctl enable iptables
			systemctl start iptables
		fi
	fi
	if grep -qs "^nogroup:" /etc/group; then
		NOGROUP=nogroup
	else
		NOGROUP=nobody
	fi
	if [[ -d /etc/openvpn/easy-rsa/ ]]; then
		rm -rf /etc/openvpn/easy-rsa/
	fi
	wget -O ~/EasyRSA-3.0.3.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v3.0.3/EasyRSA-3.0.3.tgz
	tar xzf ~/EasyRSA-3.0.3.tgz -C ~/
	mv ~/EasyRSA-3.0.3/ /etc/openvpn/
	mv /etc/openvpn/EasyRSA-3.0.3/ /etc/openvpn/easy-rsa/
	chown -R root:root /etc/openvpn/easy-rsa/
	rm -rf ~/EasyRSA-3.0.3.tgz
	cd /etc/openvpn/easy-rsa/
	echo "set_var EASYRSA_KEY_SIZE $RSA_KEY_SIZE" > vars
	./easyrsa init-pki
	./easyrsa --batch build-ca nopass
	openssl dhparam -out dh.pem $DH_KEY_SIZE
	./easyrsa build-server-full server nopass
	./easyrsa build-client-full $CLIENT nopass
	EASYRSA_CRL_DAYS=3650 ./easyrsa gen-crl
	openvpn --genkey --secret /etc/openvpn/tls-auth.key
	cp pki/ca.crt pki/private/ca.key dh.pem pki/issued/server.crt pki/private/server.key /etc/openvpn/easy-rsa/pki/crl.pem /etc/openvpn
	chmod 644 /etc/openvpn/crl.pem
	echo "port $PORT" > /etc/openvpn/server.conf
	echo "proto tcp" >> /etc/openvpn/server.conf
	echo "dev tun
user nobody
group $NOGROUP
persist-key
persist-tun
keepalive 10 120
topology subnet
server 10.8.0.0 255.255.255.0
ifconfig-pool-persist ipp.txt" >> /etc/openvpn/server.conf
echo 'push "dhcp-option DNS 198.251.90.143"' >> /etc/openvpn/server.conf
echo 'push "redirect-gateway def1 bypass-dhcp" '>> /etc/openvpn/server.conf
echo "crl-verify crl.pem
ca ca.crt
cert server.crt
key server.key
tls-auth tls-auth.key 0
dh dh.pem
auth SHA256
$CIPHER
tls-server
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-128-GCM-SHA256
status /dev/null
log-append /dev/null
verb 0" >> /etc/openvpn/server.conf
	if [[ ! -e $SYSCTL ]]; then
		touch $SYSCTL
	fi
	sed -i '/\<net.ipv4.ip_forward\>/c\net.ipv4.ip_forward=1' $SYSCTL
	if ! grep -q "\<net.ipv4.ip_forward\>" $SYSCTL; then
		echo 'net.ipv4.ip_forward=1' >> $SYSCTL
	fi
	echo 1 > /proc/sys/net/ipv4/ip_forward
	iptables -t nat -A POSTROUTING -o $NIC -s 10.8.0.0/24 -j MASQUERADE
	iptables-save > $IPTABLES
	if pgrep firewalld; then
		if [[ "$PROTOCOL" = 'UDP' ]]; then
			firewall-cmd --zone=public --add-port=$PORT/udp
			firewall-cmd --permanent --zone=public --add-port=$PORT/udp
		elif [[ "$PROTOCOL" = 'TCP' ]]; then
			firewall-cmd --zone=public --add-port=$PORT/tcp
			firewall-cmd --permanent --zone=public --add-port=$PORT/tcp
		fi
		firewall-cmd --zone=trusted --add-source=10.8.0.0/24
		firewall-cmd --permanent --zone=trusted --add-source=10.8.0.0/24
	fi
	if iptables -L -n | grep -qE 'REJECT|DROP'; then
		if [[ "$PROTOCOL" = 'UDP' ]]; then
			iptables -I INPUT -p udp --dport $PORT -j ACCEPT
		elif [[ "$PROTOCOL" = 'TCP' ]]; then
			iptables -I INPUT -p tcp --dport $PORT -j ACCEPT
		fi
		iptables -I FORWARD -s 10.8.0.0/24 -j ACCEPT
		iptables -I FORWARD -m state --state RELATED,ESTABLISHED -j ACCEPT
        iptables-save > $IPTABLES
	fi
	if hash sestatus 2>/dev/null; then
		if sestatus | grep "Current mode" | grep -qs "enforcing"; then
			if [[ "$PORT" != '1194' ]]; then
				# semanage isn't available in CentOS 6 by default
				if ! hash semanage 2>/dev/null; then
					yum install policycoreutils-python -y
				fi
				if [[ "$PROTOCOL" = 'UDP' ]]; then
					semanage port -a -t openvpn_port_t -p udp $PORT
				elif [[ "$PROTOCOL" = 'TCP' ]]; then
					semanage port -a -t openvpn_port_t -p tcp $PORT
				fi
			fi
		fi
	fi
	if [[ "$OS" = 'debian' ]]; then
		if pgrep systemd-journal; then
				sed -i 's|LimitNPROC|#LimitNPROC|' /lib/systemd/system/openvpn\@.service
				sed -i 's|/etc/openvpn/server|/etc/openvpn|' /lib/systemd/system/openvpn\@.service
				sed -i 's|%i.conf|server.conf|' /lib/systemd/system/openvpn\@.service
				systemctl daemon-reload
				systemctl restart openvpn
				systemctl enable openvpn
		else
			/etc/init.d/openvpn restart
		fi
	else
		if pgrep systemd-journal; then
			if [[ "$OS" = 'arch' || "$OS" = 'fedora' ]]; then
				sed -i 's|/etc/openvpn/server|/etc/openvpn|' /usr/lib/systemd/system/openvpn-server@.service
				sed -i 's|%i.conf|server.conf|' /usr/lib/systemd/system/openvpn-server@.service
				systemctl daemon-reload
				systemctl restart openvpn-server@openvpn.service
				systemctl enable openvpn-server@openvpn.service
			else
				systemctl restart openvpn@server.service
				systemctl enable openvpn@server.service
			fi
		else
			service openvpn restart
			chkconfig openvpn on
		fi
	fi
	echo "client" > /etc/openvpn/client-template.txt
  echo "proto tcp-client" >> /etc/openvpn/client-template.txt
echo "remote $IP $PORT
dev tun
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
auth SHA256
auth-nocache
$CIPHER
tls-client
tls-version-min 1.2
tls-cipher TLS-DHE-RSA-WITH-AES-128-GCM-SHA256
setenv opt block-outside-dns
verb 3" >> /etc/openvpn/client-template.txt
	newclient "$CLIENT"
	echo "A test .ovpn file is located at $homeDir/$CLIENT.ovpn"
fi
exit 0;
