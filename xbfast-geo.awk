function low_number(ip, parts) {
    split(ip, parts, ".")
    return parts[2] * 65536 + parts[3] * 256 + parts[4]
}

BEGIN {
    count = split(queries, words, " ")
    for (position = 1; position <= count; position++) {
        split(words[position], octets, ".")
        if (octets[1] == prefix) wanted[words[position]] = low_number(words[position])
    }
    remaining = 0
    for (ip in wanted) remaining++
}

{
    first = $1 + 0
    last = $2 + 0
    label = $0
    sub(/^[0-9]+ [0-9]+ /, "", label)
    for (ip in wanted) {
        if (wanted[ip] >= first && wanted[ip] <= last) {
            matches[ip] = label
            delete wanted[ip]
            remaining--
        }
    }
    if (!remaining) exit
}

END {
    for (position = 1; position <= count; position++) {
        ip = words[position]
        if (ip in matches) printf "%s|%s;", ip, matches[ip]
    }
}
