function codex {
    local promptHeaderJson='"#!/bin/bash\n\n'
    local promptExamplesJson='# update submodules\ngit submodule update --init --recursive\n\n'
    local promptBodyJson='# '"$*"'\n"'
    local promptWithExamplesJson="$promptHeaderJson$promptExamplesJson$promptBodyJson"
    _debug "promptWithExamplesJson=$promptWithExamplesJson"

    local prompt=$(echo "$promptHeaderJson$promptBodyJson" | jq -r)
    _debug "$(echo "prompt:"; echo "$prompt")"

    local maxTokens=64
    local temperatureDecimal=0

    local textsTrimmed=()
    local textFile=$(mktemp)
    _debug "textFile=$textFile"

    while true; do
        local ret=0

        echo "Trying with max_tokens=$maxTokens, temperature=0.$temperatureDecimal" >&2
        local res=$(curl -s https://api.openai.com/v1/engines/code-davinci-002/completions \
                    -H "Content-Type: application/json" \
                    -H "Authorization: Bearer $OPENAI_API_KEY" \
                    -d '{"prompt": '"$promptWithExamplesJson"', "max_tokens": '$maxTokens', "temperature": 0.'$temperatureDecimal', "echo": false, "stop": "\n\n"}')
        ret=$?
        _debug "$(echo "$res" | jq -C)"
        if [ $ret -ne 0 ]; then
            _err $res
            break
        fi

        local textJson=$(echo "$res" | jq -e '.choices[0].text')
        ret=$?
        _debug "textJson=$textJson"
        if [[ "$textJson" != \"*\" ]]; then
            ret=1
        
        elif [ $ret -eq 0 ]; then
            local text=$(echo "$textJson" | jq -r)
            echo >&2
            tput setaf 5
            echo "$text" >&2
            tput sgr0
            echo >&2

            local finishReason=$(echo "$res" | jq -e '.choices[0].finish_reason')
            _debug "finishReason=$finishReason"
            ret=$?
            if [ $ret -eq 0 ]; then
                if [ "$finishReason" != '"stop"' ]; then
                    if [ "$finishReason" == '"length"' ]; then
                        _err "Hit max tokens"
                        maxTokens=$((maxTokens * 2))
                        continue
                    fi

                    _err "Finished for unhandled reason: $finishReason"
                    ret=1
                    break
                fi

                local textTrimmed=$(echo "$text" | grep -oP '^\s*(?!#)([^\s]((?! #).)*)')
                _debug "$(echo "textTrimmed:"; echo "$textTrimmed")"

                local retry=0
                local temperatureUp=0

                if _element-in "$textTrimmed" "${textsTrimmed[@]}"; then
                    _err "Repeated result"
                    retry=1
                    temperatureUp=1

                else
                    textsTrimmed+=("$textTrimmed")

                    if [ -z "$textTrimmed" ]; then
                        _err "Empty result"
                        retry=1

                    else
                        tput bold
                        tput setaf 4
                        echo -n "Execute [(y)es, (e)dit, (r)etry, other to exit]? " >&2
                        tput sgr0
                        read -p ""
                        echo >&2

                        case "$REPLY" in
                            Y|y|E|e)
                                echo "$prompt" > "$textFile"
                                echo "$text" >> "$textFile"
                                ;;
                        esac

                        case "$REPLY" in
                            E|e)
                                $(git config core.editor) "$textFile"
                                ;;
                        esac

                        case "$REPLY" in
                            Y|y|E|e)
                                "$textFile"
                                ret=$?
                                ;;
                            R|r) retry=1;;
                        esac
                    fi
                fi

                if [ $retry -eq 0 ]; then
                    break
                fi

                if [ $temperatureDecimal -eq 0 ]; then
                    temperatureUp=1
                fi
                if [ $temperatureDecimal -lt 7 ]; then
                    temperatureDecimal=$((temperatureDecimal + temperatureUp))
                fi

                continue
            fi
        fi

        if [ $ret -ne 0 ]; then
            _err "Failed to parse response data:"
            echo "$res" | jq -C >&2
            break
        fi
    done

    if (( DEBUG != 1 )); then
        rm "$textFile"
    fi

    return $ret
}
