#!/bin/sh
ORIGINAL_PATH=$PATH
. "${1:-./xbfast.sh}"
set -eu
PATH=$ORIGINAL_PATH
run=$(mktemp -d)
trap 'rmdir "$run" 2>/dev/null || true' EXIT
router=192.168.1.1
netmask=255.255.255.0
bridge=br5

get() {
    case "$1" in
        cfg_enabled) printf '%s\n' "$test_enabled";;
        cfg_autostart) printf '%s\n' "$test_auto";;
        cfg_devices) printf '192.168.1.10\n';;
        cfg_xbox) printf '1\n';;
        cfg_store) printf '0\n';;
        runtime) printf 'stopped\n';;
    esac
}
put() { :; }
alive() { return 1; }
(
apply_config() { printf '%s\n' applied; }
test_enabled=0; test_auto=1
[ -z "$(repair)" ]
test_enabled=1; test_auto=0
[ -z "$(repair)" ]
test_auto=1
[ "$(repair)" = applied ]
test_auto=0
[ "$(repair)" = applied ]
)
rm -f "$run/requested"
payload='12345|1|0|1|0|192.168.1.10||58.216.30.197|||end'
read_config edit_
[ "$requested:$enabled:$autostart:$devices:$legacy" = '12345:1:0:192.168.1.10:58.216.30.197' ]
payload='12345|1|0|1|0|192.168.1.10||58.216.30.197|||extra|end'
! read_config edit_ || exit 1

iptables() { printf '%s\n' "$*"; }
ipset() { :; }
devices=192.168.1.10; xbox=1; store=0; main=; legacy=
rules=$(build_rules)
printf '%s\n' "$rules" | grep -Fxq -- '-t nat -A XBFAST_NAT -m set ! --match-set xbfast_devices src -j RETURN'
printf '%s\n' "$rules" | grep -Fxq -- '-t nat -A XBFAST_NAT -p udp --dport 53 -j REDIRECT --to-ports 15354'
printf '%s\n' "$rules" | grep -Fxq -- '-t nat -A XBFAST_NAT -p tcp --dport 53 -j REDIRECT --to-ports 15354'
printf '%s\n' "$rules" | grep -Fxq -- '-t nat -A XBFAST_NAT -d 192.0.2.253 -p tcp --dport 80 -j REDIRECT --to-ports 18081'

# The old payload remains valid; the new mode also preserves a manual list.
payload='12346|1|0|1|0|192.168.1.10|||||1|end'
read_config edit_
[ "$all_devices:$devices" = '1:192.168.1.10' ]
payload='12346|1|0|1|0||||||1|end'
read_config edit_
[ "$all_devices:$devices" = '1:' ]
payload='12346|1|0|1|0||||||2|end'
! read_config edit_ || exit 1
all_devices=1; devices=; xbox=1; store=0; main=; legacy=
rules=$(build_rules)
printf '%s\n' "$rules" | grep -Fxq -- '-A XBFAST_IN -i br5 -s 192.168.1.1/255.255.255.0 -j RETURN'
printf '%s\n' "$rules" | grep -Fxq -- '-t nat -A XBFAST_NAT ! -s 192.168.1.1/255.255.255.0 -j RETURN'
! printf '%s\n' "$rules" | grep -q -- '--match-set xbfast_devices src' || exit 1

cat > "$run/leases" <<'EOF'
2000000000 aa:bb:cc:dd:ee:ff 192.168.1.10 xbox *
2000000000 aa:bb:cc:dd:ee:00 192.168.1.11 <script> *
2000000000 aa:bb:cc:dd:ee:01 192.168.2.12 elsewhere *
EOF
cat > "$run/arp" <<'EOF'
IP address       HW type     Flags       HW address            Mask     Device
192.168.1.10     0x1         0x2         aa:bb:cc:dd:ee:ff     *        br5
192.168.1.12     0x1         0x2         aa:bb:cc:dd:ee:02     *        br5
192.168.1.13     0x1         0x2         aa:bb:cc:dd:ee:03     *        br0
EOF
clients=$(known_devices "$run/leases" "$run/arp")
[ "$clients" = '192.168.1.10|xbox;192.168.1.11|;192.168.1.12|' ]
rm -f "$run/leases" "$run/arp"
printf 'Runtime: boot, payload, rule-builder and device-discovery checks passed\n'

