#!/bin/sh

PATH=/koolshare/bin:/sbin:/usr/sbin:/bin:/usr/bin
export PATH
set -f
umask 022

valid_ip() {
    printf '%s\n' "$1" | awk -F. 'NR != 1 || NF != 4 {bad=1} {for(i=1;i<=NF;i++) if($i !~ /^[0-9]+$/ || length($i)>3 || ($i+0)>255 || (length($i)>1 && $i ~ /^0/)) bad=1} END{exit bad || NR!=1}'
}

public_ip() {
    valid_ip "$1" || return 1
    case "$1" in
        0.*|10.*|127.*|169.254.*|172.1[6-9].*|172.2?.*|172.3[01].*|192.168.*|192.0.0.*|192.0.2.*|198.1[89].*|198.51.100.*|203.0.113.*|100.6[4-9].*|100.[7-9]?.*|100.1[01]?.*|100.12[0-7].*|22[4-9].*|23?.*|24?.*|25?.*) return 1;;
    esac
}

device_ip() {
    valid_ip "$1" && valid_ip "$router" && valid_ip "$netmask" || return 1
    [ "$netmask" != 0.0.0.0 ] || return 1
    awk -v ip="$1" -v gateway="$router" -v mask="$netmask" 'BEGIN {
        split(ip,a,"."); split(gateway,b,"."); split(mask,c,".")
        host=0; span=1; opened=0
        for(i=1;i<=4;i++) {
            block=256-c[i]
            if((opened && block!=256) || (block!=1 && block!=2 && block!=4 && block!=8 && block!=16 && block!=32 && block!=64 && block!=128 && block!=256)) exit 1
            if(int(a[i]/block)!=int(b[i]/block)) exit 1
            if(block>1) opened=1
            host=host*block+a[i]%block; span*=block
        }
        exit !(ip!=gateway && host>0 && host<span-1)
    }'
}

normalize_ips() {
    [ "${#1}" -le 400 ] || return 1
    tokens=$(printf '%s' "$1" | tr ',;\r\n\t' '     ')
    found= n=0
    for candidate in $tokens; do
        case "$2" in
            device) device_ip "$candidate" || return 1;;
            public) public_ip "$candidate" || return 1;;
            *) return 1;;
        esac
        case " $found " in *" $candidate "*) continue;; esac
        n=$((n+1)); [ "$n" -le "$3" ] || return 1
        found="${found:+$found }$candidate"
    done
    printf '%s\n' "$found"
}

root=/koolshare/xbfast
run=/tmp/xbfast
cron_spool=/var/spool/cron/crontabs
iptables_matches=/proc/net/ip_tables_matches
firmware_modprobe=/sbin/modprobe
alias_ip=192.0.2.253
dnsport=15354
httpport=18081
nat_chain=XBFAST_NAT
input_chain=XBFAST_IN
dev_set=xbfast_devices
cdn_set=xbfast_cdn
main_hosts='assets1.xboxlive.com assets2.xboxlive.com d1.xboxlive.com d2.xboxlive.com xvcf1.xboxlive.com xvcf2.xboxlive.com 5.xb.delivery.microsoft.com assets1.xboxlive.com.edgesuite.net cl-glcb907925.gcdn.co fg.microsoft.map.fastly.net'
legacy_hosts='dlassets.xboxlive.com dlassets2.xboxlive.com'
get() { dbus get "xbfast_$1"; }
put() { dbus set "xbfast_$1=$2"; }
request_id() { printf '%s\n' "$1" | grep -Eq '^[0-9]{1,16}$'; }
watchdog() { cru a XBFAST '*/1 * * * * /koolshare/scripts/xbfast_repair.sh'; }

profile() {
    case "$1" in
        main) host=assets1.xboxlive.cn; path=/Z/routing/extraextralarge.txt; scheme=http; port=80;;
        legacy) host=dlassets.xboxlive.cn; path=/public/content/0044aef3-bd7e-4478-8782-6191546dcd9a/f6585e19-765c-49c3-ba77-326c3766e05a/1.0.4.0.60281fce-b9c0-49f6-a475-90eae0259f8c/ACBF_1.0.4.0_x64__b6krnev7r9sf8; scheme=http; port=80;;
        store_dl) host=dl.delivery.mp.microsoft.com; path=; scheme=http; port=80;;
        store_tlu) host=tlu.dl.delivery.mp.microsoft.com; path=; scheme=http; port=80;;
        *) return 1;;
    esac
}

