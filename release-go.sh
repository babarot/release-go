#!/bin/bash

set -e

prepare() {
    github_token=${GITHUB_TOKEN}
    if [[ -z ${github_token} ]]; then
        read -p "GITHUB_TOKEN (paste here)> " github_token
    fi
    export GITHUB_TOKEN=${github_token}

    for command in git gobump goreleaser
    do
        if ! type "${command}" &>/dev/null; then
            echo "[ERROR] ${command} not found" >&2
            return 1
        fi
    done
}

ask() {
    message="${1:-Are you sure?}"
    while true
    do
        read -r -p "${message} [y/n] " input
        case "${input}" in
            [yY][eE][sS]|[yY])
                return 0
                ;;
            [nN][oO]|[nN])
                echo "[INFO] canceled" >&2
                return 1
                ;;
            *)
                echo "[ERROR] Invalid input...again"
                ;;
        esac
    done
}

main() {
    prepare || return 1

    if [[ -n "$(git status -s)" ]]; then
        echo "[ERROR] there are untracked or unstaged files" >&2
        return 1
    fi

    current_version="$(gobump show -r)"
    echo "[INFO] current version: ${current_version}"

    while true
    do
        read -p "Specify [major | minor | patch]: " version
        case "${version}" in
            major | minor | patch )
                gobump "${version}" -w
                next_version="$(gobump show -r)"
                break
                ;;
            "")
                echo "[INFO] canceled" >&2
                return 1
                ;;
            *)
                echo "[ERROR] ${version}: invalid semver type" >&2
                continue
                ;;
        esac
        shift
    done

    if [[ -d .chglog ]] && type git-chglog &>/dev/null; then
        git-chglog -o CHANGELOG.md --next-tag "v${next_version}"
        git --no-pager diff
    fi

    ask "OK to commit/push these changes?" || return 1
    git commit -am "Bump version ${next_version} and update changelog"
    git tag "v${next_version}"
    git push

    ask "OK to release?" || return 1
    if [[ -f CHANGELOG.md ]]; then
        goreleaser --release-notes CHANGELOG.md --rm-dist
    else
        goreleaser --rm-dist
    fi
}

main "${@}"
exit