fixture=$run/firewall
mkdir "$fixture"
trap 'rm -rf "$fixture"; rm -f "$run/runtime" "$cron_spool/fixture"; rmdir "$cron_spool" "$run" 2>/dev/null || true' EXIT
put() { [ "$1" != runtime ] || printf '%s\n' "$2" > "$run/runtime"; }
lock() { :; }
cron_spool=$run/crontabs
nvram() { [ "$*" = 'get http_username' ] && printf '%s\n' fixture; }
cat() {
    if [ "$*" != "$cron_spool/fixture" ]; then command cat "$@"; return; fi
    [ "$fault" != cron-list ] || return 4
    if [ -f "$fixture/cron-listed" ] && [ "$fault" = cron-recheck ]; then return 4; fi
    touch "$fixture/cron-listed"
    command cat "$@" || return 1
    if [ -f "$fixture/cron" ]; then printf '%s\n' '*/1 * * * * /koolshare/scripts/xbfast_repair.sh #XBFAST#'; fi
}
cru() {
    case "$*" in
        'd XBFAST') remove_object cron-delete cron;;
        *) return 99;;
    esac
}
dbus() {
    case "$*" in
        'list __event__onnatstart_xbfast')
            [ "$fault" != event-list ] || return 4
            if [ -f "$fixture/event-listed" ] && [ "$fault" = event-recheck ]; then return 4; fi
            touch "$fixture/event-listed"
            printf '%s\n' '__event__onnatstart_xbfast_other=/other/repair.sh'
            if [ -f "$fixture/event" ]; then printf '%s\n' '__event__onnatstart_xbfast='; fi;;
        'remove __event__onnatstart_xbfast') remove_object event-delete event;;
        *) return 99;;
    esac
}

remove_object() {
    [ "$fault" != "$1" ] || return 4
    [ -f "$fixture/$2" ] || return 1
    [ "$fault" = "stale-$1" ] || rm "$fixture/$2"
}

iptables() {
    case "$*" in
        '-t nat -S PREROUTING'|'-t nat -S')
            [ "$fault" != nat-list ] || return 4
            printf '%s\n' '-P PREROUTING ACCEPT' '-A PREROUTING -i br0 -j PROXY'
            if [ -f "$fixture/nat" ]; then printf '%s\n' '-N XBFAST_NAT'; fi
            if [ -f "$fixture/nat-hook" ]; then printf '%s\n' '-A PREROUTING -i br5 -j XBFAST_NAT'; fi;;
        '-S INPUT'|'-t filter -S')
            [ "$fault" != filter-list ] || return 4
            printf '%s\n' '-P INPUT ACCEPT' '-A INPUT -j PROXY'
            if [ -f "$fixture/filter" ]; then printf '%s\n' '-N XBFAST_IN'; fi
            if [ -f "$fixture/input-hook" ]; then printf '%s\n' '-A INPUT -j XBFAST_IN'; fi;;
        '-t nat -D PREROUTING -i br5 -j XBFAST_NAT') remove_object nat-hook nat-hook;;
        '-D INPUT -j XBFAST_IN') remove_object input-hook input-hook;;
        '-t nat -F XBFAST_NAT') [ "$fault" != nat-flush ] && [ -f "$fixture/nat" ];;
        '-t filter -F XBFAST_IN') [ "$fault" != filter-flush ] && [ -f "$fixture/filter" ];;
        '-t nat -X XBFAST_NAT') [ ! -f "$fixture/nat-hook" ] && remove_object nat-delete nat;;
        '-t filter -X XBFAST_IN') [ ! -f "$fixture/input-hook" ] && remove_object filter-delete filter;;
        *) printf 'Unexpected iptables command: %s\n' "$*" >&2; return 99;;
    esac
}