read_config() {
    if [ "$1" = edit_ ]; then
        [ "${#payload}" -le 1400 ] || return 1
        IFS='|' read -r requested enabled autostart xbox store devices main legacy store_dl store_tlu all_devices sentinel <<EOF
$payload
EOF
        if [ "$all_devices" = end ] && [ -z "$sentinel" ]; then all_devices=0; sentinel=end; fi
        [ "$sentinel" = end ] || return 1
    else
        enabled=$(get cfg_enabled); xbox=$(get cfg_xbox); store=$(get cfg_store)
        autostart=$(get cfg_autostart); devices=$(get cfg_devices)
        all_devices=$(get cfg_all_devices)
        main=$(get cfg_main); legacy=$(get cfg_legacy); store_dl=$(get cfg_store_dl); store_tlu=$(get cfg_store_tlu)
    fi
    autostart=${autostart:-0}; all_devices=${all_devices:-0}
    enabled=${enabled:-0}; xbox=${xbox:-1}; store=${store:-0}
    for flag in "$enabled" "$xbox" "$store" "$autostart" "$all_devices"; do case "$flag" in 0|1) ;; *) return 1;; esac; done
    devices=$(normalize_ips "$devices" device 16) || return 1
    main=$(normalize_ips "$main" public 8) || return 1
    legacy=$(normalize_ips "$legacy" public 8) || return 1
    store_dl=$(normalize_ips "$store_dl" public 8) || return 1
    store_tlu=$(normalize_ips "$store_tlu" public 8) || return 1
    if [ "$enabled" = 1 ]; then
        { [ "$all_devices" = 1 ] || [ -n "$devices" ]; } && [ "$xbox$store" != 00 ] || return 1
    fi
}

save_config() {
    put cfg_enabled "$enabled" && put cfg_autostart "$autostart" && put cfg_devices "$devices" && put cfg_all_devices "$all_devices" && put cfg_xbox "$xbox" && put cfg_store "$store" &&
        put cfg_main "$main" && put cfg_legacy "$legacy" && put cfg_store_dl "$store_dl" && put cfg_store_tlu "$store_tlu" && put enable "$enabled"
}

alive() {
    proc_id=$(cat "$run/$1.pid" 2>/dev/null) || return 1
    case "$proc_id" in ''|*[!0-9]*) return 1;; esac
    [ -r "/proc/$proc_id/cmdline" ] && tr '\000' '\n' 2>/dev/null < "/proc/$proc_id/cmdline" | grep -Fxq "$run/$1.conf"
}

wait_start() {
    for attempt in 1 2 3 4 5; do
        alive "$1" && return 0
        sleep 1
    done
    alive "$1"
}

remove_nat_jumps() (
    interfaces=$(awk -v chain="$nat_chain" '$1=="-A" && $2=="PREROUTING" && NF==6 && $3=="-i" && $5=="-j" && $6==chain {print $4}') || exit 1
    for iface in $interfaces; do iptables -t nat -D PREROUTING -i "$iface" -j "$nat_chain" || exit 1; done
)

drop_nat_hook() {
    hooks=$(iptables -t nat -S PREROUTING) || return 1
    printf '%s\n' "$hooks" | remove_nat_jumps
}

owned_chain_rules() {
    awk -v chain="$1" '($1=="-N" && $2==chain) || ($1=="-A" && ($2==chain || ($NF==chain && ($(NF-1)=="-j" || $(NF-1)=="-g"))))'
}

clear_firewall_chain() (
    table=$1 chain=$2
    rules=$(iptables -t "$table" -S) || exit 1
    owned=$(printf '%s\n' "$rules" | owned_chain_rules "$chain") || exit 1
    [ -n "$owned" ] || exit 0
    case "$table" in
        nat) printf '%s\n' "$owned" | remove_nat_jumps || exit 1;;
        filter)
            printf '%s\n' "$owned" | while IFS= read -r rule; do
                if [ "$rule" = "-A INPUT -j $chain" ]; then iptables -D INPUT -j "$chain" || exit 1; fi
            done || exit 1;;
    esac
    if printf '%s\n' "$owned" | grep -Fxq -- "-N $chain"; then
        iptables -t "$table" -F "$chain" && iptables -t "$table" -X "$chain" || exit 1
    fi
    rules=$(iptables -t "$table" -S) || exit 1
    owned=$(printf '%s\n' "$rules" | owned_chain_rules "$chain") || exit 1
    [ -z "$owned" ]
)

