#!/bin/bash

set -e

prepare() {
    if [[ -p /dev/stdin ]]; then
        echo "[ERROR] Use 'bash <(wget ...)' instead of 'wget ... | bash'" >&2
        echo "[ERROR] e.g. 'bash <(curl -sL https://git.io/release-go)'" >&2
        echo "[ERROR] e.g. 'bash <(wget -o /dev/null -qO - https://git.io/release-go)'" >&2
        return 1
    fi

    local tool
    for tool in git gobump goreleaser
    do
        if ! type "${tool}" &>/dev/null; then
            echo "[ERROR] ${tool} not found" >&2
            return 1
        fi
    done

    if [[ ! -d .git ]]; then
        echo "[ERROR] .git: not found in ${PWD}" >&2
        return 1
    fi

    if [[ -n "$(git status -s)" ]]; then
        echo "[ERROR] there are untracked or unstaged files" >&2
        return 1
    fi

    local github_token
    github_token=${GITHUB_TOKEN}
    if [[ -z ${github_token} ]]; then
        read -p "GITHUB_TOKEN (paste here)> " github_token
        export GITHUB_TOKEN=${github_token}
    fi

    if ! gobump show -r ${VERSION_DIR} &>/dev/null; then
      local version_dir
      version_dir=${VERSION_DIR}
      if [[ -z ${version_dir} ]]; then
        read -p "Specify dir where the file that version info is written is located> " version_dir
        export VERSION_DIR=${version_dir}
      fi
    fi
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
                echo "[ERROR] Invalid input...again" >&2
                ;;
        esac
    done
}

main() {
    prepare || return 1

    current_version="$(gobump show -r ${VERSION_DIR})"
    echo "[INFO] current version: ${current_version}"

    while true
    do
        read -p "Specify [major | minor | patch]: " version
        case "${version}" in
            major | minor | patch )
                gobump "${version}" -w ${VERSION_DIR}
                next_version="$(gobump show -r ${VERSION_DIR})"
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
        ask "OK to commit/push these changes?" || return 1
    fi

    git commit -am "Bump version ${next_version} and update changelog"
    git push

    ask "OK to release?" || return 1
    git tag "v${next_version}"
    if [[ -f CHANGELOG.md ]]; then
        goreleaser --rm-dist --release-notes CHANGELOG.md
    else
        goreleaser --rm-dist
    fi
}

main "${@}"
exit
