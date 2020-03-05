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
script_name="$(basename "$0")"

plugin_dir=${mvn_completion_plugin_dir:-$HOME/.maven-completion.d}
xsl_file="mvn-comp-create-plugin.xsl"

typeset -a xslt_cmd
if [ "$OSTYPE" = "msys" ]; then

    if ! type xsltproc >/dev/null 2>&1 || ! xsltproc </dev/null >/dev/null 2>&1; then
        if type msxsl.exe >/dev/null 2>&1; then
            xslt_cmd=( msxsl - "$script_dir/$xsl_file" )
        else
            echo >&2 "ERROR: Neither working xsltproc nor msxsl.exe found ... can't continue"
            exit 1
        fi
    fi
else
    if ! type xpath >/dev/null 2>&1; then
        echo >&2 "ERROR: Executable 'xpath' is not available ... can't continue"
        exit 1
    fi
    if ! type xsltproc >/dev/null 2>&1; then
        echo >&2 "ERROR: Executable 'xsltproc' is not available ... can't continue"
        exit 1
    fi
    xslt_cmd=( xsltproc "$script_dir/$xsl_file" - )
fi



create_plugin()
{
    jar="$1"

    if ! plugin_xml="$(unzip -qc "$jar" META-INF/maven/plugin.xml 2>/dev/null)"; then
        echo >&2 "ERROR: Not a mvn plugin (META-INF/maven/plugin.xml not found): $jar"
        return 1
    fi

    tmp_file="$(mktemp)"

    if ! echo "$plugin_xml"| "${xslt_cmd[@]}" > "$tmp_file"; then
        echo >&2 "ERROR: XSLT failed"
        rm -f "$tmp_file"
        return 1
    fi

    if [ "$OSTYPE" != "msys" ]; then
        target_file="$plugin_dir/$(echo "$plugin_xml" | xpath -q -s . -e "concat(/plugin/groupId/text(),'.', /plugin//artifactId/text(),'.mc-plugin')" 2>/dev/null)"
    else
        target_file="$plugin_dir/$(grep "^# FILE:" "$tmp_file" | sed 's/^# FILE: //')"
    fi

    mv -f "$tmp_file" "$target_file"
    chmod +x "$target_file"

    echo "Created $target_file from $(basename "$jar")"
}

if [ $# -eq 0 ]; then
    echo
    echo "Usage: $script_name <plugin-jar-file> ..."
    echo
    echo "Creates completion-plugins for all given maven-plugin jars."
    echo
else
    if [ ! -e "$plugin_dir" ]; then
        if ! mkdir "$plugin_dir"; then
            echo >&2 "ERROR: Can't create mvn completion plugin dir: $plugin_dir"
            exit 1
        fi
    fi

    for jar in "$@"; do
        create_plugin "$jar"
    done
fi

