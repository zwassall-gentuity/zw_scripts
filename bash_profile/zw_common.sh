_indent=""

function _debug {
    local ret=$?

    if (( DEBUG == 1 )); then
        echo "[D] $_indent$@" >&2
    fi

    return $ret
}

function _enter {
    local ret=$?

    _debug "{ $*"
    _indent="$_indent  "

    return $ret
}

function _return {
    local ret=$?
    if [ $# -ge 1 ]; then
        ret=$1
    fi

    _indent="${_indent::${#_indent}-2}"
    _debug "} $ret"

    return $ret
}

function _time {
    _enter "_time $*"

    local -n _time_result=$1

    local timeCmd=
    if (( DEBUG == 1 )); then
        _time_result=$(time "${@:2}")
    else
        _time_result=$("${@:2}")
    fi

    _return
}


function _err {
    tput bold
    tput setaf 1
    echo "$@" >&2
    tput sgr0
}


# Modified from https://stackoverflow.com/a/8574392/3447746
function _element-in {
    local e match="$1"
    shift
    for e; do [ "$e" = "$match" ] && return 0; done
    return 1
}


function _max-ret {
    _enter "_max-ret $*"

    local retMax=-128

    while [ $# -ge 1 ]; do
        local ret=$1
        shift

        if [ $ret -ge 128 ]; then
            ret=$(($ret - 256))
        fi

        if [ $retMax -lt $ret ]; then
            retMax=$ret
        fi
    done

    _return $retMax
}
