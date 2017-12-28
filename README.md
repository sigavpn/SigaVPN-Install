# SigaVPN-Install
A script that we use to make our SigaVPN servers. It deadsimple to install.

Auto-configure settings:

- No logs (set to /dev/null)
- AES-128
- RSA-4096
- OpenNIC no-log anycast DNS (ns5.any.dns.opennic.glue)
- TCP/443
- tls-version-min 1.2
- 3072 Bit Diffie-Hellman key
- no compression

Run sigavpn-setup.sh to set up the OpenVPN server and clientgen.sh to make a new client.


https://sigavpn.com
