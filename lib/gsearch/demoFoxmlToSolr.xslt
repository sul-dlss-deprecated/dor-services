<?xml version="1.0" encoding="UTF-8"?> 
<!-- $Id: demoFoxmlToLucene.xslt 5734 2006-11-28 11:20:15Z gertsp $ -->
<xsl:stylesheet exclude-result-prefixes="exts" version="1.0"
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
	xmlns:fedora-model="info:fedora/fedora-system:def/model#"
	xmlns:foxml="info:fedora/fedora-system:def/foxml#" xmlns:mods="http://www.loc.gov/mods/v3"
	xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rel="info:fedora/fedora-system:def/relations-external#"
	xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/"
	xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
	xmlns:fn="http://www.w3.org/TR/xpath-functions/"
	xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:zs="http://www.loc.gov/zing/srw/">
	<xsl:output encoding="UTF-8" indent="yes" method="xml"/>
	<!--
	 This xslt stylesheet generates the Solr doc element consisting of field elements
     from a FOXML record. The PID field is mandatory.
     Options for tailoring:
       - generation of fields from other XML metadata streams than DC
       - generation of fields from other datastream types than XML
         - from datastream by ID, text fetched, if mimetype can be handled
             currently the mimetypes text/plain, text/xml, text/html, application/pdf can be handled.
-->
	<xsl:param name="REPOSITORYNAME" select="repositoryName"/>
	<xsl:param name="FEDORASOAP" select="repositoryName"/>
	<xsl:param name="FEDORAUSER" select="repositoryName"/>
	<xsl:param name="FEDORAPASS" select="repositoryName"/>
	<xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
	<xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>
	<xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
	<xsl:variable name="docBoost" select="1.4*2.5"/>
	
	<xsl:variable name="OBJECTTYPE" select="//foxml:datastream/foxml:datastreamVersion[last()]//identityMetadata/objectType/text()"/>

  <xsl:variable name="INDEXVERSION" select="'1.1.2011092801'"/>

	<!-- or any other calculation, default boost is 1.0 -->
	<xsl:template match="/">
		<add>
			<doc boost="{$docBoost}">
				<xsl:apply-templates/>
			</doc>
		</add>
	</xsl:template>
	
	<xsl:template match="/foxml:digitalObject">
		<field name="index_version_field">
			<xsl:value-of select="$INDEXVERSION"/>
		</field>
		<field boost="2.5" name="PID">
			<xsl:value-of select="$PID"/>
		</field>
		<field name="namespace_field">
			<xsl:value-of select="substring-before($PID,':')"/>
		</field>
		<field name="namespace_facet">
			<xsl:value-of select="substring-before($PID,':')"/>
		</field>
		<field name="link_text_display">
			<xsl:choose>
				<xsl:when test="//dc:title"><xsl:value-of select="//dc:title/text()"/></xsl:when>
				<xsl:otherwise><xsl:value-of select="$PID"/></xsl:otherwise>
			</xsl:choose>
		</field>
		<xsl:apply-templates select="*"/>
	</xsl:template>
	
	<xsl:template match="foxml:objectProperties/foxml:property">
			<field>
				<xsl:attribute name="name">
					<!-- if this is a data field, append with date, otherwise field -->
					<xsl:choose>
						<xsl:when test="contains(@NAME, 'Date')">
							<xsl:value-of
								select="concat('fgs_', substring-after(@NAME,'#'), '_date')"/>
						</xsl:when>
						<xsl:otherwise>
							<xsl:value-of
								select="concat('fgs_', substring-after(@NAME,'#'), '_field')"/>
						</xsl:otherwise>
					</xsl:choose>
				</xsl:attribute>
				<xsl:value-of select="@VALUE"/>
			</field>
	</xsl:template>

	<xsl:template match="foxml:datastream">
<!--
		<field name="fedora_datastream_id_field">
			<xsl:value-of select="@ID"/>
		</field>
