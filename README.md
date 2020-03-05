
# Bash MAVEN completion

This project provides a bash completion script for the Apache Maven build tool.

The script is initially based on the [maven-completion from Juven
Xu](https://github.com/juven/maven-bash-completion). A lot of stuff were added
or changed, but some parts are still from Juven Xu.

## Installation

1. Copy the file `_maven-completion.bash` to `$HOME/.maven-completion.bash`
2. Add the following line to your `.bashrc`:
   ```
   [ -f "$HOME/.maven-completion.bash" ] && . "$HOME/.maven-completion.bash"
   ```
3. Run the script `bin/mvn-comp-create-all-plugins.sh` (see below)
4. Start a new shell (or source `.maven-completion.bash`)


In step 3 the script `bin/mvn-comp-create-all-plugins.sh` scans the local
repository for all JARs that are named like a maven-plugin and will
generate a completion-plugin for it. The completion-plugins are stored in the
directory `$HOME/.mvn-completion.d`.

The script might issue error messages for JARs that seems to be a plugin by
name but isn't one or plugins without goals (yes, this is possible). Just
ignore them.

See [Completion-Plugins](#completion-plugins) below for details.


## Features

### Configuration

Then maven completion can be configured with two options

#### `mvn_completion_no_parsing`

If the environment variable `mvn_completion_no_parsing` is set to any non-empty
value, parsing the POMs is disabled all together. This is useful on machines
with slow file IO (maybe due to a virus scanner monitoring all file operations)
or very large code bases.

#### `mvn_completion_parser`

This options gives a hint which parser to use for parsing the POMs. See
"Parser Selection" below.



### Parsing Profiles

When the argument for `-P` or `--activate-profiles` should be completed, the
script parses the POM for profile names. It parses the current POM, all child
POMS and all parent POMS as found in the current source tree.

Restriction: Parent POMS from the M2 directory or a remote repository are _not_
parsed.

The result of parsing the POMs is cached in a environment variable. If the
maven completion is invoked for a different POM, the cached profiles are
discarded and the POM(s) are parsed again.

Parsing is done either with `xsltproc`, `xpath` or `grep` (and friends).

Performance of parsing with `grep` or `xsltproc` is nearly the same, but `grep`
is less precise. For example it doesn't know XML comments, so it might return
profile names that are actually commented out. Also it requires proper
formatted POMs with only one tag per line.

The script also checks for `msxsl.exe` and uses it if `xsltproc` is not
available or not working. Performance with this tool could not be assessed
(virus scanner on test machine).

The performance of `xpath` (from the Perl package) is much slower (factor 10 or
more).  Support for `xpath` might be removed in the future.

__Parser Selection__

The parser is selected in the following order:

1. `xsltproc`
2. `msxsl` (on Windows, maybe needs to be downloaded from Microsoft)
3. `xpath` (Perl)
4. `grep` (and other text tools)

Whatever is found first is used.

The environment variable `mvn_completion_parser` can be used to influence the
selection:

* `msxsl`: Skip `xsltproc` and start selection with `msxsl`.
* `xpath`: Skip xslt processors and start selection with `xpath`.
* `grep`: Use `grep`.

If no xsl processor is available, consider setting `mvn_completion_parser` to
`grep` as `xpath` is just slow. Or disable parsing by setting
`mvn_completion_no_parsing`.


### Completion-Plugins

The completion script is able to load completion-plugins to support additional
maven-plugins.

Completion-Plugins are executable scripts that provide support for completion
for additional maven-plugins. They are registered on the first invocation of
the maven completion function and executed on demand.

Completion-Plugins have 3 integration points:

1. `register` to list the maven-plugin names the plugin want to register
2. `goals` to list the goals of the maven-plugin
3. `goalopts <goal>` to list the options defined by the given goal


Here is the example usage for the completion-plugin for the
`maven-shade-plugin`:

```
~/.maven-completion.d $ ./org.apache.maven.plugins.maven-shade-plugin.mc-plugin register
org.apache.maven.plugins:maven-shade-plugin
maven-shade-plugin
shade

~/.maven-completion.d $ ./org.apache.maven.plugins.maven-shade-plugin.mc-plugin goals
help|shade

~/.maven-completion.d $ ./org.apache.maven.plugins.maven-shade-plugin.mc-plugin goalopts shade
|-DshadeSourcesContent=true

```


#### Manually create a Completion-Plugin

NOTE: Before starting to write a script, see next section.

Create a file in `~/.maven-completion.d` with a file name with the extension `mc-plugin`.

Example - plugin for the `maven-shade-plugin`:
```
register()
{
    # the full name
    echo "org.apache.maven.plugins:maven-shade-plugin"
    # as groupId is org.apache.maven.plugins, also detected without it
    echo "maven-shade-plugin"
    # the goalPrefix
    echo "shade"
}

goals()
{
    echo "help|shade"
}

goal_options()
{
    if [ "$1" = "help" ]; then
        echo "|-Ddetail=true|-Dgoal=|-DindentSize=|-DlineLength="
    elif [ "$1" = "shade" ]; then
        echo "|-DshadeSourcesContent=true"
    fi
}

if [ "$1" = "register" ]; then
    register
elif [ "$1" = "goals" ]; then
    goals
elif [ "$1" = "goalopts" ]; then
    if [ $# != 2 ];then
        echo >&2 "ERROR: Missing goal name"
        exit 1
    fi
    goal_options "$2"
else
    echo "Usage:"
    echo "    register         - show names to register the plugin"
    echo "    goals            - list goals (pipe separated)"
    echo "    goalopts <goal>  - list options for given goal"
fi

```

#### Script to create Completion-Plugins

Fortunately Maven has some rules about the content of the JAR file of a
maven-plugin.  It has to contain the file `META-INF/maven/plugin.xml`. This
file describes the plugin, its goals and the options supported by each goal.

That makes creating a completion-plugin quite easy. Just unpack the file
`META-INF/maven/plugin.xml` from the JAR and filter it through XSLT.

The script `bin/mvn-comp-create-plugin.sh` with the XSL stylesheet
`bin/mvn-comp-create-plugin.xsl` does exactly that.

Example:

```
~ $ bin/mvn-comp-create-plugin.sh ~/.m2/repository/org/apache/maven/plugins/maven-shade-plugin/3.2.1/maven-shade-plugin-3.2.1.jar
Created /home/.../.maven-completion.d/org.apache.maven.plugins.maven-shade-plugin.mc-plugin from maven-shade-plugin-3.2.1.jar
```

Note: This needs the `xsltproc` executable.

### Caching

As described in the section [Profiles](#profiles) the parsed profiles are
cached in environment variables.

Also the available plugins are cached in the file
`~/.maven-completion.d/mc-plugin.cache`. This file is updated whenever the
maven completion is first used in a new shell _and_ there is some `*.mc-plugin`
that is newer than the cache file.

To delete the cached data in environment variables and to force the up-to-date
check for completion-plugins execute the command `mvn_comp_reset`.  On the next
invocation of the completion code the current pom will be parsed again and it
is checked if the plugin-cache is up-to-date.

## Supporting Tools

* `xsltproc` - a XSLT processor (package `xsltproc` on Debian, `libxslt` on RH)
* `xpath` - a simple XPath processor (package `libxml-xpath-perl` on Debian,
  `perl-XML-XPath` on RH)
* `msxsl` - a XSLT processor for Windows. AFAIK not installed by default. Get
  it from
  [Microsoft](https://www.microsoft.com/en-us/download/details.aspx?id=21714).


## License

As the original code of maven-completion, this is released under Apache License 2.



