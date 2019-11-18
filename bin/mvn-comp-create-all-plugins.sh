#!/bin/bash
#
# FILE: mvn-comp-create-all-plugins.sh
#
# ABSTRACT: Process all maven plugins from the m2 repository
#
# Search for JARs whose name that like a maven plugin and process it with
# mvn-comp-create-plugin.sh.
#
# If multiple versions of a plugin is available, all are processed. Due to
# sorting the *-SNAPSHOT version is processed after the release version.
#
# TODO: Proper handling of version numbers.
#
# AUTHOR: Ralf Schandl
#

script_dir="$(cd "$(dirname "$0")" && pwd)"
script_name="$(basename "$0")"
script_file="$script_dir/$script_name"

repo="$(xpath -q -e "/settings/localRepository/text()" "$HOME/.m2/settings.xml")"
if [ -z "$repo" ]; then
    repo="$HOME/.m2/repository"
fi

find $repo -name .cache -prune -o \( -name "*maven-plugin-*.jar" -o -name "maven-*-plugin-*.jar" \) -print |
    grep -v '\(sources\|javadoc\)\.jar' | sort |
    xargs $script_dir/mvn-comp-create-plugin.sh