clear_firewall_sets() (
    sets=$(ipset list -n) || exit 1
    changed=0
    for name in $sets; do
        case "$name" in "$dev_set"|"$cdn_set") ipset destroy "$name" || exit 1; changed=1;; esac
    done
    [ "$changed" = 1 ] || exit 0
    sets=$(ipset list -n) || exit 1
    for name in $sets; do
        case "$name" in "$dev_set"|"$cdn_set") exit 1;; esac
    done
)

clean_runtime() {
    clear_firewall_chain nat "$nat_chain" || return 1
    for service in dns light; do
        if alive "$service"; then kill "$proc_id" 2>/dev/null; fi
    done
    for attempt in 1 2 3 4 5; do
        if ! alive dns && ! alive light; then break; fi
        sleep 1
    done
    if alive dns || alive light; then return 1; fi
    rm -f "$run/dns.pid" "$run/light.pid" || return 1
    clear_firewall_chain filter "$input_chain" && clear_firewall_sets
}

stop_runtime() {
    if clean_runtime; then
        put runtime stopped
    else
        printf '%s\n' 'XBFAST: runtime cleanup incomplete; retry before removing the plug-in.' >&2
        put runtime cleanup_error
        return 1
    fi
}

apply_failed() {
    if stop_runtime; then put runtime error; fi
    return 1
}

read_crontab() (
    owner=$(nvram get http_username) || exit 1
    case "$owner" in ''|.|..|*[!a-zA-Z0-9_.-]*) exit 1;; esac
    [ -d "$cron_spool" ] && [ -r "$cron_spool" ] && [ -x "$cron_spool" ] || exit 1
    tab=$cron_spool/$owner
    if [ -e "$tab" ] || [ -L "$tab" ]; then
        [ -f "$tab" ] && cat "$tab" || exit 1
    fi
)

clear_watchdog() (
    cron_jobs=$(read_crontab) || exit 1
    marker=$(printf '%s\n' "$cron_jobs" | awk '/#XBFAST#$/ {print 1; exit}') || exit 1
    [ -n "$marker" ] || exit 0
    cru d XBFAST || exit 1
    cron_jobs=$(read_crontab) || exit 1
    marker=$(printf '%s\n' "$cron_jobs" | awk '/#XBFAST#$/ {print 1; exit}') || exit 1
    [ -z "$marker" ]
)

ensure_watchdog() (
    cron_jobs=$(read_crontab) || exit 1
    case "$cron_jobs" in *'#XBFAST#'*)
        if printf '%s\n' "$cron_jobs" | grep -q '#XBFAST#$'; then exit 0; fi;;
    esac
    watchdog || exit 1
    cron_jobs=$(read_crontab) || exit 1
    printf '%s\n' "$cron_jobs" | grep -q '#XBFAST#$'
)

clear_nat_event() (
    key=__event__onnatstart_xbfast
    entries=$(dbus list "$key") || exit 1
    marker=$(printf '%s\n' "$entries" | awk -F= -v key="$key" '$1==key && NF>1 {print 1; exit}') || exit 1
    [ -n "$marker" ] || exit 0
    dbus remove "$key" || exit 1
    entries=$(dbus list "$key") || exit 1
    marker=$(printf '%s\n' "$entries" | awk -F= -v key="$key" '$1==key && NF>1 {print 1; exit}') || exit 1
    [ -z "$marker" ]
)

purge_runtime() (
    lock measure || exit 1
    rm -f "$run/boot.pending" || exit 1
    if ! clear_watchdog; then
        printf '%s\n' 'XBFAST: could not verify removal of the scheduled repair task; retry uninstall.' >&2
        exit 1
    fi
    if ! clear_nat_event; then
        printf '%s\n' 'XBFAST: could not verify removal of the NAT repair event; retry uninstall.' >&2
        exit 1
    fi
    stop_runtime || exit 1
    rm -f "$run/requested" "$run/isp-dns" "$run/dns.conf" "$run/light.conf" "$run/xbfast-dns" "$run/boot.log" "$run/discovery" || exit 1
    rmdir "$run/empty"
)