-->
		<xsl:apply-templates select="./foxml:datastreamVersion[last()]/foxml:xmlContent"/>
		<xsl:apply-templates select="./foxml:datastreamVersion[last()]/foxml:contentLocation"/>
	</xsl:template>

	<!-- Index RELS-EXT -->
	<xsl:template match="rdf:RDF[ancestor::foxml:datastream[@ID='RELS-EXT']]">
		<!-- Grab the cmodel -->
		<xsl:for-each select="./fedora-model:hasModel">
			<field name="fedora_has_model_field">
				<xsl:value-of select="@rdf:resource"/>
			</field>
		</xsl:for-each>
	</xsl:template>

	<!-- Index DC -->
	<xsl:template match="oai_dc:dc[ancestor::foxml:datastream[@ID='DC']]">
		<xsl:for-each select="dc:title|dc:creator|dc:identifier">
			<field name="dc_{local-name(.)}_text">
				<xsl:value-of select="text()"/>
			</field>
		</xsl:for-each>
		<xsl:for-each select="./*">
			<field name="dc_{local-name(.)}_field">
				<xsl:value-of select="text()"/>
			</field>
		</xsl:for-each>
	</xsl:template>
	
	<!-- Index identity metadata -->
	<xsl:template match="identityMetadata[ancestor::foxml:datastream[@ID='identityMetadata']]">
		<xsl:for-each select="./objectType">
			<field name="object_type_field">
				<xsl:value-of select="./text()"/>
			</field>
		</xsl:for-each>
		<xsl:for-each select="./sourceId">
			<field name="dor_id_field">
				<xsl:value-of select="concat(@source, ':', normalize-space(./text()))"/>
			</field>
			<field name="source_id_field">
				<xsl:value-of select="normalize-space(./text())"/>
			</field>
			<field name="identifier_text">
				<xsl:value-of select="concat(@source, ':', normalize-space(./text()))"/>
			</field>
			<field name="identifier_text">
				<xsl:value-of select="normalize-space(./text())"/>
			</field>
		</xsl:for-each>
		<xsl:for-each select="./otherId">
			<field name="dor_id_field">
				<xsl:value-of select="concat(@name, ':', normalize-space(./text()))"/>
			</field>
			<field name="dor_{@name}_id_field">
				<xsl:value-of select="normalize-space(./text())"/>
			</field>
		</xsl:for-each>
		<!-- tags -->
		<xsl:for-each select="./tag">
			<xsl:variable name="text-value" select="normalize-space(./text())"/>
			<field name="tag_field">
				<xsl:value-of select="$text-value"/>
			</field>
			<field name="tag_facet">
				<xsl:value-of select="$text-value"/>
			</field>
			<xsl:variable name="tag-name"
				select="normalize-space(substring-before($text-value, ':'))"/>
			<xsl:variable name="field-name">
				<xsl:call-template name="valid-field-name"><xsl:with-param name="name" select="$tag-name"/></xsl:call-template>
				<xsl:text>_tag</xsl:text>
			</xsl:variable>
			<field name="{$field-name}_field">
				<xsl:value-of select="normalize-space(substring-after($text-value, ':'))"/>
			</field>
			<field name="{$field-name}_facet">
				<xsl:value-of select="normalize-space(substring-after($text-value, ':'))"/>
			</field>
		</xsl:for-each>
	</xsl:template>
		
	<!-- Index MODS descriptive metadata -->
	<xsl:template match="mods:mods[ancestor::foxml:datastream[@ID='descMetadata']]">
		<!-- Grab the MODS identifiers -->
		<xsl:for-each select="./mods:identifier">
			<xsl:variable name="identifier-label">
				<xsl:call-template name="valid-field-name"><xsl:with-param name="name" select="@displayLabel"/></xsl:call-template>
			</xsl:variable>
			<field name="mods_identifier_field">
				<xsl:value-of select="@displayLabel"/>:<xsl:value-of select="text()"/>
			</field>
			<field name="mods_{$identifier-label}_identifier_field">
				<xsl:value-of select="text()"/>
			</field>
			<field name="mods_identifier_text">
				<xsl:value-of select="@displayLabel"/>:<xsl:value-of select="text()"/>
			</field>
			<field name="mods_{$identifier-label}_identifier_text">
				<xsl:value-of select="text()"/>
			</field>
		</xsl:for-each>
		
		<xsl:for-each select="mods:titleInfo">
			<xsl:variable name="title-info">
				<xsl:value-of select="mods:nonSort/text()"/>
				<xsl:value-of select="mods:title/text()"/>
				<xsl:if test="mods:subTitle">
					<xsl:text> : </xsl:text>
					<xsl:value-of select="mods:subTitle/text()"/>
				</xsl:if>
			</xsl:variable>
			<field name="mods_titleInfo_field">
				<xsl:value-of select="$title-info"/>
			</field>
			<field name="mods_title_text">
				<xsl:value-of select="$title-info"/>
			</field>
		</xsl:for-each>
		
		<xsl:for-each select="mods:name">
			<field name="mods_name_field">
				<xsl:value-of select="mods:namePart/text()"/>
			</field>
			<field name="mods_name_text">
				<xsl:value-of select="mods:namePart/text()"/>
			</field>
		</xsl:for-each>
		
		<!-- Index some, but not all, MODS fields -->
		<xsl:for-each select="//mods:coordinates|//mods:extent|//mods:scale|//mods:topic">
			<xsl:if test="./text()">
				<field name="mods_{local-name(.)}_field">
					<xsl:value-of select="text()"/>
				</field>
			</xsl:if>
		</xsl:for-each>
		
		<xsl:for-each select="//mods:*[contains(local-name(),'date') or contains(local-name(), 'Date')]">
			<xsl:variable name="date-label">
				<xsl:call-template name="valid-field-name"><xsl:with-param name="name" select="local-name()"/></xsl:call-template>
			</xsl:variable>
			<field name="mods_{$date-label}_field">
				<xsl:value-of select="normalize-space(./text())"/>
			</field>
		</xsl:for-each>
