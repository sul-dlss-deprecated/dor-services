<?xml version="1.0" encoding="UTF-8"?> 
<!-- $Id: demoFoxmlToLucene.xslt 5734 2006-11-28 11:20:15Z gertsp $ -->
<xsl:stylesheet version="1.0"
	exclude-result-prefixes="dc exts xalan fedora-model fedora-types fn foxml hydra oai_dc rdf rel uvalibadmin uvalibdesc xsl" 
	xmlns:dc="http://purl.org/dc/elements/1.1/"
	xmlns:exts="xalan://dk.defxws.fedoragsearch.server.GenericOperationsImpl"
	xmlns:xalan="http://xml.apache.org/xalan"
	xmlns:fedora-model="info:fedora/fedora-system:def/model#"
	xmlns:fedora-types="http://www.fedora.info/definitions/1/0/types/"
	xmlns:fn="http://www.w3.org/TR/xpath-functions/"
	xmlns:foxml="info:fedora/fedora-system:def/foxml#"
	xmlns:hydra="http://projecthydra.org/ns/relations#" xmlns:mods="http://www.loc.gov/mods/v3"
	xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
	xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
	xmlns:rel="info:fedora/fedora-system:def/relations-external#"
	xmlns:uvalibadmin="http://dl.lib.virginia.edu/bin/admin/admin.dtd/"
	xmlns:uvalibdesc="http://dl.lib.virginia.edu/bin/dtd/descmeta/descmeta.dtd"
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
	<xsl:variable name="INDEXVERSION">2.0.3</xsl:variable>
	
	<xsl:param name="INCLUDE_EXTERNALS" select="true()"/>
	<xsl:param name="REPOSITORYNAME" select="repositoryName"/>
	<xsl:param name="FEDORASOAP" select="repositoryName"/>
	<xsl:param name="FEDORAUSER" select="repositoryName"/>
	<xsl:param name="FEDORAPASS" select="repositoryName"/>
	<xsl:param name="TRUSTSTOREPATH" select="repositoryName"/>
	<xsl:param name="TRUSTSTOREPASS" select="repositoryName"/>
	<xsl:variable name="PID" select="/foxml:digitalObject/@PID"/>
	<xsl:variable name="docBoost" select="1.4*2.5"/>
	<xsl:variable name="OBJECTTYPE"
		select="//foxml:datastream/foxml:datastreamVersion[last()]//identityMetadata/objectType/text()"/>
	<xsl:variable name="DATASTREAM_LIST">
		<ds name="RELS-EXT"/>
		<ds name="DC"/>
		<ds name="identityMetadata"/>
		<ds name="descMetadata"/>
		<ds name="embargoMetadata"/>
		<ds name="administrativeMetadata"/>
		<ds name="roleMetadata"/>
		<ds name="contentMetadata"/>
		<ds match="WF"/>
	</xsl:variable>
	<xsl:variable name="INDEXED_DATASTREAMS" select="xalan:nodeset($DATASTREAM_LIST)"/>

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
				<xsl:when test="//dc:title">
					<xsl:value-of select="//dc:title/text()"/>
				</xsl:when>
				<xsl:otherwise>
					<xsl:value-of select="$PID"/>
				</xsl:otherwise>
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
						<xsl:value-of select="concat('fgs_', substring-after(@NAME,'#'), '_date')"/>
					</xsl:when>
					<xsl:otherwise>
						<xsl:value-of select="concat('fgs_', substring-after(@NAME,'#'), '_field')"
						/>
					</xsl:otherwise>
				</xsl:choose>
			</xsl:attribute>
			<xsl:value-of select="@VALUE"/>
		</field>
	</xsl:template>

	<xsl:template match="foxml:datastream">
		<field name="fedora_datastream_version_field">
			<xsl:value-of select="foxml:datastreamVersion[last()]/@ID"/>
		</field>
		<xsl:apply-templates select="foxml:datastreamVersion[last()]"/>		
	</xsl:template>
	
	<!-- Index inline datastreams -->
	<xsl:template match="foxml:datastream[foxml:datastreamVersion/foxml:xmlContent]/foxml:datastreamVersion[last()]">
		<xsl:variable name="datastream-name" select="../@ID"/>
		<xsl:apply-templates select="foxml:xmlContent/*">
			<xsl:with-param name="datastream-name" select="$datastream-name"/>
		</xsl:apply-templates>
	</xsl:template>
	
	<!-- Index managed/external datastreams -->
	<xsl:template match="foxml:datastream[foxml:datastreamVersion/foxml:contentLocation]/foxml:datastreamVersion[last()]">
		<xsl:if test="$INCLUDE_EXTERNALS">
			<xsl:variable name="ds" select="."/>
			<xsl:variable name="datastream-name" select="../@ID"/>
			<xsl:variable name="datastream-ts" select="@CREATED"/>
			<xsl:variable name="content-location" select="foxml:contentLocation/@REF"/>
			<xsl:for-each select="$INDEXED_DATASTREAMS/*">
				<xsl:if test="(@name and (@name = $datastream-name)) or (@match and contains($datastream-name,@match))">
					<xsl:variable name="content-uri">
						<xsl:choose>
							<xsl:when test="contains($content-location, '/fedora/get/')">http://localhost:8080/fedora/<xsl:value-of select="substring-after($content-location,'/fedora/')"/></xsl:when>
							<xsl:otherwise><xsl:value-of select="$content-location"/></xsl:otherwise>
						</xsl:choose>
					</xsl:variable>
					<xsl:message>Retrieving <xsl:value-of select="$content-uri"/></xsl:message>
					<xsl:apply-templates select="document($content-uri)/*">
						<xsl:with-param name="datastream-name" select="$datastream-name"/>
					</xsl:apply-templates>
				</xsl:if>
			</xsl:for-each>
		</xsl:if>
	</xsl:template>
	
	<!-- Index RELS-EXT -->
	<xsl:template match="rdf:RDF/rdf:Description">
		<!-- Grab the cmodel -->
		<xsl:for-each select="./fedora-model:hasModel">
			<field name="fedora_has_model_field">
				<xsl:value-of select="@rdf:resource"/>
			</field>
		</xsl:for-each>
		<xsl:for-each select="*[@rdf:resource]">
			<xsl:variable name="doc-pid" select="substring-after(./@rdf:resource,'info:fedora/')"/>
			<field name="{local-name(.)}_id_field">
				<xsl:value-of select="$doc-pid"/>
			</field>
			<field name="{local-name(.)}_id_facet">
				<xsl:value-of select="$doc-pid"/>
			</field>
		</xsl:for-each>
	</xsl:template>
	<!-- Index DC -->
	<xsl:template match="oai_dc:dc">
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
	<xsl:template match="identityMetadata">
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
				<xsl:call-template name="valid-field-name">
					<xsl:with-param name="name" select="$tag-name"/>
				</xsl:call-template>
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
	<xsl:template match="mods:mods">
		<!-- Grab the MODS identifiers -->
		<xsl:for-each select="./mods:identifier">
			<xsl:variable name="identifier-label">
				<xsl:call-template name="valid-field-name">
					<xsl:with-param name="name" select="@displayLabel"/>
				</xsl:call-template>
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
			<xsl:if test="mods:role/mods:roleTerm[@type='text']">
				<xsl:variable name="role" select="mods:role/mods:roleTerm[@type='text']/text()"/>
				<field name="mods_{$role}_field">
					<xsl:value-of select="mods:namePart/text()"/>
				</field>
				<field name="mods_{$role}_text">
					<xsl:value-of select="mods:namePart/text()"/>
				</field>
			</xsl:if>
		</xsl:for-each>
		<xsl:for-each select="mods:originInfo/mods:publisher">
			<field name="mods_publisher_field">
				<xsl:value-of select="text()"/>
			</field>
			<field name="mods_publisher_text">
				<xsl:value-of select="text()"/>
			</field>
		</xsl:for-each>
		<xsl:for-each select="mods:originInfo/mods:place/mods:placeTerm[@type='text']">
			<field name="mods_origininfo_place_field">
				<xsl:value-of select="text()"/>
			</field>
			<field name="mods_origininfo_place_text">
				<xsl:value-of select="text()"/>
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
		<xsl:for-each
			select="//mods:*[contains(local-name(),'date') or contains(local-name(), 'Date')]">
			<xsl:variable name="date-label">
				<xsl:call-template name="valid-field-name">
					<xsl:with-param name="name" select="local-name()"/>
				</xsl:call-template>
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
	<xsl:template match="contentMetadata">
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
	
	<!-- Index embargo metadata -->
	<xsl:template match="embargoMetadata">
		<xsl:if test="(status != '') and (releaseDate != '')">
			<field name="embargo_status_field">
				<xsl:value-of select="status"/>
			</field>
			<field name="embargo_release_date">
				<xsl:value-of select="releaseDate"/>
			</field>
		</xsl:if>
	</xsl:template>
	
	<!-- Workflows -->
	<xsl:template match="workflow">
		<xsl:param name="datastream-name" select="ancestor::foxml:datastream/@ID"/>
		<xsl:variable name="workflow-name" select="$datastream-name"/>
		<xsl:variable name="workflow-token">
			<xsl:call-template name="valid-field-name">
				<xsl:with-param name="name" select="$workflow-name"/>
			</xsl:call-template>
		</xsl:variable>
		<field name="wf_facet">
			<xsl:value-of select="$workflow-name"/>
		</field>
		<field name="wf_wsp_facet">
			<xsl:value-of select="$workflow-name"/>
		</field>
		<field name="wf_wps_facet">
			<xsl:value-of select="$workflow-name"/>
		</field>
		<xsl:for-each select="process">
			<xsl:if test="@status='completed' and @lifecycle">
				<field name="lifecycle_field">
					<xsl:value-of select="@lifecycle"/>:<xsl:value-of select="@datetime"/>
				</field>
			</xsl:if>
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
	<xsl:template match="administrativeMetadata">
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
	
	<xsl:template match="roleMetadata">
		<xsl:for-each select="./role/*">
			<xsl:variable name="role_value"><xsl:value-of select="identifier/@type"/>:<xsl:value-of
					select="identifier/text()"/></xsl:variable>
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
		<xsl:value-of
			select="translate($name,' ABCDEFGHIJKLMNOPQRSTUVWXYZ','_abcdefghijklmnopqrstuvwxyz')"/>
	</xsl:template>
</xsl:stylesheet>