ipset() {
    case "$*" in
        'list -n')
            [ "$fault" != set-list ] || return 4
            printf '%s\n' proxy_set
            for name in "$dev_set" "$cdn_set"; do
                if [ -f "$fixture/$name" ]; then printf '%s\n' "$name"; fi
            done;;
        "destroy $dev_set"|"destroy $cdn_set") remove_object "delete-$2" "$2";;
        *) printf 'Unexpected ipset command: %s\n' "$*" >&2; return 99;;
    esac
}

cleanup_checks=0
seed_firewall() {
    touch "$fixture/nat" "$fixture/filter" "$fixture/nat-hook" "$fixture/input-hook" "$fixture/$dev_set" "$fixture/$cdn_set"
    put runtime running
}
for fault in input-hook nat-hook filter-list nat-list filter-flush nat-flush filter-delete nat-delete stale-filter-delete set-list "delete-$dev_set" "delete-$cdn_set" "stale-delete-$cdn_set"; do
    seed_firewall
    if stop_runtime; then printf 'FAIL stop reported success for %s (runtime=%s)\n' "$fault" "$(cat "$run/runtime")" >&2; exit 1; fi
    [ "$(cat "$run/runtime")" = cleanup_error ]
    cleanup_checks=$((cleanup_checks+1))
done

seed_firewall
fault=input-hook
mkdir "$cron_spool"
mkdir "$run/empty"
touch "$run/dns.conf" "$run/requested"
if purge_runtime; then printf 'FAIL purge reported success after INPUT deletion failed\n' >&2; exit 1; fi
[ "$(cat "$run/runtime")" = cleanup_error ] && [ -f "$run/dns.conf" ] && [ -f "$run/requested" ] || exit 1
cleanup_checks=$((cleanup_checks+1))
fault=
purge_runtime || exit 1
rm -f "$fixture/cron-listed" "$fixture/event-listed"
[ ! -e "$run/dns.conf" ] && [ ! -e "$run/requested" ] && [ ! -e "$run/empty" ] && [ -z "$(ls -A "$fixture")" ] || exit 1
cleanup_checks=$((cleanup_checks+1))
stop_runtime
[ "$(cat "$run/runtime")" = stopped ]
cleanup_checks=$((cleanup_checks+1))

seed_firewall
fault=input-hook
if apply_failed; then exit 1; fi
[ "$(cat "$run/runtime")" = cleanup_error ]
cleanup_checks=$((cleanup_checks+1))
fault=
if apply_failed; then exit 1; fi
[ "$(cat "$run/runtime")" = error ] && [ -z "$(ls -A "$fixture")" ] || exit 1
cleanup_checks=$((cleanup_checks+1))
printf 'Runtime cleanup: %s scenarios passed\n' "$cleanup_checks"

scheduler_checks=0
printf '%s\n' '* * * * * /proxy/repair.sh #PROXY#' '* * * * * /other/repair.sh #OTHER_XBFAST#' > "$cron_spool/fixture"
for fault in cron-list cron-delete stale-cron-delete cron-recheck event-list event-delete stale-event-delete event-recheck; do
    rm -f "$fixture/cron-listed" "$fixture/event-listed"
    touch "$fixture/cron" "$fixture/event" "$run/dns.conf" "$run/requested"
    mkdir "$run/empty"
    if purge_runtime; then printf 'FAIL purge reported success for %s\n' "$fault" >&2; exit 1; fi
    [ -f "$run/dns.conf" ] && [ -f "$run/requested" ] && [ -d "$run/empty" ] || exit 1
    scheduler_checks=$((scheduler_checks+1))
    fault=
    purge_runtime || exit 1
    [ ! -e "$fixture/cron" ] && [ ! -e "$fixture/event" ] && [ ! -e "$run/dns.conf" ] && [ ! -e "$run/empty" ] || exit 1
    scheduler_checks=$((scheduler_checks+1))
done
mkdir "$run/empty"
purge_runtime || exit 1
[ ! -e "$run/empty" ]
scheduler_checks=$((scheduler_checks+1))
rm "$cron_spool/fixture"
mkdir "$run/empty"
purge_runtime || exit 1
[ ! -e "$run/empty" ]
scheduler_checks=$((scheduler_checks+1))
rmdir "$cron_spool"
mkdir "$run/empty"
if purge_runtime; then exit 1; fi
[ -d "$run/empty" ]
rmdir "$run/empty"
scheduler_checks=$((scheduler_checks+1))
printf 'Scheduler cleanup: %s scenarios passed\n' "$scheduler_checks"

