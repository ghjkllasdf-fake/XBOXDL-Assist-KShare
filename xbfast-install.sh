#!/bin/sh
set -eu
PATH=/koolshare/bin:/sbin:/usr/sbin:/bin:/usr/bin
export PATH
umask 022

src=$(CDPATH= cd "$(dirname "$0")" && pwd)
root=/koolshare/xbfast
[ -n "$(nvram get lan_ipaddr)" ] && [ -n "$(nvram get lan_ifname)" ]
[ -x /usr/sbin/lighttpd ] && [ -r /usr/lib/mod_redirect.so ] && [ -x /koolshare/bin/curl ]
sh -n "$src/xbfast.sh"
sh "$src/xbfast-test.sh" "$src/xbfast.sh"
[ -s "$src/xbfast-icon.png" ] && grep -Fq '<style id="xbfastStyles">' "$src/xbfast-ui.asp" || {
    echo 'Incomplete UI assets; install the built package' >&2
    exit 1
}
[ ! -e "$root" ] && [ ! -L "$root" ] || { echo 'Existing plug-in directory; refusing overwrite'; exit 1; }
set -- "$src/geo/"*.dat.gz
[ "$#" -eq 221 ] && [ -s "$src/geo/LICENSE.ip2region.md" ] && [ -s "$src/geo/NOTICE.txt" ] || {
    echo 'Incomplete offline IP attribution database' >&2
    exit 1
}
for shard do [ -f "$shard" ] && [ -s "$shard" ] && [ ! -L "$shard" ] || exit 1; done
df -Pk /koolshare | awk 'NR==2 {ok=($4>=8192)} END{exit !ok}' || {
    echo 'At least 8 MiB of free space is required for the plug-in and offline IP attribution database' >&2
    exit 1
}
owned_files=
owned_keys=

key_exists() {
    printf '%s\n' "$1" | awk -F= -v key="$2" '$1==key && NF>1 {found=1} END{exit !found}'
}

register() {
    key=${1%%=*}
    entries=$(dbus list "$key") || return 1
    if key_exists "$entries" "$key"; then
        printf 'Existing registration; refusing overwrite: %s\n' "$key" >&2
        return 1
    fi
    owned_keys="$key $owned_keys"
    dbus set "$1" && entries=$(dbus list "$key") && printf '%s\n' "$entries" | grep -Fxq -- "$1"
}

reserve_file() {
    if [ -e "$1" ] || [ -L "$1" ] || ! (set -C; : > "$1"); then
        printf 'Could not reserve installation path: %s\n' "$1" >&2
        return 1
    fi
    owned_files="$1 $owned_files"
}

rollback_install() {
    status=$?
    trap - EXIT
    trap '' HUP INT TERM
    incomplete=0
    for key in $owned_keys; do
        if ! entries=$(dbus list "$key"); then incomplete=1; continue; fi
        if key_exists "$entries" "$key"; then
            if ! dbus remove "$key" || ! entries=$(dbus list "$key") || key_exists "$entries" "$key"; then incomplete=1; fi
        fi
    done
    for file in $owned_files; do rm -f "$file" || incomplete=1; done
    if [ -d "$root/geo" ] && [ ! -L "$root/geo" ]; then
        rm -f "$root/geo/"*.dat.gz "$root/geo/LICENSE.ip2region.md" "$root/geo/NOTICE.txt" || incomplete=1
        rmdir "$root/geo" || incomplete=1
    fi
    rm -f "$root/xbfast.sh" "$root/lighttpd.conf" "$root/lookup.awk" || incomplete=1
    rmdir "$root" || incomplete=1
    if [ "$incomplete" -ne 0 ]; then
        echo 'Installation failed; cleanup incomplete. Check install paths and registration before retrying.' >&2
    fi
    [ "$status" -ne 0 ] || status=1
    exit "$status"
}

mkdir -m 755 "$root"
trap 'rollback_install' EXIT
trap 'exit 1' HUP INT TERM
mkdir "$root/geo"
cp "$@" "$src/geo/LICENSE.ip2region.md" "$src/geo/NOTICE.txt" "$root/geo/"
cp "$src/xbfast.sh" "$root/xbfast.sh"
cp "$src/xbfast-lighttpd.conf" "$root/lighttpd.conf"
cp "$src/xbfast-geo.awk" "$root/lookup.awk"
reserve_file /koolshare/webs/Module_xbfast.asp
cp "$src/xbfast-ui.asp" /koolshare/webs/Module_xbfast.asp
reserve_file /koolshare/res/icon-xbfast.png
cp "$src/xbfast-icon.png" /koolshare/res/icon-xbfast.png