isp_servers() {
    for addr in $(nvram get wan0_dns) $(nvram get wan0_xdns); do
        public_ip "$addr" && printf '%s\n' "$addr"
    done | sort -u | head -3
}

dns_profile() {
    target=$1; pins=$2
    printf 'ipset=/%s/%s\n' "$target" "$cdn_set"
    if [ -n "$pins" ]; then
        for pin in $pins; do
            printf 'host-record=%s,%s\n' "$target" "$pin"
        done
    else
        for resolver in $resolvers; do
            printf 'server=/%s/%s\n' "$target" "$resolver"
        done
    fi
}

write_configs() {
    resolvers=$(isp_servers)
    {
        printf 'port=%s\nlisten-address=%s,127.0.0.1\nbind-interfaces\nno-resolv\nno-hosts\ncache-size=150\nlocal-ttl=20\nserver=127.0.0.1#53\npid-file=%s/dns.pid\n' "$dnsport" "$router" "$run"
        if [ "$xbox" = 1 ]; then
            for name in $main_hosts $legacy_hosts; do printf 'host-record=%s,%s\n' "$name" "$alias_ip"; done
            dns_profile assets1.xboxlive.cn "$main"
            dns_profile dlassets.xboxlive.cn "$legacy"
        fi
        if [ "$store" = 1 ]; then
            dns_profile dl.delivery.mp.microsoft.com "$store_dl"
            dns_profile tlu.dl.delivery.mp.microsoft.com "$store_tlu"
        fi
    } > "$run/dns.conf" && dnsmasq --test -C "$run/dns.conf" || return 1
    if [ "$xbox" = 1 ]; then
        sed "s|@RUN@|$run|g; s|@ROUTER@|$router|g; s|@PORT@|$httpport|g" "$root/lighttpd.conf" > "$run/light.conf" &&
            /usr/sbin/lighttpd -tt -m /usr/lib -f "$run/light.conf" || return 1
    fi
}

build_rules() {
    if [ "${all_devices:-0}" = 1 ]; then
        [ "$netmask" != 0.0.0.0 ] || return 1
        set -- -s "$router/$netmask"
    else
        ipset create "$dev_set" hash:ip hashsize 64 maxelem 16 || return 1
        for addr in $devices; do ipset add "$dev_set" "$addr" || return 1; done
        set -- -m set --match-set "$dev_set" src
    fi
    ipset create "$cdn_set" hash:ip hashsize 64 timeout 86400 maxelem 1024 || return 1
    pins=
    [ "$xbox" != 1 ] || pins="$main $legacy"
    [ "$store" != 1 ] || pins="$pins $store_dl $store_tlu"
    for addr in $pins; do ipset -! add "$cdn_set" "$addr" timeout 0 || return 1; done
    iptables -N "$input_chain" && iptables -t nat -N "$nat_chain" || return 1
    iptables -A "$input_chain" -i lo -j RETURN &&
        iptables -A "$input_chain" ! -d "$router" -j RETURN &&
        iptables -A "$input_chain" -i "$bridge" "$@" -j RETURN &&
        iptables -A "$input_chain" -p udp --dport "$dnsport" -j DROP &&
        iptables -A "$input_chain" -p tcp -m multiport --dports "$dnsport,$httpport" -j DROP &&
        iptables -I INPUT 1 -j "$input_chain" || return 1
    if [ "${all_devices:-0}" = 1 ]; then
        iptables -t nat -A "$nat_chain" ! -s "$router/$netmask" -j RETURN || return 1
        iptables -t nat -A "$nat_chain" -s "$router" -j RETURN || return 1
    else
        iptables -t nat -A "$nat_chain" -m set ! --match-set "$dev_set" src -j RETURN || return 1
    fi
    iptables -t nat -A "$nat_chain" -p udp --dport 53 -j REDIRECT --to-ports "$dnsport" &&
    iptables -t nat -A "$nat_chain" -p tcp --dport 53 -j REDIRECT --to-ports "$dnsport" || return 1
    if [ "$xbox" = 1 ]; then
        iptables -t nat -A "$nat_chain" -d "$alias_ip" -p tcp --dport 80 -j REDIRECT --to-ports "$httpport" || return 1
    fi
    iptables -t nat -A "$nat_chain" -p tcp -m multiport --dports 80,443 -m set --match-set "$cdn_set" dst -j ACCEPT
}