(
    iptables_matches=$fixture/iptables-matches
    firmware_modprobe=$fixture/modprobe
    export XBFAST_MATCH_FIXTURE=$fixture
    cat > "$firmware_modprobe" <<'EOF'
#!/bin/sh
[ "$*" = xt_set ] || exit 99
printf 'load\n' >> "$XBFAST_MATCH_FIXTURE/load-attempts"
case "$(cat "$XBFAST_MATCH_FIXTURE/load-mode")" in
    fail) exit 4;;
    ready) printf 'set\n' >> "$XBFAST_MATCH_FIXTURE/iptables-matches";;
esac
EOF
    chmod +x "$firmware_modprobe"
    write_configs() { printf 'configured\n' >> "$fixture/configured"; return 1; }
    build_rules() { printf 'rules\n' >> "$fixture/rules"; return 1; }
    enabled=1
    printf 'iprange\n' > "$iptables_matches"
    printf 'fail\n' > "$fixture/load-mode"
    if apply_config; then exit 1; fi
    [ "$apply_stage" = kernel-set ] && [ ! -e "$fixture/configured" ] && [ ! -e "$fixture/rules" ] || exit 1
    [ "$(wc -l < "$fixture/load-attempts")" -eq 1 ]
    printf 'noop\n' > "$fixture/load-mode"
    if apply_config; then exit 1; fi
    [ "$apply_stage" = kernel-set ] && [ ! -e "$fixture/configured" ] && [ ! -e "$fixture/rules" ] || exit 1
    [ "$(wc -l < "$fixture/load-attempts")" -eq 2 ]
    printf 'ready\n' > "$fixture/load-mode"
    if apply_config; then exit 1; fi
    [ "$apply_stage" = config-check ] && [ -f "$fixture/configured" ] || exit 1
    [ "$(wc -l < "$fixture/load-attempts")" -eq 3 ]
    rm "$fixture/configured" "$firmware_modprobe"
    if apply_config; then exit 1; fi
    [ "$apply_stage" = config-check ] && [ -f "$fixture/configured" ] || exit 1
    rm "$fixture/configured" "$iptables_matches"
    if apply_config; then exit 1; fi
    [ "$apply_stage" = kernel-set ] && [ ! -e "$fixture/configured" ] && [ ! -e "$fixture/rules" ] || exit 1
    enabled=0
    apply_config
    [ "$(wc -l < "$fixture/load-attempts")" -eq 3 ]
)
printf 'Kernel set match: load failure, false success, recovery, already loaded, missing loader and disabled passed\n'

get() {
    case "$1" in
        cfg_enabled) printf '%s\n' "$boot_enabled";;
        cfg_autostart) printf '%s\n' "$boot_auto";;
        runtime) printf 'stopped\n';;
    esac
}
boot_lan_ready() { [ ! -f "$fixture/lan-late" ]; }
boot_settled() { [ ! -f "$fixture/boot-early" ]; }
repair() {
    apply_stage=dns
    [ ! -f "$fixture/dns-late" ] || return 1
    printf 'repair\n' >> "$run/boot-trace"
}
ensure_watchdog() {
    printf 'watchdog\n' >> "$run/boot-trace"
    [ ! -f "$fixture/cron-late" ]
}
assert_boot_step() {
    expected=$1; shift
    if boot_step "$@"; then result=0; else result=$?; fi
    [ "$result" = "$expected" ] || { printf 'FAIL boot_step %s: exit %s, expected %s\n' "$*" "$result" "$expected" >&2; exit 1; }
}
boot_enabled=1; boot_auto=1
printf '%s\n' "$$" > "$run/boot.pending"
touch "$fixture/lan-late"
assert_boot_step 1 1
[ ! -e "$run/boot-trace" ]
grep -Fxq 'attempt=1 service=lan watchdog=waiting' "$run/boot.log"
rm "$fixture/lan-late"
touch "$fixture/dns-late" "$fixture/cron-late"
assert_boot_step 1 2
grep -Fxq 'attempt=2 service=dns watchdog=unverified' "$run/boot.log"
rm "$fixture/dns-late"
assert_boot_step 1 3
grep -Fxq 'attempt=3 service=ready watchdog=unverified' "$run/boot.log"
rm "$fixture/cron-late"
touch "$fixture/boot-early"
assert_boot_step 1 4
grep -Fxq 'attempt=4 service=ready watchdog=ready' "$run/boot.log"
[ -f "$run/boot.pending" ]
touch "$fixture/cron-late"
assert_boot_step 1 5
grep -Fxq 'attempt=5 service=ready watchdog=unverified' "$run/boot.log"
rm "$fixture/cron-late" "$fixture/boot-early"
assert_boot_step 0 6
[ ! -e "$run/boot.pending" ]
assert_boot_step 2 7
[ "$(wc -l < "$run/boot.log")" -eq 6 ]

