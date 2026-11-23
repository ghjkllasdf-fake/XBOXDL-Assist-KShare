#!/bin/sh
set -eu

actual=$(awk -v prefix=58 -v 'queries=58.216.30.197 58.216.30.200 58.216.31.0 58.216.31.1 58.216.32.0 59.216.30.197' -f "${1:-work/xbfast-geo.awk}" <<'EOF'
14163648 14163655 常州电信
14163656 14163711 无锡电信
14163712 14163712 苏州移动
EOF
)
expected='58.216.30.197|常州电信;58.216.30.200|无锡电信;58.216.31.0|苏州移动;'
[ "$actual" = "$expected" ] || { printf 'Expected: %s\nActual:   %s\n' "$expected" "$actual"; exit 1; }
echo 'Geo lookup: 6 coverage, boundary and miss cases passed'

if [ "$#" -ge 2 ]; then
    lookup=$(CDPATH= cd "$(dirname "$1")" && pwd)/$(basename "$1")
    core=$2
    work=$(mktemp -d)
    trap 'rm -rf "$work"' EXIT
    sed -n '/^locations_for()/,/^known_devices()/p' "$core" | sed '$d' > "$work/functions"
    . "$work/functions"
    root=$work
    cp "$lookup" "$root/lookup.awk"
    [ -z "$(locations_for '58.216.30.197')" ]
    for slot in geo geo-a geo-b; do
        mkdir "$root/$slot"
        [ "$slot" = geo ] || printf '%s\n' "$slot" > "$root/geo-current"
        printf '14163648 14163655 %s\n' "$slot" | gzip -c > "$root/$slot/58.dat.gz"
        [ "$(locations_for '58.216.30.197')" = "58.216.30.197|$slot;" ]
    done
    echo 'Local geo integration: no library, legacy directory and both tracked slots passed'
fi
