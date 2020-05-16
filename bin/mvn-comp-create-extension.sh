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

typeset -a xslt_cmd
typeset repo_dir

#
# Determine local .m2 directory by asking Maven
#
init_repo_path()
{
    if ! command -v mvn >/dev/null 2>&1; then
        echo >&2 "ERROR: Executable 'mvn' is not available ... can't continue"
        exit 1
    fi
    repo_dir="$(mvn -q -B help:evaluate -Dexpression=settings.localRepository -DforceStdout=true)"
    if [[ "$repo_dir" = ?:* ]]; then
        # path starts with any char followed by colon -> looks like Windows
        # Change backslashes to slashes
        repo_dir="${repo_dir//\\/\/}"
    fi
}

#
# Initialize the command line used to call the XSLT processor
#
init_xslt_proc()
{
    if [ "$OSTYPE" = "msys" ]; then

        if ! command -v xsltproc >/dev/null 2>&1 || ! xsltproc </dev/null >/dev/null 2>&1; then
            if command -v msxsl.exe >/dev/null 2>&1; then
                xslt_cmd=( msxsl - "$script_dir/$xsl_file" )
            else
                echo >&2 "ERROR: Neither working xsltproc nor msxsl.exe found ... can't continue"
                exit 1
            fi
        else
            xslt_cmd=( xsltproc "$script_dir/$xsl_file" - )
        fi
    else
        if ! command -v xpath >/dev/null 2>&1; then
            echo >&2 "ERROR: Executable 'xpath' is not available ... can't continue"
            exit 1
        fi
        if ! command -v xsltproc >/dev/null 2>&1; then
            echo >&2 "ERROR: Executable 'xsltproc' is not available ... can't continue"
            exit 1
        fi
        xslt_cmd=( xsltproc "$script_dir/$xsl_file" - )
    fi
}

#
# create a completion extension from a jar file
# Handles not exiting files and JARs that don't have a
# META-INF/maven/plugin.xml.
# $1: The jar file
create_extension()
{
    jar="$1"

    if [ ! -r "$jar" ]; then
        echo >&2 "ERROR: Jar does not exist / not readable: $jar"
        return 1
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

#
# Search the m2 repository directory for maven plugins and return a list of
# jars to convert.  This functions tries to sort by version number and only
# return the latest jars, but this might fail.
# Sorting maven versions is not trivial because of '-SNAPSHOT', '-alpha', '-RC'
# etc. So this might return a SNAPSHOT while a real release is available.
# Bad luck.
#
scan_repo_dir()
{
    if sort -k2V /dev/null &>/dev/null; then
        # Version-sort supported -- good
        # Here it gets complicated:
        # 1. find all *.pom files that describe a maven plugin
        # 2. replace extension '.pom' with '.jar'
        # 3. list exiting files, redirect stderr
        # 4. Split into 3 pipe-separated fields: dir|version|jar-file
        # 5. Sort first by dir (-k1,1) and then by version reverse (-k2,2rV -- 'V' enables version sorting)
        # 6. remove dulicate lower versions
        # 7. Now replace the pipes with slashes to get the proper filename again
        #find "$repo_dir" -name .cache -prune -o \( -name "*maven-plugin-*.jar" -o -name "maven-*-plugin-*.jar" \) -print |
        find "$repo_dir" -name \*.pom -exec grep -l "<packaging>maven-plugin</packaging>" {} \; |
            sed 's/\.pom$/.jar/' |
            xargs -d$'\n' ls 2>/dev/null |
            sed 's%\(^.*\)/\([0-9][^/]*\)/\([^/]*\.jar\)$%\1|\2|\3%' |
            sort '-t|' -k1,1 -k2,2rV |
            awk -F"|" '!_[$1]++' |
            sed "s%|%/%g"
        #
    else
        # Version-sort NOT supported -- not so good
        # 1. find all *.pom files that describe a maven plugin
        # 2. replace extension '.pom' with '.jar'
        # 3. list exiting files, redirect stderr
        # 4. Sort list
        # 5. Split into 3 pipe-separated fields: dir|version|jar-file
        # 6. remove dulicate lower versions
        # 7. Now replace the pipes with slashes to get the proper filename again
        find "$repo_dir" -name \*.pom -exec grep -l "<packaging>maven-plugin</packaging>" {} \; |
            sed 's/\.pom$/.jar/' |
            xargs -d$'\n' ls 2>/dev/null |
            sort -r |
            sed 's%\(^.*\)/\([0-9][^/]*\)/\([^/]*\.jar\)$%\1|\2|\3%' |
            awk -F"|" '!_[$1]++' |
            sed "s%|%/%g"
        exit

    fi
}

show_help()
{
    echo "Usage:"
    echo "    $script_name <plugin-jar-file> ..."
    echo
    echo "    Creates completion-extensions for all given maven-plugin jars."
    echo
    echo " or"
    echo "    $script_name --all"
    echo
    echo "    Creates completion-extensions for all maven-plugins found in the local"
    echo "    repository. By default this is ~/.m2/repository/, but this scritpt asks"
    echo "    Maven for the actual repository."
    echo
    echo " or"
    echo "    $script_name [ --help | --version ]"
    echo
}

show_version()
{
    echo "$script_name  v$version"
}

#---------[ MAIN ]-------------------------------------------------------------

init_xslt_proc

while getopts ":-:" o "$@"; do
    case $o in
        -)
            case $OPTARG in
                all)
                    search_the_repo=true
                    ;;
                help)
                    show_help
                    exit 0
                    ;;
                version)
                    show_version
                    exit 0
                    ;;
                *)
                    echo >&2 "ERROR: Unknown option: --$OPTARG"
                    show_help
                    exit 1
                    ;;
            esac
            ;;
        *)
            echo >&2 "ERROR: Unknown option: -$OPTARG"
            show_help
            exit 1
            ;;
    esac
done
shift $((OPTIND-1))

if [ "${search_the_repo:-}" != true ] && [ "$#" -eq 0 ]; then
    show_help
    exit 1
fi

typeset -a jar_list
if [ "$search_the_repo" = 'true' ]; then
    printf "Determine repository directory ... "
    init_repo_path
    printf "it's %s\n" "$repo_dir"
    echo "Searching ..."
    mapfile -t jar_list < <(scan_repo_dir)
else
    jar_list=( "$@" )
fi

if [ ! -d "$ext_dir" ]; then
    if ! mkdir "$ext_dir"; then
        echo >&2 "ERROR: Can't create mvn completion extensions dir: $ext_dir"
        exit 1
    fi
fi

for jar in "${jar_list[@]}"; do
    create_extension "$jar"
done

