#!/bin/sh

# DSM Config
__USERNAME__="$(echo "$@" | cut -d' ' -f1)"
__PASSWORD__="$(echo "$@" | cut -d' ' -f2)"
__HOSTNAME__="$(echo "$@" | cut -d' ' -f3)"

# ddnsd will give us both IPv4 and IPv6 addresses
eval "$(ddnsd -a | sed 's/: /=/')"

# log location
__LOGFILE__="/var/log/cloudflareddns.log"


# CloudFlare Config
__IP4RECTYPE__="A"
__IP4RECID__=""
__IP6RECTYPE__="AAAA"
__IP6RECID__=""
__ZONE_ID__=""
__TTL__="1"
__PROXY__="true"

log() {
    __LOGTIME__=$(date +"%b %e %T")
    if [ "$#" -lt 1 ]; then
        false
    else
        __LOGMSG__="$1"
    fi
    if [ "$#" -lt 2 ]; then
        __LOGPRIO__=7
    else
        __LOGPRIO__="$2"
    fi

    logger -p "$__LOGPRIO__" -t "$(basename "$0")" "$__LOGMSG__"
    echo "${__LOGTIME__} $(basename "$0") (${__LOGPRIO__}): ${__LOGMSG__}" >> "$__LOGFILE__"
}

update() {
    __URL__="$1"
    __RECTYPE__="$2"
    __MYIP__="$3"

    log "Updating with $__MYIP__..."
    __RESPONSE__=$(curl -s -X PUT "$__URL__" \
        -H "X-Auth-Email: ${__USERNAME__}" \
        -H "X-Auth-Key: ${__PASSWORD__}" \
        -H "Content-Type: application/json" \
        --data "{\"type\":\"${__RECTYPE__}\",\"name\":\"${__HOSTNAME__}\",\"content\":\"${__MYIP__}\",\"ttl\":${__TTL__},\"proxied\":${__PROXY__}}")

    # Strip the result element from response json
    __RESULT__=$(echo "$__RESPONSE__" | grep -Po '"success":\K.*?[^\\],')
    echo "$__RESPONSE__"
    case $__RESULT__ in
        'true,')
            __STATUS__='good'
            ;;
        *)
            __STATUS__="$__RESULT__"
            log "__RESPONSE__=${__RESPONSE__}"
            ;;
    esac
}

__URL__="https://api.cloudflare.com/client/v4/zones/${__ZONE_ID__}/dns_records/${__IP4RECID__}"

update \
    "https://api.cloudflare.com/client/v4/zones/${__ZONE_ID__}/dns_records/${__IP4RECID__}" \
    "$__IP4RECTYPE__" "${IPv4:?}"

if [ "$__STATUS__" = 'good' ] && [ "${IPv6:?}" != '0:0:0:0:0:0:0:0' ]; then
    update \
        "https://api.cloudflare.com/client/v4/zones/${__ZONE_ID__}/dns_records/${__IP6RECID__}" \
        "$__IP6RECTYPE__" "${IPv6:?}"
fi

log "Status: ${__STATUS__}"

printf "%s" "$__STATUS__"
