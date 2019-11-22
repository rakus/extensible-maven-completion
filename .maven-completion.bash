#
# Bash completion for MAVEN
#
# RECOMMENDED: xsltproc or xpath
#
# AUTHOR: Ralf Schandl
# Based on work by Juven Xu. See https://github.com/juven/maven-bash-completion
#
# ----------------------------------------------------------------------------
# shellcheck shell=bash
# shellcheck disable=SC2207,SC2155

_mvn_has_xsltproc="$(type -P xsltproc 2>/dev/null)"
_mvn_has_xpath="$(type -P xpath 2>/dev/null)"

#mvc_debug()
#{
#    echo "$@" >> $HOME/maven-completion.log
#}

#---------[ Make sure some standart functions exist ]--------------------------
_mvn_function_exists()
{
    declare -F "$1" > /dev/null
    return $?
}

_mvn_function_exists _get_comp_words_by_ref ||
_get_comp_words_by_ref ()
{
    local exclude cur_ words_ cword_;
    if [ "$1" = "-n" ]; then
        exclude=$2;
        shift 2;
    fi;
    __git_reassemble_comp_words_by_ref "$exclude";
    cur_=${words_[cword_]};
    while [ $# -gt 0 ]; do
        case "$1" in
            cur)
                cur=$cur_
            ;;
            prev)
                prev=${words_[$cword_-1]}
            ;;
            words)
                # shellcheck disable=SC2034
                words=("${words_[@]}")
            ;;
            cword)
                # shellcheck disable=SC2034
                cword=$cword_
            ;;
        esac;
        shift;
    done
}

