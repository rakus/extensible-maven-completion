#!/bin/bash
#
# FILE: mvn-comp-create-plugin.sh
#
# ABSTRACT:
#
# AUTHOR: Ralf Schandl
#
# CREATED: 2019-11-17
#

script_dir="$(cd "$(dirname "$0")" && pwd)"

plugin_dir="$HOME/.maven-completion.d"
xsl_file="mvn-comp-create-plugin.xsl"


if [ ! -e "$plugin_dir" ]; then
    if ! mkdir "$plugin_dir"; then
        echo >&2 "ERROR: Can't create mvn completion plugin dir: $plugin_dir"
        exit 1
    fi
fi

create_plugin()
{
    jar="$1"

    #plugin_xml="$(unzip -qc "$jar" META-INF/maven/plugin.xml 2>/dev/null)"
    #if [ $? != 0 ]; then
    if ! plugin_xml="$(unzip -qc "$jar" META-INF/maven/plugin.xml 2>/dev/null)"; then
        echo >&2 "ERROR: Not a mvn plugin (META-INF/maven/plugin.xml not found): $jar"
        return 1
    fi

    tmp_file="$(mktemp)"

    if ! echo "$plugin_xml"| xsltproc "$script_dir/$xsl_file" - > "$tmp_file"; then
        echo >&2 "ERROR: XSLT failed"
        return 1
    fi

    target_file="$plugin_dir/$(grep "^# FILE:" "$tmp_file" | cut -d: -f2 | tr -d ' \t')"

    mv -f "$tmp_file" "$target_file"
    chmod +x "$target_file"

    echo "Created $target_file"
}

for jar in "$@"; do
    create_plugin "$jar"
done