ensure_set_match() {
    grep -Fxq set "$iptables_matches" 2>/dev/null && return 0
    if [ -x "$firmware_modprobe" ] && "$firmware_modprobe" xt_set && grep -Fxq set "$iptables_matches" 2>/dev/null; then
        return 0
    fi
    printf '%s\n' 'XBFAST: firmware IPv4 iptables set match unavailable (xt_set).' >&2
    return 1
}

apply_config() {
    apply_stage=cleanup
    stop_runtime || return 1
    [ "$enabled" = 1 ] || return 0
    apply_stage=lan
    valid_ip "$router" && valid_ip "$netmask" || return 1
    apply_stage=kernel-set
    ensure_set_match || return 1
    apply_stage=config-check
    write_configs || return 1
    apply_stage=firewall
    build_rules || return 1
    apply_stage=http
    if [ "$xbox" = 1 ]; then /usr/sbin/lighttpd -m /usr/lib -f "$run/light.conf" && wait_start light || return 1; fi
    apply_stage=dns
    dns_binary=$(which dnsmasq) || return 1
    case "$dns_binary" in /*) ;; *) return 1;; esac
    ln -sf "$dns_binary" "$run/xbfast-dns" && "$run/xbfast-dns" -C "$run/dns.conf" && wait_start dns || return 1
    apply_stage=nat-hook
    iptables -t nat -I PREROUTING 1 -i "$bridge" -j "$nat_chain" || return 1
    isp_servers > "$run/isp-dns"
    apply_stage=state
    put runtime running
}

repair() {
    [ "$(get cfg_enabled)" = 1 ] || return 0
    if [ ! -f "$run/requested" ] && [ "$(get cfg_autostart)" != 1 ]; then
        [ "$(get runtime)" = stopped ] || stop_runtime
        return $?
    fi
    apply_stage=settings
    read_config cfg_ || { apply_failed; return 1; }
    if [ ! -f "$run/requested" ]; then
        : > "$run/requested" || return 1
    fi
    if ! alive dns || { [ "$xbox" = 1 ] && ! alive light; } ||
        [ "$(isp_servers)" != "$(cat "$run/isp-dns" 2>/dev/null)" ] ||
        ! iptables -S INPUT | grep -Fxq -- "-A INPUT -j $input_chain" ||
        ! iptables -t nat -L "$nat_chain" -n >/dev/null 2>&1; then
        apply_config || { apply_failed; return 1; }
    elif [ "$(iptables -t nat -S PREROUTING | sed -n '2p')" != "-A PREROUTING -i $bridge -j $nat_chain" ]; then
        apply_stage=nat-hook
        drop_nat_hook || return 1
        iptables -t nat -I PREROUTING 1 -i "$bridge" -j "$nat_chain"
    fi
}

valid_bridge() {
    case "$bridge" in ''|.|..|*[!a-zA-Z0-9_.-]*) return 1;; esac
}

boot_requested() {
    [ "$(get cfg_enabled)" = 1 ] && [ "$(get cfg_autostart)" = 1 ]
}

boot_lan_ready() {
    valid_bridge && [ -d "/sys/class/net/$bridge" ] && valid_ip "$router" && valid_ip "$netmask" &&
        [ "$router" != 0.0.0.0 ] && [ "$netmask" != 0.0.0.0 ]
}

boot_settled() {
    awk 'NR==1 {exit !($1>=180)} END {if(NR==0) exit 1}' /proc/uptime
}

boot_step() {
    boot_attempt=$1
    [ -f "$run/boot.pending" ] || return 2
    if ! boot_requested; then
        rm -f "$run/boot.pending" || return 1
        return 2
    fi
    apply_stage=lan
    watchdog_stage=waiting
    if boot_lan_ready; then
        if repair; then apply_stage=ready; fi
        if ensure_watchdog; then watchdog_stage=ready; else watchdog_stage=unverified; fi
    fi
    printf 'attempt=%s service=%s watchdog=%s\n' "$boot_attempt" "$apply_stage" "$watchdog_stage" >> "$run/boot.log" || :
    if [ "$apply_stage:$watchdog_stage" = ready:ready ] && { [ "$boot_attempt" = 7 ] || boot_settled; }; then
        rm -f "$run/boot.pending"
        return $?
    fi
    if [ "$boot_attempt" = 7 ]; then rm -f "$run/boot.pending"; fi
    return 1
}

boot_worker() {
    boot_attempt=0
    for delay in 2 5 10 20 30 55 60; do
        sleep "$delay"
        [ "$(cat "$run/boot.pending" 2>/dev/null)" = "$$" ] || return 0
        boot_attempt=$((boot_attempt+1))
        sh "$root/xbfast.sh" boot-step "$boot_attempt" "$$"
        case $? in 0|2) return 0;; esac
    done
    return 1
}

queue_boot_worker() {
    worker=$(cat "$run/boot.pending" 2>/dev/null) || worker=
    case "$worker" in ''|0|*[!0-9]*) ;; *) if kill -0 "$worker" 2>/dev/null; then return 0; fi;; esac
    : > "$run/boot.log" || return 1
    sh "$root/xbfast.sh" boot-worker </dev/null >/dev/null 2>&1 &
    printf '%s\n' "$!" > "$run/boot.pending"
}

repair_entry() {
    [ "$(get cfg_enabled)" = 1 ] || return 0
    if boot_requested; then
        if ! boot_settled; then queue_boot_worker || return 1; fi
    elif [ ! -f "$run/requested" ]; then
        repair
        return $?
    fi
    repair_result=0
    watchdog_result=0
    if boot_lan_ready; then repair || repair_result=1; else repair_result=1; fi
    ensure_watchdog || watchdog_result=1
    if [ "$watchdog_result" != 0 ]; then
        printf '%s\n' 'XBFAST: could not verify the scheduled repair task.' >&2
    fi
    if [ "$repair_result:$watchdog_result" != 0:0 ] && boot_requested; then
        queue_boot_worker || return 1
    fi
    [ "$repair_result:$watchdog_result" = 0:0 ]
}

schedule_boot() {
    if boot_requested; then queue_boot_worker; else repair_entry; fi
}

mark_requested() {
    if [ "$enabled" = 1 ]; then
        : > "$run/requested" && watchdog
    else
        rm -f "$run/requested" "$run/boot.pending" || return 1
        cru d XBFAST 2>/dev/null || :
    fi
}

score() {
    if [ -n "$path" ]; then
        measure=$(/koolshare/bin/curl -q -s --globoff --noproxy '*' -4 --connect-timeout 2 --max-time 5 --max-filesize 8388608 \
            --resolve "$host:$port:$1" -r 0-8388607 -o /dev/null -w '%{http_code} %{size_download} %{speed_download}' "$scheme://$host$path") || {
            printf '下载测速未完成'; return 0;
        }
        set -- $measure
        if [ "${1:-}" = 206 ] && awk -v b="${2:-0}" 'BEGIN{exit !(b>=65536)}'; then
            awk -v b="$3" 'BEGIN{printf "%.2f Mbps",b*8/1000000}'
        else
            printf '不支持测试文件或超时 (HTTP %s)' "${1:-000}"
        fi
    else
        measure=$(/koolshare/bin/curl -q -s --noproxy '*' -4 --connect-timeout 2 --max-time 4 \
            --resolve "$host:$port:$1" -I -o /dev/null -w '%{http_code} %{time_starttransfer}' "$scheme://$host/")
        set -- $measure
        if [ "${1:-000}" != 000 ]; then
            awk -v t="${2:-0}" -v h="$1" 'BEGIN{printf "响应 %.0f ms (HTTP %s)",t*1000,h}'
        else
            printf '连接失败或超时'
        fi
    fi
}

locations_for() {
    directory=$root/geo
    lookup=$root/lookup.awk
    case $(cat "$root/geo-current" 2>/dev/null) in
        geo-a) directory=$root/geo-a;;
        geo-b) directory=$root/geo-b;;
    esac
    [ -r "$lookup" ] || return 0
    prefixes=
    for addr in $1; do
        prefix=${addr%%.*}
        case "$prefix" in ''|*[!0-9]*) continue;; esac
        [ "${#prefix}" -le 3 ] || continue
        case " $prefixes " in *" $prefix "*) continue;; esac
        prefixes="${prefixes:+$prefixes }$prefix"
        if [ -r "$directory/$prefix.dat.gz" ]; then
            gzip -dc "$directory/$prefix.dat.gz" | head -c 2097152 | awk -v prefix="$prefix" -v queries="$1" -f "$lookup"
        fi
    done
}

known_devices() {
    {
        if [ -r "$1" ]; then head -n 512 "$1" | awk 'NF>=4 {print $3,$4}'; fi
        if [ -r "$2" ]; then head -n 512 "$2" | awk -v bridge="$bridge" '$6==bridge && $3=="0x2" {print $1,"*"}'; fi
    } | awk -v gateway="$router" -v mask="$netmask" '
        BEGIN { split(gateway,gw,"."); split(mask,nm,"."); }
        function scoped(ip,parts,i,block,offset,count) {
            if (split(ip,parts,".")!=4 || ip==gateway || mask=="0.0.0.0") return 0
            offset=0; count=1
            for(i=1;i<=4;i++) {
                block=256-nm[i]
                if (block<1 || parts[i] !~ /^(0|[1-9][0-9]?[0-9]?)$/ || parts[i]+0>255 || int(parts[i]/block)!=int(gw[i]/block)) return 0
                offset=offset*block+parts[i]%block; count*=block
            }
            return offset>0 && offset<count-1
        }
        length($1)<=15 && scoped($1) && !seen[$1]++ {
            host=($2 ~ /^[A-Za-z0-9_.-]+$/ && length($2)<=32) ? $2 : ""
            if (count++) printf ";"
            printf "%s|%s", $1, host
            if (count>=48) exit
        }'
}

discovery_time() {
    awk 'NR==1 && $1 ~ /^[0-9]+\.[0-9]+$/ {printf "%.0f\n",int($1)}' /proc/uptime
}

measure_job() {
    operation=$(get edit_job)
    category=$(get edit_profile)
    profile "$category" || return 1
    case "$operation" in
        discover)
            rm -f "$run/discovery" || return 1
            put candidates '' && put locations '' && put resolvers '' || return 1
            resolvers=$(isp_servers)
            [ -n "$resolvers" ] || return 2
            rows=$(
                for resolver in $resolvers; do
                    nslookup "$host" "$resolver" 2>/dev/null | awk '
                        /^Name:/ { answer=1 }
                        answer && /^Address: *[0-9]/ {print $2}
                        answer && /^Address [0-9]+:/ {print $3}' &
                done
                wait
            )
            valid=
            candidates=$(printf '%s\n' "$rows" | awk 'NF && !seen[$1]++ {print $1}' | head -32)
            count=0
            for addr in $candidates; do
                public_ip "$addr" || continue
                valid="${valid:+$valid }$addr"
                count=$((count+1)); [ "$count" -lt 16 ] || break
            done
            [ -n "$valid" ] || return 3
            stamp=$(discovery_time) || return 1
            case "$stamp" in ''|*[!0-9]*) return 1;; esac
            printf '%s|%s|%s|%s\n' "$requested" "$category" "$stamp" "$valid" > "$run/discovery" || return 1
            put candidates "$valid" && put resolvers "$(echo $resolvers)" && put locations "$(locations_for "$valid")";;
        test)
            discovery=$(get edit_discovery)
            request_id "$discovery" || return 4
            [ -r "$run/discovery" ] || return 4
            IFS='|' read -r snapshot snapshot_category stamp recent < "$run/discovery" || return 4
            [ "$snapshot:$snapshot_category" = "$discovery:$category" ] || return 4
            now=$(discovery_time) || return 4
            case "$now:$stamp" in :*|*:|*[!0-9:]*) return 4;; esac
            [ "$now" -ge "$stamp" ] && [ "$((now-stamp))" -lt 300 ] || return 4
            candidates=$(normalize_ips "$(get edit_candidates)" public 16) || return 1
            [ -n "$candidates" ] || return 1
            for addr in $candidates; do
                case " $recent " in *" $addr "*) ;; *) return 4;; esac
            done
            case "$host" in *.delivery.mp.microsoft.com)
                sample=$(get edit_sample)
                if [ -n "$sample" ]; then
                    case "$sample" in
                        "http://$host/"*) sample=${sample#"http://$host"};;
                        "https://$host/"*) sample=${sample#"https://$host"}; scheme=https; port=443;;
                    esac
                    [ "${#sample}" -le 350 ] && printf '%s\n' "$sample" | awk 'NR!=1 || !/^\/[A-Za-z0-9._%~+\/-]+$/ {bad=1} END{exit bad || NR!=1}' || return 1
                    path=$sample
                fi;;
            esac
            put locations "$(locations_for "$recent")" || return 1
            index=0
            for addr in $candidates; do
                index=$((index+1))
                put "result_$index" "$addr $(score "$addr")" || return 1
            done;;
        *) return 1;;
    esac
}

lock() {
    lockdir=$run/$1.lock
    if ! mkdir -m 700 "$lockdir" 2>/dev/null; then
        owner=$(cat "$lockdir/pid" 2>/dev/null) || return 1
        case "$owner" in ''|*[!0-9]*) return 1;; esac
        [ ! -d "/proc/$owner" ] || return 1
        rm -f "$lockdir/pid" && rmdir "$lockdir" && mkdir -m 700 "$lockdir" || return 1
    fi
    echo "$$" > "$lockdir/pid"
    trap 'rm -f "$lockdir/pid"; rmdir "$lockdir" 2>/dev/null' EXIT
    trap 'exit 1' HUP INT TERM
}

command=${1:-save}
case "${0##*/}" in xbfast-test.sh|xbfast-runtime-test.sh) return 0;; esac
router=$(nvram get lan_ipaddr)
netmask=$(nvram get lan_netmask)
bridge=$(nvram get lan_ifname)
case "$command" in
    boot|boot-worker|boot-step|stop|purge) ;;
    save|repair|measure|devices) valid_bridge || exit 1;;
    *) exit 2;;
