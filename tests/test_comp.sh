#!/usr/bin/bash
#
# FILE: test_comp.sh
#
# ABSTRACT: tests for maven-completion.bash
#
# Idea and code from https://brbsix.github.io/2015/11/29/accessing-tab-completion-programmatically-in-bash/
#
# AUTHOR: Ralf Schandl
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
    # shellcheck disable=SC1091
    [ -e /usr/share/bash-completion/bash_completion ] && source /usr/share/bash-completion/bash_completion
}
if [ "$OSTYPE" = "msys" ]; then
    # shellcheck disable=SC1091
    [ -e "/etc/profile.d/git-prompt.sh" ] && source  "/etc/profile.d/git-prompt.sh"
fi

export mvn_completion_ext_dir="$script_dir/workdir/maven-completion.d"
mkdir -p "$mvn_completion_ext_dir"
# shellcheck disable=SC1090
source "$mvn_completion_script"
rm -f "$mvn_completion_ext_dir/mc-ext.cache"

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
    local msg=$1
    shift
    if [ $# -gt 0 ]; then
        printf '%s: %s, Expected: "%s", Actual: "%s"\n' "$ERROR" "$msg" "$1" "$2"
    else
        printf '%s: %s\n' "$ERROR" "$msg"
    fi
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
        log_error "$*" "$expected" "$actual"
    fi
}


section "Downloading maven plugins and creating completion extensions"

create_comp_ext()
{
    local grp="$1"
    local artifact="$2"
    local version="$3"

    local mvn_plugin="$test_m2/$artifact-$version.jar"
    local comp_ext="$mvn_completion_ext_dir/$grp.$artifact.mc-ext"

    if [ ! -e "$mvn_plugin" ]; then
        echo "Downloading $grp:$artifact:$version"
        mvn dependency:copy -DoutputDirectory="$test_m2" \
            -Dartifact="$grp:$artifact:$version" \
            -Dtransitive=false >/dev/null
    fi

    rm -f "$comp_ext"

    "$script_dir/../bin/mvn-comp-create-extension.sh" "$mvn_plugin"


    if [ -e "$comp_ext" ]; then
        log_ok "Completion Extension created"
    else
        log_error "Completion Extension NOT created"
    fi

    # shellcheck disable=SC2155
    local cmt_fn="$(grep "^# FILE:" "$comp_ext" | sed 's/^# FILE: //')"
    if [ "$cmt_fn" = "$(basename "$comp_ext")" ]; then
        log_ok "Completion Extension file comment"
    else
        log_error "Completion Extension file comment" "$(basename "$comp_ext")" "$cmt_fn"
    fi

    if "$comp_ext" register &>/dev/null; then
        log_ok "Completion Extension returns 0"
    else
        log_error "Run Completion Extension returned $?"
    fi

    local goals goalopts IFS
    IFS='|' read -r -a goals < <("$comp_ext" goals)
    for goal in "${goals[@]}"; do
        goalopts="$("$comp_ext" goalopts "$goal")"
        if [ -n "$goalopts" ]; then
            if [[ "$goalopts" = "|"* ]]; then
                log_ok "goalopts $goal: Leading pipe"
            else
                log_error "goalopts $goal: Leading pipe" "leading pipe" "$goalopts"
            fi
            if [[ "$goalopts" = *"|" ]]; then
                log_error "goalopts $goal: No trailing pipe" "no trailing pipe" "$goalopts"
            else
                log_ok "goalopts $goal: No trailing pipe"
            fi
        fi
    done

    if [ -z "$("$comp_ext" goalopts "invalid goal")" ]; then
        log_ok "goalopts: No output on invalid goal"
    else
        log_error "goalopts: No output on invalid goal" "" "$("$comp_ext" goalopts "invalid goal")"
    fi

    err_stdout="$($comp_ext wrong 2>/dev/null)"
    if [ -z "$err_stdout" ]; then
        log_ok "Completion Extension error msg to stderr"
    else
        log_error "Completion Extension error msg to stderr" "" "$(echo "$err_stdout" | paste -sd' ')"
    fi

    local shellcheck
    if ! shellcheck="$(shellcheck -fgcc "$comp_ext")"; then
        log_error "Shellcheck Completion Extension reports findings:"
        echo "$shellcheck"
    else
        log_ok "Shellcheck Completion Extension"
    fi

}

create_comp_ext "org.apache.maven.plugins" "maven-deploy-plugin" "2.7"
create_comp_ext "org.apache.maven.plugins" "maven-dependency-plugin" "2.10"

# Test extension cache created
_mvn >/dev/null 2>&1
if [ -e "$mvn_completion_ext_dir/mc-ext.cache" ]; then
    log_ok "Check mc-ext.cache created"
else
    log_error "File mc-ext.cache NOT created"
fi

# Test extension cache refreshed
touch "$mvn_completion_ext_dir"/*.mc-ext
mvn_comp_reset
_mvn >/dev/null 2>&1
# shellcheck disable=SC2012
if [[ "$(ls -tr "$mvn_completion_ext_dir"/* | tail -n1)" = *"/mc-ext.cache" ]]; then
    log_ok "Check mc-ext.cache refresh"
else
    log_error "File mc-ext.cache not refreshed"
fi

section "Lifecycle Completion"

# disable extensions
export mvn_completion_ext_dir="$script_dir/OFF"
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

# reenable extensions
export mvn_completion_ext_dir="$script_dir/workdir/maven-completion.d"
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
        log_error "Profile Cache" "deep-profile|delete|test|top-profile" "$__mvn_last_pom_profiles"
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

    # reset cache
    mvn_comp_reset
    if [ -z "$__mvn_last_pom_profiles" ]; then
        log_ok "Reset Profile Cache"
        export __mvn_last_pom_profiles
    else
        log_error  "Reset Profile Cache" "" "$__mvn_last_pom_profiles"
    fi

}

check_profile_completion
check_profile_completion msxsl
check_profile_completion xpath
check_profile_completion grep


echo "-----"
echo "Tests: $test_count  Failed: $error_count"

[ $error_count -ne 0 ] && exit 1
exit 0


