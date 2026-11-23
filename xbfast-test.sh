#!/bin/sh
set -eu
. "${1:-./xbfast.sh}"
router=192.168.1.1
netmask=255.255.255.0

expect_ipv4() {
    if valid_ip "$2"; then actual=yes; else actual=no; fi
    test "$actual" = "$1" || { echo "IPv4 case failed: $2"; exit 1; }
}

expect_ipv4 yes 192.168.1.20
expect_ipv4 yes 39.136.121.17
expect_ipv4 no 192.168.1.06
expect_ipv4 no 192.168.1.256
expect_ipv4 no '1.2.3.4;echo x'
expect_ipv4 no '1.2.3.4 5.6.7.8'
for ip in 127.0.0.1 169.254.169.254 192.168.1.1 10.1.2.3 100.64.0.1 224.0.0.1; do
    ! public_ip "$ip" || exit 1
done
public_ip 39.136.121.17
public_ip 23.211.177.166
test "$(normalize_ips '39.136.121.17, 58.216.30.197 39.136.121.17' public 8)" = '39.136.121.17 58.216.30.197'
! normalize_ips '39.136.121.17 127.0.0.1' public 8 || exit 1
! normalize_ips '192.168.1.20 192.168.1.21' device 1 || exit 1
test "$(normalize_ips '192.168.1.20 192.168.1.21' device 16)" = '192.168.1.20 192.168.1.21'
! normalize_ips '192.168.2.7' device 16 || exit 1
! normalize_ips '192.168.1.1' device 16 || exit 1
router=10.4.0.1
netmask=255.255.254.0
test "$(normalize_ips '10.4.1.1 10.4.0.255' device 16)" = '10.4.1.1 10.4.0.255'
! normalize_ips '10.4.0.0' device 16 || exit 1
! normalize_ips '10.4.1.255' device 16 || exit 1
! normalize_ips '10.4.2.1' device 16 || exit 1
netmask=255.255.253.0
! normalize_ips '10.4.0.2' device 16 || exit 1
echo 'IPv4, subnet scope, deduplication and limits: 25 checks passed'
