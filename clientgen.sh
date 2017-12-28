#!/bin/sh
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

                        var=`date +%s%N`
                        cd /etc/openvpn/easy-rsa/
                        ./easyrsa build-client-full $var nopass
                        newclient "$var"
                        mv ~/$var.ovpn /var/www/$var.ovpn
                        echo "http://yourdomain.com/$var.ovpn"
exit
;;