esac
if [ "$command" = boot-worker ]; then boot_worker; exit $?; fi
if [ "$command" = boot-step ]; then
    case "${2:-}" in [1-7]) ;; *) exit 2;; esac
    [ "$(cat "$run/boot.pending" 2>/dev/null)" = "${3:-invalid}" ] || exit 2
    lock apply || exit 1
    [ "$(cat "$run/boot.pending" 2>/dev/null)" = "${3:-invalid}" ] || exit 2
    boot_step "$2"
    exit $?
fi
if [ ! -e "$run" ]; then mkdir -m 755 "$run" || exit 1; fi
[ -d "$run" ] && [ ! -L "$run" ] && [ -O "$run" ] || exit 1
if [ ! -e "$run/empty" ]; then mkdir -m 755 "$run/empty" || exit 1; fi
[ -d "$run/empty" ] && [ ! -L "$run/empty" ] && [ -O "$run/empty" ] || exit 1
case "$command" in
    devices)
        requested=$(get edit_devices_request)
        request_id "$requested" || exit 1
        lease=/var/lib/misc/dnsmasq.leases
        [ -r "$lease" ] || lease=/tmp/dnsmasq.leases
        put known_devices "$(known_devices "$lease" /proc/net/arp)" && put devices_request "$requested";;
    measure)
        lock measure || exit 1
        requested=$(get edit_job_request)
        request_id "$requested" || exit 1
        put job_state running
        put job_request "$requested"
        for i in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16; do put "result_$i" ''; done
        measure_job
        case $? in
            0) put job_state done;;
            2) put job_state no_resolvers;;
            3) put job_state no_candidates;;
            4) put job_state stale_candidates;;
            *) put job_state failed; exit 1;;
        esac;;
    *)
        lock apply || exit 1
        case "$command" in
            save)
                payload=$(get edit_save)
                requested=${payload%%|*}
                request_id "$requested" || exit 1
                put state running
                put request "$requested"
                if ! read_config edit_; then put state invalid; exit 1; fi
                if apply_config && mark_requested && save_config; then put state saved; else
                    if stop_runtime && read_config cfg_; then apply_config || apply_failed; fi
                    put state failed; exit 1
                fi;;
            boot) schedule_boot;;
            repair) repair_entry;;
            purge)
                purge_runtime || exit 1
                rm -f "$lockdir/pid" && rmdir "$lockdir" && rmdir "$run" || exit 1
                trap - EXIT;;
            stop) rm -f "$run/requested" "$run/boot.pending"; stop_runtime;;
        esac;;
esac
