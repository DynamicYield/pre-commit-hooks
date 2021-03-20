#!/bin/bash
set -e

while test $# -gt 0; do
    case "$1" in
        -h|--help)
            echo " "
            echo "options:"
            echo "-h, --help            show brief help"
            echo "--version-file        set the name of the version file to bump"
            echo "--remote-branch       set the name of the remote branch to diff against"
            exit 0
            ;;
        --version-file)
            shift
            if test $# -gt 0; then
                export version_file=$1
            fi
            shift
            ;;
        --remote-branch)
            shift
            if test $# -gt 0; then
                export remote_branch=$1
            fi
            shift
            ;;
            *)
            break
            ;;
    esac
done

if [[ -z "$version_file" ]]; then
    echo "version-file flag must be set" 1>&2
    exit 1
fi

if [[ -z "$remote_branch" ]]; then
    echo "remote-branch flag must be set" 1>&2
    exit 1
fi

semver_regex="(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$"

bumped_version="false"

# https://stackoverflow.com/a/8574392
# Usage: contains_element "val" "${array[@]}"
# Returns: 0 if there is a match, 1 otherwise
contains_element() {
  local -r match="$1"
  shift

  for e in "$@"; do
    if [[ "$e" == "$match" ]]; then
      return 0
    fi
  done
  return 1
}

# checks up the directory tree for a version file match
check_dirs () {
    local dir="$1"
    while [ "$dir" != "." ]; do
        dir=$(dirname "$dir")
        if [[ -f "$dir/$version_file" ]]; then
            echo "$dir"
            return 0
        fi
    done
}

processed_dirs=()

for file in "$@"; do

    # check if file was modified since remote head commit to prevent false-positive bumping during pre-commit run all-files
    if ! git diff --exit-code --quiet $remote_branch "$file"; then

        version_dir=$(check_dirs "$file")

        # check if dir was already processed
        if ! contains_element "$version_dir" "${processed_dirs[@]}"; then

            if [[ -f "$version_dir/$version_file" ]]; then
                # check if version file was modified since remote head commit
                if git diff --exit-code --quiet $remote_branch "$version_dir/$version_file"; then
                    bump2version --allow-dirty --current-version "$(grep -Eo "$semver_regex" "$version_dir/$version_file")" patch "$version_dir/$version_file"
                    bumped_version="true"
                    # add bumped version file to the staged changes to make sure it's commited
                    git add "$version_dir/$version_file"
                    echo "bumped $version_dir/$version_file"
                fi
            fi
        fi
        processed_dirs+=( "$version_dir" )
    fi
done

if [ $bumped_version == "true" ]; then
    exit 1
fi
