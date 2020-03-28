#!/bin/sh
#
# Check if all scripts contain correct version.
#

set -u

script_dir="$(cd "$(dirname "$0")" && pwd)" || exit 1

version="$1"
rc=0

if [ -z "$version" ]; then
    echo "ERROR: Can't check for empty version"
    exit 2
fi

cd "$script_dir" || exit 1

if grep "extensible-maven-completion v$version" _maven-completion.bash >/dev/null; then
    echo "OK:    _maven-completion.bash"
else
    echo >&1 "ERROR: _maven-completion.bash"
    rc=1
fi

for fn in bin/*.sh bin/*.xsl; do
    if grep "^version=$version" "$fn" >/dev/null; then
        echo "OK:    $fn"
    else
        echo >&1 "ERROR: $fn"
        rc=1
    fi
done
exit $rc