_mvn_function_exists __ltrim_colon_completions ||
    __ltrim_colon_completions()
    {
        if [[ "$1" == *:* && "$COMP_WORDBREAKS" == *:* ]]; then
            # Remove colon-word prefix from COMPREPLY items
            local colon_word=${1%${1##*:}}
            local i=${#COMPREPLY[*]}
            while [[ $((--i)) -ge 0 ]]; do
                COMPREPLY[$i]=${COMPREPLY[$i]#"$colon_word"}
            done
        fi
    }


unset -f _mvn_function_exists

#---------[ POM parsing functions ]--------------------------------------------
# Either using xpath or xslt or (as fallback) grep etc
if [ -n "$_mvn_has_xsltproc" ]; then

    __mvn_get_module_poms()
    {
        xsltproc - "$1" << EOF
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:m="http://maven.apache.org/POM/4.0.0">
    <xsl:output method="text"/>
    <xsl:template match="/">
        <xsl:for-each select="//m:modules/m:module">
            <xsl:value-of select="text()"/><xsl:text>/pom.xml&#xA;</xsl:text>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
EOF
}

__mvn_get_pom_profiles()
{
    xsltproc - "$@" << EOF
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:m="http://maven.apache.org/POM/4.0.0">
    <xsl:output method="text"/>
    <xsl:template match="/">
        <xsl:for-each select="/m:project/m:profiles/m:profile/m:id">
            <xsl:value-of select="text()"/><xsl:text>&#xA;</xsl:text>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
EOF
}

__mvn_get_parent_pom_path()
{
    xsltproc - "$1" << EOF
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:m="http://maven.apache.org/POM/4.0.0">
    <xsl:output method="text"/>
    <xsl:template match="/">
        <xsl:apply-templates/>
    </xsl:template>
    <xsl:template match="/m:project/m:parent">
        <xsl:choose>
            <xsl:when test="./m:relativePath">
                <xsl:value-of select="./m:relativePath/text()"/><xsl:text>&#xA;</xsl:text>
            </xsl:when>
            <xsl:otherwise>
                <xsl:text>../pom.xml&#xA;</xsl:text>
            </xsl:otherwise>
        </xsl:choose>
    </xsl:template>
    <xsl:template match="text()"/>
</xsl:stylesheet>
EOF
}

__mvn_get_settings_profiles()
{
    xsltproc - "$HOME/.m2/settings.xml"  << EOF
<xsl:stylesheet version="1.0"
    xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:m="http://maven.apache.org/POM/4.0.0"
    xmlns:set="http://maven.apache.org/SETTINGS/1.0.0">
    <xsl:output method="text"/>
    <xsl:template match="/">
        <xsl:for-each select="/set:settings/set:profiles/set:profile/set:id">
            <xsl:value-of select="text()"/><xsl:text>&#xA;</xsl:text>
        </xsl:for-each>
    </xsl:template>
</xsl:stylesheet>
EOF
}

elif [ -n "$_mvn_has_xpath" ]; then

    __mvn_get_module_poms()
    {
        xpath -q -e '//modules/module/text()' "$1" | sed 's/$/\/pom.xml/'
    }

__mvn_get_pom_profiles()
{
    xpath -q -e '/project/profiles/profile/id/text()' "$@"
}

__mvn_get_parent_pom_path()
{
    local parent
    if [ -n "$(xpath -q -e '/project/parent' "$1" 2>/dev/null)" ]; then
        parent=$(xpath -q -e '/project/parent/relativePath/text()' "$1")
        [ -z "$parent" ] && parent='../pom.xml'
        echo "$parent"
    else
        return 0
    fi
}
__mvn_get_settings_profiles()
{
    xpath -q -e '/settings/profiles/profile/id/text()' "$HOME/.m2/settings.xml"
}

else
    #
    # Fallback using grep and friends. This is "best effort".
    # It requires that every tag is on its own line.
    #
    __mvn_clean_pom()
    {
        # remove comments
        sed 's/<!--.*-->//g;/<!--/,/-->/d' "$@"
    }

__mvn_get_module_poms()
{
    __mvn_clean_pom "$1" | grep "<module>" | sed 's/<[^>]*>//g;s/$/\/pom.xml/' | tr -d ' \t'
}

__mvn_get_pom_profiles()
{
    __mvn_clean_pom "$@" | grep -A2 '<profile>' | grep '<id>' | sed 's/<[^>]*>//g' | tr -d ' \t'
}

__mvn_get_parent_pom_path()
{
    local parent pom
    parent="$(__mvn_clean_pom "$1" | sed -n '/<parent>/,/<\/parent>/p')"
    if [ -n "$parent" ]; then
        pom="$(echo "$parent" | grep "<relativePath>" | sed 's/<[^>]*>//g' | tr -d ' \t')"
        [ -z "$pom" ] && pom='../pom.xml'
        echo "$pom"
    else
        return 0
    fi
}
__mvn_get_settings_profiles()
{
    __mvn_get_pom_profiles "$HOME/.m2/settings.xml"
}

fi

unset _mvn_has_xpath
unset _mvn_has_xsltproc

#---------[ Not parsing functions ]--------------------------------------------

__mvn_get_poms_recursive()
{
    echo "$1"
    local modules=$( __mvn_get_module_poms "$1" | sed "s%^%$(dirname "$1")/%")
    #mvc_debug "recModules: >>$modules<<"
    echo "$modules"
    for m in $modules; do
        __mvn_get_poms_recursive "$m"
    done
}

__mvn_get_parent_poms()
{
    local parent
    [ ! -e "$1" ] && return
    local parent=$(__mvn_get_parent_pom_path "$1")
    if [ -z "$parent" ]; then
        return
    fi
    parent="$(dirname "$1")/$parent"
    if [ ! -e "$parent" ]; then
        #mvc_debug "does not exist: $parent"
        return
    fi
    __mvn_get_parent_poms "$parent"
    echo "$parent"
}

__mvn_get_profiles()
{
    if [ -z "$__mvn_last_pom_profiles" ]; then
        local IFS profs modules
        IFS=$'\n' modules=( $(__mvn_get_poms_recursive "$1" | sort -u) )
        IFS=$'\n' parents=( $(__mvn_get_parent_poms "$1" | sort -u) )
        #mvc_debug "modules: $modules"
        IFS=$'\n' profs=( $(__mvn_get_pom_profiles "${modules[@]}" "${parents[@]}" | sort -u) )
        IFS=$'\n' profs+=( $(__mvn_get_settings_profiles | sort -u) )
        IFS='|' __mvn_last_pom_profiles="${profs[*]}"
    fi
    echo "$__mvn_last_pom_profiles"
}


__mvn_filter_array()
{
    local match="$1"
    shift
    for str in "$@"; do
        if [[ $str = ${match}* ]]; then
            echo "$str"
        fi
    done
}


__mvn_plugin_goal()
{
    local plugin goals suffix

    if [[ ${cur} == *:* ]] ; then
        local plugin="${cur%:*}"
        if [ -n "${__mvn_comp_plugins["$plugin"]}" ]; then
            local goals="$("$HOME/.maven-completion.d/${__mvn_comp_plugins[$plugin]}" goals | sed "s/^/$plugin:/;s/|/|$plugin:/g")"
            suffix=' '
        else
            local goals="$(__mvn_filter_array "$cur" "${!__mvn_comp_plugins[@]}")"
            suffix=':'
        fi
        if [ -n "$goals" ]; then
            COMPREPLY=( $(compgen -W "${goals}" -S "$suffix" -- "${cur}") )
        else
            COMPREPLY=( '' )
        fi
    else
        COMPREPLY+=( $(compgen -W "${!__mvn_comp_plugins[*]}" -S ':' -- "${cur}") )
    fi
}

__mvn_init()
{
    unset __mvn_comp_plugins
    typeset -gA __mvn_comp_plugins

    # shellcheck disable=SC2012
    if [ "$(ls -tr "$HOME/.maven-completion.d" 2>/dev/null| tail -n1)" != "mc-plugin.cache" ]; then
        if [ -d "$HOME/.maven-completion.d" ]; then
            true > "$HOME/.maven-completion.d/mc-plugin.cache"
            for pi in "$HOME/.maven-completion.d/"*.mc-plugin; do
                for al in $($pi register); do
                    #echo >&2 "Registering: >>$al<<"
                    echo "__mvn_comp_plugins[\"$al\"]=\"$(basename "$pi")\"" >> "$HOME/.maven-completion.d/mc-plugin.cache"
                done
            done
        fi
    fi
    # shellcheck disable=SC1090
    . "$HOME/.maven-completion.d/mc-plugin.cache"
    __mvn_inited="true"
}

_mvn()
{
    local cur prev
    COMPREPLY=()
    _get_comp_words_by_ref -n : cur prev

    # Register plugins on first run
    if [ -z "$__mvn_inited" ]; then
        __mvn_init
    fi

    local opts="-am|-amd|-B|-C|-c|-cpu|-D|-e|-emp|-ep|-f|-fae|-ff|-fn|-gs|-h|-l|-N|-npr|-npu|-nsu|-o|-P|-pl|-q|-rf|-s|-T|-t|-U|-up|-V|-v|-X"
    local long_opts="--also-make|--also-make-dependents|--batch-mode|--strict-checksums|--lax-checksums|--check-plugin-updates|--define|--errors|--encrypt-master-password|--encrypt-password|--file|--fail-at-end|--fail-fast|--fail-never|--global-settings|--help|--log-file|--non-recursive|--no-plugin-registry|--no-plugin-updates|--no-snapshot-updates|--offline|--activate-profiles|--projects|--quiet|--resume-from|--settings|--threads|--toolchains|--update-snapshots|--update-plugins|--show-version|--version|--debug"

    local common_clean_lifecycle="pre-clean|clean|post-clean"
    local common_default_lifecycle="validate|initialize|generate-sources|process-sources|generate-resources|process-resources|compile|process-classes|generate-test-sources|process-test-sources|generate-test-resources|process-test-resources|test-compile|process-test-classes|test|prepare-package|package|pre-integration-test|integration-test|post-integration-test|verify|install|deploy"
    local common_site_lifecycle="pre-site|site|post-site|site-deploy"
    local common_lifecycle_phases="${common_clean_lifecycle}|${common_default_lifecycle}|${common_site_lifecycle}"

    local options="-Dmaven.test.skip=true|-DskipTests|-DskipITs|-Dmaven.surefire.debug|-DenableCiProfile|-Dpmd.skip=true|-Dcheckstyle.skip=true|-Dtycho.mode=maven|-Dmaven.javadoc.skip=true|-Dgwt.compiler.skip|-Drestart|-Dtest.project.only|-DfullDeployment=true"

    #local profile_settings=$(__mvn_get_settings_profiles | tr '\n' '|' )

    fqPom=$(readlink -f pom.xml)
    if [ ! -e "$fqPom" ]; then
        # reset cache
        unset __mvn_last_pom_profiles
        unset __mvn_last_pom
    elif [ "$fqPom" != "$__mvn_last_pom" ]; then
        # reset cache
        __mvn_last_pom=$fqPom
        unset __mvn_last_pom_profiles
    fi

    #local profiles="${profile_settings}|${__mvn_last_pom_profiles}"
    local IFS=$'|\n'

    if [[ ${cur} == -D* ]] ; then
        local pl_options=''
        local prev_parts part pl gl part

        IFS=" " read -r -a prev_parts <<< "$COMP_LINE"
        for part in "${prev_parts[@]}"; do
            local pl="${part%:*}"
            local gl="${part##*:}"
            if [ -n "${__mvn_comp_plugins[$pl]}" ]; then
                pl_options="${pl_options}$("$HOME/.maven-completion.d/${__mvn_comp_plugins[$pl]}" goalopts "$gl")"
            fi
        done
        COMPREPLY=( $(compgen -S ' ' -W "${options}${pl_options}" -- "${cur}") )

    elif [[ ${cur} == -P* ]] ; then
        cur=${cur:2}
        local profiles=$(__mvn_get_profiles pom.xml)
        if [[ ${cur} == *,* ]] ; then
            COMPREPLY=( $(compgen -S ',' -W "${profiles}" -P "-P${cur%,*}," -- "${cur##*,}") )
        else
            COMPREPLY=( $(compgen -S ',' -W "${profiles}" -P "-P" -- "${cur}") )
        fi
    elif [[ ${prev} == -P || ${prev} == --activate-profiles ]] ; then
        local profiles=$(__mvn_get_profiles pom.xml)
        if [[ ${cur} == *,* ]] ; then
            COMPREPLY=( $(compgen -S ',' -W "${profiles}" -P "${cur%,*}," -- "${cur##*,}") )
        else
            COMPREPLY=( $(compgen -S ',' -W "${profiles}" -- "${cur}") )
        fi

    elif [[ ${cur} == --* ]] ; then
        COMPREPLY=( $(compgen -W "${long_opts}" -S ' ' -- "${cur}") )

    elif [[ ${cur} == -* ]] ; then
        COMPREPLY=( $(compgen -W "${opts}" -S ' ' -- "${cur}") )

    elif [[ ${prev} == -pl ]] ; then
        if [[ ${cur} == *,* ]] ; then
            COMPREPLY=( $(compgen -d -S ',' -P "${cur%,*}," -- "${cur##*,}") )
        else
            COMPREPLY=( $(compgen -d -S ',' -- "${cur}") )
        fi

    elif [[ ${prev} == -rf || ${prev} == --resume-from ]] ; then
        COMPREPLY=( $(compgen -d -S ' ' -- "${cur}") )

    elif [[ ${cur} == *:* ]] ; then
        __mvn_plugin_goal "${cur}"

    else
        if echo "${common_lifecycle_phases}" | tr '|' '\n' | grep -q -e "^${cur}" ; then
            COMPREPLY=( $(compgen -S ' ' -W "${common_lifecycle_phases}" -- "${cur}") )
        fi
        __mvn_plugin_goal "${cur}"
    fi

    __ltrim_colon_completions "$cur"
}

function mvn_comp_reset()
{
    unset __mvn_last_pom
    unset __mvn_last_pom_profiles
    unset __mvn_inited
    __mvn_init
}

complete -o default -F _mvn -o nospace mvn
complete -o default -F _mvn -o nospace mvnrecursive
complete -o default -F _mvn -o nospace mvnDebug

# vim:ft=sh:
