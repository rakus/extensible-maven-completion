#!/usr/bin/bash
#
# FILE: test_comp.sh
#
# ABSTRACT: tests for maven-completion.bash
#
# Idea and code from https://brbsix.github.io/2015/11/29/accessing-tab-completion-programmatically-in-bash/
#
# AUTHOR: Ralf Schandl <ralf.schandl@de.ibm.com>
#
# CREATED: 2020-03-04
#

script_dir="$(cd "$(dirname "$0")" && pwd)" || exit 1
#script_name="$(basename "$0")"
#script_file="$script_dir/$script_name"

mvn_completion_script="${1:-$script_dir/../_maven-completion.bash}"
# shellcheck disable=SC1090
source "$mvn_completion_script"

cd "$script_dir" || exit 1

test_count=0
error_count=0

# load bash-completion if necessary
declare -F _completion_loader &>/dev/null || {
    [ -e /usr/share/bash-completion/bash_completion ] && source /usr/share/bash-completion/bash_completion
}
if [ "$OSTYPE" = "msys" ]; then
    [ -e "/etc/profile.d/git-prompt.sh" ] && source  "/etc/profile.d/git-prompt.sh"
fi

export mvn_completion_plugin_dir="$script_dir/workdir/maven-completion.d"
mkdir -p "$mvn_completion_plugin_dir"
# shellcheck disable=SC1090
source "$mvn_completion_script"
rm -f "$mvn_completion_plugin_dir/mc-plugin.cache"

export test_m2="$script_dir/workdir/m2"
mkdir -p "$test_m2"

if ! declare -F _mvn &>/dev/null; then
    echo >&2 "ERROR: Maven completion not loaded"
    exit 1
fi

if [ -t 1 ]; then
    OK="$(tput bold;tput setaf 2)OK$(tput sgr0)"
    ERROR="$(tput bold;tput setaf 1)ERROR$(tput sgr0)"
else
    OK="OK"
    ERROR="ERROR"
fi

