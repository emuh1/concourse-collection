#!/bin/bash

Exit_error()
{
    echo "ERROR: $*" 1>&2
    exit 1
}

Echo_error()
{
    echo "ERROR: $*" 1>&2
}

Svn_getReopitoryRoot()
{
    local _URI="$1"

    [[ -z "${_URI}" ]] && Exit_error "no uri given"

    LC_ALL=C svn info "${_URI}" | grep "Repository Root" | cut -d ":" -f 2- | cut -d " " -f 2-
}

Misc_MergePath()
{
    local _BASE="$1"
    local _END="$2"

    if [[ "${_END:0:2}" == '..' ]]
    then
        Misc_MergePath "${_BASE%/*}" "${_END:3}"
    else
        echo "${_BASE}/${_END}"
    fi
}

Misc_normalizeName()
{
    local _RAW_NAME="$1"
    if [[ "${_RAW_NAME%/externals/source}" != "${_RAW_NAME}" ]]; then
        local _RAW_NAME="${_RAW_NAME%/externals/source}"
    fi
    echo "${_RAW_NAME##*/}"
}

Svn_getNormalizedExternalDef()
{
    local _URI="$1"

    [[ -z "${_URI}" ]] && Exit_error "no uri given"

    local _BASE_URI="$(Svn_getReopitoryRoot "${_URI}")"
    [[ -z "${_BASE_URI}" ]] && Exit_error "base uri could not be evaluated"
    
    local _EXTERNALS_LIST=''

    while read -r _LINE
    do
        if [[ "${_LINE##Properties on \'*\'}" == ':' ]];then
            local _EXT_BASE_PATH="${_LINE#*${_URI}}"
            local _EXT_BASE_PATH="${_EXT_BASE_PATH%%\'*}"
            [[ "${_EXT_BASE_PATH:0:1}" == '/' ]] && _EXT_BASE_PATH="${_EXT_BASE_PATH:1}"
            [[ -n "${_EXT_BASE_PATH}" ]] && _EXT_BASE_PATH="${_EXT_BASE_PATH}/"
            continue
        elif [[ "${_LINE}" == 'svn:externals' ]]; then
            continue
        else
            if [[ "${_LINE:0:1}" == '#' ]]; then
                continue
            elif [[ -z "${_LINE}" ]]; then
                continue
            else
                local _EXT_DEF_PART1="${_LINE%% *}"
                local _EXT_DEF_PART2="${_LINE##* }"
                if [[ "${_EXT_DEF_PART1:0:1}" == '^' ]]
                then
                    local _EXT_URI="$(Misc_MergePath "${_BASE_URI}" "${_EXT_DEF_PART1:2}")"
                    local _EXT_NAME="${_EXT_BASE_PATH}${_EXT_DEF_PART2}"
                else
                    if [[ -e "${_EXT_BASE_PATH}/${_EXT_DEF_PART1}" ]]
                    then
                        local _EXT_NAME="${_EXT_BASE_PATH}${_EXT_DEF_PART1}"
                        local _EXT_URI="${_EXT_DEF_PART2}"
                    else
                        local _EXT_NAME="${_EXT_BASE_PATH}${_EXT_DEF_PART2}"
                        local _EXT_URI="${_EXT_DEF_PART1}"
                    fi
                fi
                local _EXT_NAME="$(Misc_normalizeName "${_EXT_NAME}")"
                local _EXT_DEF="${_EXT_NAME},${_EXT_URI}"
            fi
        fi
        _EXTERNALS_LIST="${_EXTERNALS_LIST} ${_EXT_DEF}"
    done < <(LC_ALL=C svn propget -R -v svn:externals "${_URI}")

    echo "${_EXTERNALS_LIST}" 
}