for settings in '0 1' '1 0'; do
    set -- $settings
    boot_enabled=$1; boot_auto=$2
    printf '%s\n' "$$" > "$run/boot.pending"
    assert_boot_step 2 1
    [ ! -e "$run/boot.pending" ]
done
[ "$(wc -l < "$run/boot.log")" -eq 6 ]
boot_enabled=1; boot_auto=1
printf '%s\n' "$$" > "$run/boot.pending"
touch "$fixture/cron-late"
assert_boot_step 1 7
[ ! -e "$run/boot.pending" ]
rm -f "$run/boot.log" "$run/boot-trace"
printf 'Boot retry: readiness, service and watchdog failure, recovery, cancellation and limit passed\n'

(
    requested=12345
    operation_input=discover
    profile_input=main
    resolvers_input=
    discovery_input=12345
    candidate_input=8.8.8.8
    clock_input=1000
    get() {
        case "$1" in
            edit_job) printf '%s\n' "$operation_input";;
            edit_profile) printf '%s\n' "$profile_input";;
            edit_discovery) printf '%s\n' "$discovery_input";;
            edit_candidates) printf '%s\n' "$candidate_input";;
        esac
    }
    put() { printf '%s\n' "$2" > "$fixture/job-$1"; }
    isp_servers() { printf '%s' "$resolvers_input"; }
    discovery_time() { printf '%s\n' "$clock_input"; }
    locations_for() { :; }
    nslookup() {
        printf '%s\n' "$2" >> "$fixture/resolver-used"
        printf '%s\n' 'Server: resolver' 'Address: 4.4.4.4'
        if [ "$2" = 9.9.9.9 ]; then
            printf '%s\n' 'Name: sample' 'Address: 8.8.8.8' 'Address 2: 1.1.1.1' 'Address 3: 192.168.10.10'
        fi
    }
    score() { printf '%s\n' "$1" >> "$fixture/scored"; printf '1 Mbps\n'; }
    check_job() {
        if measure_job; then result=0; else result=$?; fi
        [ "$result" = "$1" ]
    }
    check_job 2
    [ ! -e "$fixture/resolver-used" ] && [ ! -e "$run/discovery" ] || exit 1
    resolvers_input=4.4.4.4; check_job 3
    [ ! -e "$run/discovery" ]
    resolvers_input=9.9.9.9; check_job 0
    [ "$(cat "$fixture/job-candidates")" = '8.8.8.8 1.1.1.1' ]
    operation_input=test
    candidate_input='8.8.8.8 4.4.4.4'; check_job 4
    [ ! -e "$fixture/scored" ]
    candidate_input=8.8.8.8; profile_input=legacy; check_job 4
    profile_input=main; discovery_input=99999; check_job 4
    discovery_input=12345; clock_input=1300; check_job 4
    [ ! -e "$fixture/scored" ]
    clock_input=1299; check_job 0
    [ "$(cat "$fixture/scored")" = '8.8.8.8' ]
    operation_input=discover; resolvers_input=; check_job 2
    operation_input=test; check_job 4
    [ ! -e "$run/discovery" ]
)
printf 'ISP discovery: no fallback, both DNS formats, candidate binding, expiry and invalidation passed\n'