reserve_file /koolshare/scripts/xbfast_config.sh
cat > /koolshare/scripts/xbfast_config.sh <<'XBEOF'
#!/bin/sh
exec sh /koolshare/xbfast/xbfast.sh save
XBEOF
reserve_file /koolshare/scripts/xbfast_measure.sh
cat > /koolshare/scripts/xbfast_measure.sh <<'XBEOF'
#!/bin/sh
exec sh /koolshare/xbfast/xbfast.sh measure
XBEOF
reserve_file /koolshare/scripts/xbfast_devices.sh
cat > /koolshare/scripts/xbfast_devices.sh <<'XBEOF'
#!/bin/sh
exec sh /koolshare/xbfast/xbfast.sh devices
XBEOF
reserve_file /koolshare/scripts/xbfast_repair.sh
cat > /koolshare/scripts/xbfast_repair.sh <<'XBEOF'
#!/bin/sh
exec sh /koolshare/xbfast/xbfast.sh repair
XBEOF
reserve_file /koolshare/init.d/S97xbfast.sh
cat > /koolshare/init.d/S97xbfast.sh <<'XBEOF'
#!/bin/sh
case "$1" in
    start|restart)
        sh /koolshare/xbfast/xbfast.sh boot;;
    stop|kill)
        cru d XBFAST
        sh /koolshare/xbfast/xbfast.sh stop;;
esac
XBEOF
reserve_file /koolshare/scripts/xbfast_uninstall.sh
cat > /koolshare/scripts/xbfast_uninstall.sh <<'XBEOF'
#!/bin/sh
sh /koolshare/xbfast/xbfast.sh purge || exit 1
rm -f /koolshare/xbfast/xbfast.sh /koolshare/xbfast/lighttpd.conf /koolshare/xbfast/lookup.awk /koolshare/xbfast/geo-current /koolshare/webs/Module_xbfast.asp /koolshare/res/icon-xbfast.png /koolshare/res/xbfast-ui.css
rm -f /koolshare/scripts/xbfast_config.sh /koolshare/scripts/xbfast_measure.sh /koolshare/scripts/xbfast_devices.sh /koolshare/scripts/xbfast_repair.sh /koolshare/init.d/S97xbfast.sh
for directory in /koolshare/xbfast/geo /koolshare/xbfast/geo-a /koolshare/xbfast/geo-b; do
    if [ -d "$directory" ] && [ ! -L "$directory" ]; then
        rm -f "$directory"/*.dat.gz "$directory/lookup.awk" "$directory/NOTICE.txt" "$directory/LICENSE.ip2region.md"
        rmdir "$directory"
    fi
done
rmdir /koolshare/xbfast
for key in name title description home_url version install; do dbus remove "softcenter_module_xbfast_$key"; done
dbus list xbfast_ | cut -d= -f1 | while IFS= read -r key; do
    case "$key" in xbfast_[A-Za-z0-9_]*) dbus remove "$key";; esac
done
rm -f /koolshare/scripts/xbfast_uninstall.sh
XBEOF
chmod 755 "$root/xbfast.sh" /koolshare/scripts/xbfast_config.sh /koolshare/scripts/xbfast_measure.sh /koolshare/scripts/xbfast_devices.sh /koolshare/scripts/xbfast_repair.sh /koolshare/scripts/xbfast_uninstall.sh /koolshare/init.d/S97xbfast.sh
register softcenter_module_xbfast_name=xbfast
register softcenter_module_xbfast_version=0.0.1
register 'softcenter_module_xbfast_title=下载助手'
register 'softcenter_module_xbfast_description=为指定设备加速 Xbox 与 Windows 商店下载'
register softcenter_module_xbfast_home_url=Module_xbfast.asp
register xbfast_enable=0
register xbfast_cfg_enabled=0
register xbfast_cfg_xbox=1
register xbfast_cfg_store=0
register xbfast_cfg_devices=
register xbfast_cfg_all_devices=0
register xbfast_cfg_autostart=0
register xbfast_runtime=stopped
register __event__onnatstart_xbfast=/koolshare/scripts/xbfast_repair.sh
register softcenter_module_xbfast_install=1
trap - EXIT HUP INT TERM
echo 'xbfast 0.0.1 registered (disabled)'
