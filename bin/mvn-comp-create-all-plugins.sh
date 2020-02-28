#!/bin/bash
#
# FILE: mvn-comp-create-all-plugins.sh
#
# ABSTRACT: Process all maven plugins from the m2 repository
#
# Search for JARs whose name that like a maven plugin and process it with
# mvn-comp-create-plugin.sh.
#
# If multiple versions of a plugin are available, all are processed. Due to
# sorting the *-SNAPSHOT version is processed after the release version.
#
# TODO: Proper sorting of version numbers.
#
# AUTHOR: Ralf Schandl
#

script_dir="$(cd "$(dirname "$0")" && pwd)"
script_name="$(basename "$0")"

if ! type xpath >/dev/null 2>&1; then
    echo >&2 "ERROR: Executable 'xpath' is not available ... can't continue"
    exit 1
fi

if [ -f "$HOME/.m2/settings.xml" ]; then
    repo="$(xpath -q -e "/settings/localRepository/text()" "$HOME/.m2/settings.xml")"
    if [ -z "$repo" ]; then
        repo="$HOME/.m2/repository"
    fi
fi

if [ $# -gt 0 ]; then
    echo
    echo "Usage: $script_name"
    echo
    echo "Creates completion-plugins for all maven-plugins found below"
    echo "   $repo"
    echo
    exit 1
fi



if sort -k2V /dev/null &>/dev/null; then
    # Version-sort supported -- good
    # Here it gets complicated:
    # 1. find all jar files that look like a maven plugin
    # 2. filter out source and javadoc archives
    # 3. Split into 3 pipe-separated fields: dir|version|jar-file
    # 4. Sort first by dir (-k1,1) and then by version reverse (-k2,2rV -- 'V' enables version sorting)
    # 5. Now replace the pipes with slashes to get the proper filename again
    # 6. Run mvn-comp-create-plugin.sh on the file list
    find "$repo" -name .cache -prune -o \( -name "*maven-plugin-*.jar" -o -name "maven-*-plugin-*.jar" \) -print |
        grep -v '\(sources\|javadoc\)\.jar' |
        sed 's%\(^.*\)/\([0-9][^/]*\)/\([^/]*\.jar\)$%\1|\2|\3%' |
        sort '-t|' -k1,1 -k2,2rV |
        awk -F"|" '!_[$1]++' |
        sed "s%|%/%g" |
        xargs "$script_dir/mvn-comp-create-plugin.sh"

    echo
    echo "WARNING: Completion plugin not necessarily generated from latest version."
    echo "WARNING: E.g. SNAPSHOT or RC1 is preferred to release version."
else
    # Version-sort NOT supported -- good
    # Much easier:
    # 1. find all jar files that look like a maven plugin
    # 2. filter out source and javadoc archives
    # 3. Sort list
    # 3. Run mvn-comp-create-plugin.sh on the file list
    find "$repo" -name .cache -prune -o \( -name "*maven-plugin-*.jar" -o -name "maven-*-plugin-*.jar" \) -print |
        grep -v '\(sources\|javadoc\)\.jar' |
        sort |
        xargs "$script_dir/mvn-comp-create-plugin.sh"

    echo
    echo "WARNING: Files were lexically sorted. Not sure the latest version was used"
    echo "WARNING: to generate the completion plugin."
    echo "WARNING: The available 'sort' command does not support version-sorting."
    echo "WARNING: Version-sorting would provide a better (but not perfect) result."
fi

