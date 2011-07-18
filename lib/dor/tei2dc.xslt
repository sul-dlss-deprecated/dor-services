<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
    xmlns:tei="http://www.tei-c.org/ns/1.0"
    xmlns:dc="http://purl.org/dc/elements/1.1/"
    xmlns:dcterms="http://purl.org/dc/terms/"
    xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
    xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" 
    exclude-result-prefixes="tei"
    version="1.0">
    
    <xsl:output xml:space="default" indent="yes"/>

    <xsl:template match="/">
        <oai_dc:dc xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://www.openarchives.org/OAI/2.0/oai_dc.xsd">
            <xsl:apply-templates/>
        </oai_dc:dc>
    </xsl:template>

    <xsl:template match="tei:teiHeader">
        <xsl:apply-templates/>
    </xsl:template>
    
    <xsl:template match="tei:fileDesc/tei:titleStmt/tei:title">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:title</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:fileDesc/tei:titleStmt/tei:author">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:creator</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:profileDesc/tei:textClass/tei:keywords/tei:list/tei:item">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:subject</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:encodingDesc/tei:refsDecl|tei:encodingDesc/tei:projectDesc|tei:encodingDesc/tei:editorialDesc">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:description</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:fileDesc/tei:publicationStmt/tei:publisher/tei:publisher|tei:fileDesc/tei:publicationStmt/tei:publisher/tei:pubPlace">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:publisher</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:fileDesc/tei:titleStmt/tei:editor|tei:fileDesc/tei:titleStmt/tei:funder|tei:fileDesc/tei:titleStmt/tei:sponsor|tei:fileDesc/tei:titleStmt/tei:principle">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:contributor</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:fileDesc/tei:publicationStmt/tei:date">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:date</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:extent/tei:seg[@type='size']">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dcterms:extent</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:fileDesc/tei:publicationStmt/tei:idno[@type='ARK']">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:identifier</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:sourceDesc/tei:bibful/tei:publicationStmt/tei:publisher|tei:sourceDesc/tei:bibful/tei:publicationStmt/tei:pubPlace|tei:sourceDesc/tei:bibful/tei:publicationStmt/tei:date|tei:sourceDesc/tei:bibl">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:source</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:profileDesc/tei:langUsage/tei:language">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:language</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:fileDesc/tei:seriesStmt/tei:title">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dc:relation</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:fileDesc/tei:publicationStmt/tei:availability">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dcterms:accessRights</xsl:with-param></xsl:call-template>
    </xsl:template>
    
    <xsl:template match="tei:notesStmt/tei:note[@type='summary']">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dcterms:abstract</xsl:with-param></xsl:call-template>
    </xsl:template>

<!-- 
    <xsl:template match="tei:notesStmt/tei:note[not(@type)]">
        <xsl:call-template name="ptext"><xsl:with-param name="element-name">dcterms:note</xsl:with-param></xsl:call-template>
    </xsl:template>
-->
    
    <xsl:template name="ptext">
        <xsl:param name="element-name"/>
        <xsl:variable name="text">
            <xsl:for-each select=".|./tei:p">
                <xsl:variable name="t" select="normalize-space(./text())"/>
                <xsl:if test="string-length($t) &gt; 0">
                    <xsl:value-of select="$t"/>
                </xsl:if>
            </xsl:for-each>
        </xsl:variable>
        <xsl:if test="string-length($text) &gt; 0">
            <xsl:element name="{$element-name}"><xsl:value-of select="$text"/></xsl:element>
        </xsl:if>
    </xsl:template>
    
    <xsl:template match="text()|@*"/>
    
</xsl:stylesheet>