get_completions(){
    local COMP_CWORD COMP_LINE COMP_POINT COMP_WORDS COMPREPLY=()

    COMP_LINE=$*
    COMP_POINT=${#COMP_LINE}

    eval set -- "$@"

    COMP_WORDS=("$@")

    # add '' to COMP_WORDS if the last character of the command line is a space
    [[ "$COMP_LINE" = *' ' ]] && COMP_WORDS+=('')

    # index of the last word
    COMP_CWORD=$(( ${#COMP_WORDS[@]} - 1 ))

    # execute completion function
    _mvn

    # print completions to stdout
    printf '%s\n' "${COMPREPLY[@]}" | LC_ALL=C sort | paste -sd ','
}

section()
{
    echo ""
    echo "$*"
}
log_ok()
{
    echo "$OK:    $*"
    ((test_count = test_count + 1))
}
log_error()
{
    local expected="$1"
    local got="$2"
    shift 2
    echo "$ERROR: $*, Expected: \"$expected\", Got: \"$got\""
    ((test_count = test_count + 1))
    ((error_count = error_count + 1))
}


assert_completion()
{
    local expected actual
    expected="$1"
    shift
    actual="$(get_completions "$@")"

    if [ "$expected" = "$actual" ]; then
        log_ok "$*"
    else
        log_error "$expected" "$actual" "$*"
    fi
}


section "Downloading maven plugins and creating completion plugins"

create_comp_plugin()
{
    local grp="$1"
    local artifact="$2"
    local version="$3"

    local mvn_plugin="$test_m2/$artifact-$version.jar"
    local comp_plugin="$mvn_completion_plugin_dir/$grp.$artifact.mc-plugin"

    if [ ! -e "$mvn_plugin" ]; then
        mvn dependency:copy -DoutputDirectory="$test_m2" \
            -Dartifact=$grp:$artifact:$version \
            -Dtransitive=false >/dev/null
    fi

    rm -f "$comp_plugin"

    "$script_dir/../bin/mvn-comp-create-plugin.sh" "$mvn_plugin"


    if [ -e "$comp_plugin" ]; then
        log_ok "Completion Plugin created"
    else
        log_error "created" "missing" "Completion Plugin created"
    fi

    if "$comp_plugin" register &>/dev/null; then
        log_ok "Completion Plugin returns 0"
    else
        log_error "returns 0" "returned $?" "Run Completion Plugin"
    fi
}

create_comp_plugin "org.apache.maven.plugins" "maven-deploy-plugin" "2.7"
create_comp_plugin "org.apache.maven.plugins" "maven-dependency-plugin" "2.10"

# Test plugin cache created
_mvn >/dev/null 2>&1
if [ -e "$mvn_completion_plugin_dir/mc-plugin.cache" ]; then
    log_ok "Check mc-plugin.cache created"
else
    log_error "File mc-plugin.cache created" "File missing"
fi


section "Lifecycle Completion"

# disable plugins
export mvn_completion_plugin_dir="$script_dir/OFF"
mvn_comp_reset
assert_completion "validate " mvn validate
assert_completion "initialize " mvn initialize
assert_completion "generate-sources " mvn generate-sources
assert_completion "process-sources " mvn process-sources
assert_completion "generate-resources " mvn generate-resources
assert_completion "process-resources " mvn process-resources
assert_completion "compile " mvn compile
assert_completion "process-classes " mvn process-classes
assert_completion "generate-test-sources " mvn generate-test-sources
assert_completion "process-test-sources " mvn process-test-sources
assert_completion "generate-test-resources " mvn generate-test-resources
assert_completion "process-test-resources " mvn process-test-resources
assert_completion "test-compile " mvn test-compile
assert_completion "process-test-classes " mvn process-test-classes
assert_completion "test ,test-compile " mvn test
assert_completion "prepare-package " mvn prepare-package
assert_completion "package " mvn package
assert_completion "pre-integration-test " mvn pre-integration-test
assert_completion "integration-test " mvn integration-test
assert_completion "post-integration-test " mvn post-integration-test
assert_completion "verify " mvn verify
assert_completion "install " mvn install
assert_completion "deploy " mvn deploy
assert_completion "pre-site " mvn pre-site
assert_completion "site ,site-deploy " mvn site
assert_completion "post-site " mvn post-site
assert_completion "site-deploy " mvn site-deploy

assert_completion "clean " mvn cl
assert_completion "compile " mvn co
assert_completion "package " mvn pack
assert_completion "install " mvn inst
assert_completion "deploy " mvn depl

# reenable plugins
export mvn_completion_plugin_dir="$script_dir/workdir/maven-completion.d"
mvn_comp_reset


section "Switch Completion"

assert_completion "--activate-profiles " mvn --activate
assert_completion "-rf " mvn -r
assert_completion "-npr ,-npu ,-nsu " mvn -n
assert_completion "-npr ,-npu " mvn -np
assert_completion "-npr " mvn -npr

assert_completion "-up " mvn -u
assert_completion "--update-plugins " mvn --update-plugin


section "Lifecycle & Plugins Completion"

assert_completion "deploy ,deploy:" mvn depl
assert_completion "dependency:" mvn depe
assert_completion "dependency:,deploy ,deploy:" mvn de

assert_completion "analyze-only " mvn dependency:analyze-o

assert_completion "-Dmdep.analyze.skip=true " mvn dependency:analyze -Dmdep.an

assert_completion "purge-local-repository " mvn dependency:pu

assert_completion "-DskipITs ,-DskipTests "  mvn -Dskip
assert_completion "-DskipTests "  mvn -DskipT


#---------[ Profile Completion ]-----------------------------------------------

check_profile_completion()
{
    mvn_completion_parser="$1"
    # shellcheck disable=SC1090
    source "$mvn_completion_script"

    case "$(declare -f __mvn_get_module_poms)" in
        *xsltproc*) parser="xsltproc" ;;
        *msxsl*) parser="msxsl" ;;
        *xpath*) parser="xpath" ;;
        *grep*) parser="grep" ;;
        *) parser=UNKNOWN ;;
    esac
    section "Testing profile completion with $parser (mvn_completion_parser=\"$mvn_completion_parser\")"

    #mvn_comp_reset
    cd "$script_dir/project" || exit 1

    get_completions mvn -P > /dev/null 2>&1
    if [ "$__mvn_last_pom_profiles" = "deep-profile|delete|test|top-profile" ]; then
        log_ok "Profile Cache"
        export __mvn_last_pom_profiles
    else
        log_error "deep-profile|delete|test|top-profile" "$__mvn_last_pom_profiles" "Profile Cache"
    fi

    # working with cached profiles
    assert_completion "top-profile," mvn -P top
    assert_completion "delete," mvn -P del
    assert_completion "deep-profile,,delete,,test,,top-profile," mvn "-P "
    assert_completion "-Pdeep-profile,,-Pdelete,,-Ptest,,-Ptop-profile," mvn "-P"

    # always parsing for profiles as __mvn_last_pom does not match
    cd "$script_dir/project/module-1" || exit 1
    assert_completion "top-profile," mvn -P top
    assert_completion "delete," mvn -P del
    assert_completion "deep-profile," mvn -P deep

}

check_profile_completion
check_profile_completion msxsl
check_profile_completion xpath
check_profile_completion grep


echo "-----"
echo "Tests: $test_count  Failed: $error_count"

[ $error_count -ne 0 ] && exit 1
exit 0


