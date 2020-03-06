<?xml version="1.0" encoding="UTF-8"?>
<!--
File:   mvn-comp-create-extension.xsl

Abstract: Create a mvn-comp extension from a plugin.xml

Author: Ralf Schandl
-->
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform" version="1.0">
    <xsl:output method="text" encoding="UTF-8"/>

    <xsl:template match="/plugin">
        <xsl:if test="not(mojos/mojo/goal)">
            <!-- No goals - nothing to do -->
            <xsl:message terminate="yes">
                <xsl:text>Maven plugin </xsl:text>
                <xsl:value-of select="groupId/text()"/>
                <xsl:text>:</xsl:text>
                <xsl:value-of select="artifactId/text()"/>
                <xsl:text>:</xsl:text>
                <xsl:value-of select="version/text()"/>
                <xsl:text> has no goals.</xsl:text>
            </xsl:message>
        </xsl:if>

        <!-- script header -->
        <xsl:text>#!/bin/sh&#xA;</xsl:text>
        <xsl:text># maven-completion extension for </xsl:text>
        <xsl:value-of select="groupId/text()"/>
        <xsl:text>:</xsl:text>
        <xsl:value-of select="artifactId/text()"/>
        <xsl:text>&#xA;</xsl:text>
        <xsl:text># Created from version </xsl:text>
        <xsl:value-of select="version/text()"/>
        <xsl:text>&#xA;</xsl:text>
        <xsl:text># FILE: </xsl:text>
        <xsl:value-of select="groupId/text()"/>
        <xsl:text>.</xsl:text>
        <xsl:value-of select="artifactId/text()"/>
        <xsl:text>.mvmcomp-ext</xsl:text>
        <xsl:text>&#xA;&#xA;</xsl:text>

        <!-- function register -->
        <xsl:text>register()&#xA;</xsl:text>
        <xsl:text>{&#xA;</xsl:text>
        <xsl:text>    echo "</xsl:text>
        <xsl:value-of select="groupId/text()"/>
        <xsl:text>:</xsl:text>
        <xsl:value-of select="artifactId/text()"/>
        <xsl:text>"&#xA;</xsl:text>
        <xsl:if test='./goalPrefix'>
            <xsl:text>    echo "</xsl:text>
            <xsl:value-of select="goalPrefix/text()"/>
            <xsl:text>"&#xA;</xsl:text>
        </xsl:if>
        <xsl:text>}&#xA;&#xA;</xsl:text>

        <!-- function goals -->
        <xsl:text>goals()&#xA;</xsl:text>
        <xsl:text>{&#xA;</xsl:text>
        <xsl:text>    echo "</xsl:text>
        <xsl:for-each select="mojos/mojo">
            <xsl:if test="position() != 1">
                <xsl:text>|</xsl:text>
            </xsl:if>
            <xsl:value-of select="goal/text()"/>
        </xsl:for-each>
        <xsl:text>"&#xA;</xsl:text>
        <xsl:text>}&#xA;&#xA;</xsl:text>

        <!-- function goal_options -->
        <xsl:text>goal_options()&#xA;</xsl:text>
        <xsl:text>{&#xA;</xsl:text>
        <xsl:for-each select="mojos/mojo">
            <xsl:text>    </xsl:text>
            <xsl:if test="position() != 1">
                <xsl:text>el</xsl:text>
            </xsl:if>
            <xsl:text>if [ "$1" = "</xsl:text><xsl:value-of select="goal/text()"/>
            <xsl:text>" ]; then&#xA;</xsl:text>

            <xsl:text>        echo "</xsl:text>
            <xsl:for-each select="configuration/*">
                <xsl:variable name="conf_name" select="name()" />
                <xsl:variable name="prop_name" select="substring-after(substring-before(text(),'}'), '{')" />
                <xsl:if test="string-length($prop_name) &gt; 0 and //parameters/parameter[name/text()=$conf_name]/editable/text() = 'true'">
                    <xsl:text>|</xsl:text>
                    <xsl:text>-D</xsl:text>
                    <xsl:value-of select="substring-after(substring-before(text(),'}'), '{')"/>
                    <xsl:text>=</xsl:text>
                    <xsl:if test="@implementation = 'boolean' or @implementation = 'java.lang.Boolean'">
                        <xsl:choose>
                            <xsl:when test="@default-value = 'true'">
                                <xsl:text>false</xsl:text>
                            </xsl:when>
                            <xsl:when test="@default-value = 'false'">
                                <xsl:text>true</xsl:text>
                            </xsl:when>
                            <xsl:otherwise>
                                <xsl:text>true</xsl:text>
                            </xsl:otherwise>
                        </xsl:choose>
                    </xsl:if>
                </xsl:if>
            </xsl:for-each>
            <xsl:text>"&#xA;</xsl:text>
        </xsl:for-each>
        <xsl:text>    fi&#xA;</xsl:text>
        <xsl:text>}&#xA;&#xA;</xsl:text>

        <!-- MAIN -->
        <xsl:text>if [ "$1" = "register" ]; then&#xA;</xsl:text>
        <xsl:text>    register&#xA;</xsl:text>
        <xsl:text>elif [ "$1" = "goals" ]; then&#xA;</xsl:text>
        <xsl:text>    goals&#xA;</xsl:text>
        <xsl:text>elif [ "$1" = "goalopts" ]; then&#xA;</xsl:text>
        <xsl:text>    if [ $# != 2 ];then&#xA;</xsl:text>
        <xsl:text>        echo >&amp;2 "ERROR: Missing goal name"&#xA;</xsl:text>
        <xsl:text>        exit 1&#xA;</xsl:text>
        <xsl:text>    fi&#xA;</xsl:text>
        <xsl:text>    goal_options "$2"&#xA;</xsl:text>
        <xsl:text>else&#xA;</xsl:text>
        <xsl:text>    echo "Usage:"&#xA;</xsl:text>
        <xsl:text>    echo "    register         - show names to register the extension"&#xA;</xsl:text>
        <xsl:text>    echo "    goals            - list goals (pipe separated)"&#xA;</xsl:text>
        <xsl:text>    echo "    goalopts &lt;goal>  - list options for given goal"&#xA;</xsl:text>
        <xsl:text>    exit 1&#xA;</xsl:text>
        <xsl:text>fi&#xA;</xsl:text>

        <xsl:text>&#xA;</xsl:text>
    </xsl:template>
</xsl:stylesheet>