<!--
		<xsl:for-each select=".//mods:*[string-length(normalize-space(text())) &gt; 0]">
			<field name="mods_{local-name(.)}_field"><xsl:value-of select="normalize-space(./text())"/></field>
		</xsl:for-each>
-->
	</xsl:template>
	
	<!-- Index content metadata -->
	<xsl:template match="contentMetadata[ancestor::foxml:datastream[@ID='contentMetadata']]">
	  <field name="content_type_facet">
	    <xsl:value-of select="@type"/>
	  </field>
	  <xsl:apply-templates/>
  </xsl:template>
  
  <xsl:template match="contentMetadata/resource/file">
	  <field name="content_file_field">
	    <xsl:value-of select="@id"/>
	  </field>
	  <xsl:if test="@shelve = 'yes'">
  	  <field name="shelved_content_file_field">
  	    <xsl:value-of select="@id"/>
  	  </field>
  	</xsl:if>
  </xsl:template>
  
	<!-- Workflows -->
	<xsl:template match="foxml:contentLocation[contains(@REF,'/workflows/')]">
		<xsl:apply-templates select="document(@REF)/workflow">
			<xsl:with-param name="workflow-name" select="ancestor::foxml:datastream/@ID"/>
		</xsl:apply-templates>
	</xsl:template>

	<xsl:template match="workflow">
		<xsl:param name="workflow-name" select="ancestor::foxml:datastream/@ID"/>
		<xsl:variable name="workflow-token">
			<xsl:call-template name="valid-field-name"><xsl:with-param name="name" select="$workflow-name"/></xsl:call-template>
		</xsl:variable>
		<field name="wf_facet"><xsl:value-of select="$workflow-name"/></field>
		<field name="wf_wsp_facet"><xsl:value-of select="$workflow-name"/></field>
		<field name="wf_wps_facet"><xsl:value-of select="$workflow-name"/></field>
		<xsl:for-each select="process">
			<field name="wf_wsp_facet">
				<xsl:value-of select="concat($workflow-name,':',@status)"/>
			</field>
			<field name="wf_wsp_facet">
				<xsl:value-of select="concat($workflow-name,':',@status,':',@name)"/>
			</field>
			
			<field name="wf_wps_facet">
				<xsl:value-of select="concat($workflow-name,':',@name)"/>
			</field>
			<field name="wf_wps_facet">
				<xsl:value-of select="concat($workflow-name,':',@name,':',@status)"/>
			</field>

			<field name="wf_swp_facet">
				<xsl:value-of select="@status"/>
			</field>
			<field name="wf_swp_facet">
				<xsl:value-of select="concat(@status,':',$workflow-name)"/>
			</field>
			<field name="wf_swp_facet">
				<xsl:value-of select="concat(@status,':',$workflow-name,':',@name)"/>
			</field>
		</xsl:for-each>
	</xsl:template>

	<!-- Admin Policy specific fields -->
	<xsl:template match="administrativeMetadata[ancestor::foxml:datastream[@ID='administrativeMetadata']]">
		<xsl:if test="./descMetadata/format">
			<field name="apo_metadata_format_field">
				<xsl:value-of select="./descMetadata/format/text()"/>
			</field>
		</xsl:if>
		<xsl:if test="./descMetadata/format">
			<field name="apo_metadata_source_field">
				<xsl:value-of select="./descMetadata/source/text()"/>
			</field>
		</xsl:if>
		
		<xsl:for-each select="registration/workflow">
			<field name="apo_registration_workflow_field">
				<xsl:value-of select="@id"/>
			</field>
		</xsl:for-each>
	</xsl:template>

	<xsl:template match="roleMetadata[ancestor::foxml:datastream[@ID='roleMetadata']]">
		<xsl:for-each select="./role/*">
			<xsl:variable name="role_value"><xsl:value-of select="identifier/@type"/>:<xsl:value-of select="identifier/text()"/></xsl:variable>
			<field name="apo_role_{local-name(.)}_{../@type}_field">
				<xsl:value-of select="$role_value"/>
			</field>
			<field name="apo_role_{local-name(.)}_{../@type}_facet">
				<xsl:value-of select="$role_value"/>
			</field>
			<xsl:if test="../@type = 'depositor' or ../@type = 'manager'">
				<field name="apo_register_permissions_field">
					<xsl:value-of select="$role_value"/>
				</field>
				<field name="apo_register_permissions_facet">
					<xsl:value-of select="$role_value"/>
				</field>
			</xsl:if>
		</xsl:for-each>
	</xsl:template>
	
	<!-- Utility Templates -->
	<xsl:template match="text()|@*|processing-instruction()|comment()"/>
	
	<xsl:template name="valid-field-name">
		<xsl:param name="name"/>
		<xsl:value-of select="translate($name,' ABCDEFGHIJKLMNOPQRSTUVWXYZ','_abcdefghijklmnopqrstuvwxyz')"/>
	</xsl:template>
	
</xsl:stylesheet>
