#!/bin/bash
#
# FILE: mvn-comp-create-extension.sh
#
# ABSTRACT: Create Completion Extensions for given Jar Files
#
# AUTHOR: Ralf Schandl
#
# CREATED: 2019-11-17
#

version=0.1.0

script_dir="$(cd "$(dirname "$0")" && pwd)"
script_name="$(basename "$0")"

ext_dir=${mvn_completion_ext_dir:-$HOME/.maven-completion.d}
xsl_file="mvn-comp-create-extension.xsl"


if [ $# -eq 0 ] || [[ " $*" = *' --help'* ]] || [[ " $*" = *' --version'* ]]; then
    echo "$script_name  v$version"
    echo
    echo "Usage: $script_name <plugin-jar-file> ..."
    echo
    echo "Creates completion-extensions for all given maven-plugin jars."
    echo
    exit 1
fi

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



create_extension()
{
    jar="$1"

    if [ ! -r "$jar" ]; then
        echo >&2 "Jar does not exist / not readable: $jar"
        return
    fi

    if ! plugin_xml="$(unzip -qc "$jar" META-INF/maven/plugin.xml 2>/dev/null)"; then
        echo >&2 "ERROR: Not a mvn plugin (META-INF/maven/plugin.xml not found): $jar"
        return 1
    fi

    tmp_file="$(mktemp)"

    # tr -d '\r' to replace CRLF with LF on Windows
    set -o pipefail
    if ! echo "$plugin_xml"| "${xslt_cmd[@]}" | tr -d '\r' > "$tmp_file"; then
        echo >&2 "ERROR: XSLT failed"
        rm -f "$tmp_file"
        return 1
    fi

    if [ "$OSTYPE" != "msys" ]; then
        target_file="$ext_dir/$(echo "$plugin_xml" | xpath -q -s . -e "concat(/plugin/groupId/text(),'.', /plugin//artifactId/text(),'.mc-ext')" 2>/dev/null)"
    else
        target_file="$ext_dir/$(grep "^# FILE:" "$tmp_file" | sed 's/^# FILE: //')"
    fi

    mv -f "$tmp_file" "$target_file"
    chmod +x "$target_file"

    echo "Created $target_file from $(basename "$jar")"
}

if [ ! -d "$ext_dir" ]; then
    if ! mkdir "$ext_dir"; then
        echo >&2 "ERROR: Can't create mvn completion extensions dir: $ext_dir"
        exit 1
    fi
fi

for jar in "$@"; do
    create_extension "$jar"
done

