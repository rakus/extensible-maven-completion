
# Bash completion for MAVEN

This project provides a bash completion script for the Apache Maven build tool.

The script is initially based on the [maven-completion from Juven
Xu](https://github.com/juven/maven-bash-completion). A lot of stuff was added,
but parts are still from Juven Xu.

## Installation

1. Copy the file `.maven-completion.bash` to your home directory
2. Add the following line to your `.bashrc`:
   ```
   [ -f "$HOME/.maven-completion.bash" ] && . "$HOME/.maven-completion.bash"
   ```
3. Run the script `bin/mvn-comp-create-all-plugins.sh` (see below)
4. Start a new shell (or source `.maven-completion.bash`)


In step 3 the script `bin/mvn-comp-create-all-plugins.sh` scans scan the local
repository (`~/.m2/repository` or whatever is configured in
`~/.m2/settings.xml`) for all JARs that are named like a maven-plugin and will
generate a completion-plugin for it. The completion-plugins are stored in the
directory `$HOME/.mvn-completion.d`.

The script might issue error messages for JARs that seems to be a plugin by
name but isn't one. Just ignore them.

See [Completion-Plugins](#completion-plugins) below for details.


## Features

### Parsing Profiles

todo

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
`maven-deploy-plugin`:

```
~/.maven-completion.d $ ./org.apache.maven.plugins.maven-deploy-plugin.mc-plugin register
org.apache.maven.plugins:maven-deploy-plugin
maven-deploy-plugin
deploy

~/.maven-completion.d $ ./org.apache.maven.plugins.maven-deploy-plugin.mc-plugin goals
deploy|deploy-file|help

~/.maven-completion.d $ ./org.apache.maven.plugins.maven-deploy-plugin.mc-plugin goalopts deploy
|-DaltDeploymentRepository=|-DaltReleaseDeploymentRepository=|-DaltSnapshotDeploymentRepository=|-DdeployAtEnd=true|-DretryFailedDeploymentCount=|-Dmaven.deploy.skip=true
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

The scripts to create completion-plugins need the tools

* `xsltproc` - a XSLT processor (package `xsltproc` on Debian based
  distributions)
* `xpath` - a simple XPath processor (package `libxml-xpath-perl` on Debian
  based distributions)

Also the maven completion benefit from this tools. There is a fallback to work
without them, but this depends on properly formatted pom files (one tag per line).

## License

As the original code of maven-completion, this is released under Apache License 2.



