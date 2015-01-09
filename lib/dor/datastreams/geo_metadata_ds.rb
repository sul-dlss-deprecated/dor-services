# encoding: UTF-8

require 'scanf'
require 'uri'

module Dor
  # GeoMetadataDS is a Fedora datastream for geographic metadata. It uses
  # the ISO 19139 metadata standard schema - a metadata standard for Geographic Information
  # The datastream is packaged using RDF to identify the optional ISO 19139 feature catalog
  # @see http://www.isotc211.org
  # @author Darren Hardy
  class GeoMetadataDS < ActiveFedora::OmDatastream
    include SolrDocHelper
    
    attr_accessor :geometryType, :zipName, :purl
  
    # namespaces
    NS = {
      :rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      :gco => 'http://www.isotc211.org/2005/gco',
      :gmd => 'http://www.isotc211.org/2005/gmd',
      :gfc => 'http://www.isotc211.org/2005/gfc'
    }
    
    # hash with all namespaces
    XMLNS = Hash[NS.map {|k,v| ["xmlns:#{k}", v]}]
    
    # schema locations
    NS_XSD = NS.keys.collect {|k| "#{NS[k]} #{NS[k]}/#{k}.xsd"}

    # [Nokogiri::XSLT::Stylesheet] for ISO 19139 to MODS
    XSLT_GEOMODS = Nokogiri::XSLT(File.read(
                                    File.join(
                                      File.dirname(__FILE__), 'geo2mods.xsl')))
    
    XSLT_DC = Nokogiri::XSLT(File.new(
                               File.expand_path(
                                 File.dirname(__FILE__) + '/../models/mods2dc.xslt')))
    
    # @see http://ruby-doc.org/gems/docs/o/om-1.8.0/OM/XML/Document/ClassMethods.html#method-i-set_terminology
    set_terminology do |t|
      t.root :path => '/rdf:RDF/rdf:Description/gmd:MD_Metadata', 
        'xmlns:gmd' => NS[:gmd], 
        'xmlns:gco' => NS[:gco], 
        'xmlns:rdf' => NS[:rdf]

      t.id_ :path => '/rdf:RDF/rdf:Description[1]/@rdf:about'

      p = './'
      t.dataset_id :path => p + 'gmd:dataSetURI/gco:CharacterString'
      t.file_id :path => p + 'gmd:fileIdentifier/gco:CharacterString'
      t.metadata_dt :path => p + 'gmd:dateStamp/gco:Date/text()' # XXX: Allow DateTime
      t.metadata_language :path => p + 'gmd:MD_Metadata/gmd:language/gmd:LanguageCode[@codeSpace="ISO639-2"]/@codeListValue'

      p = 'gmd:identificationInfo/gmd:MD_DataIdentification/'
      t.abstract :path => p + 'gmd:abstract/gco:CharacterString/text()'
      t.purpose :path => p + 'gmd:purpose/gco:CharacterString/text()'
      t.publisher :path => p + 'gmd:pointOfContact/gmd:CI_ResponsibleParty[gmd:role/gmd:CI_RoleCode/@codeListValue="pointOfContact"]/gmd:organisationName/gco:CharacterString/text()'

      p = 'gmd:identificationInfo/gmd:MD_DataIdentification/gmd:citation/gmd:CI_Citation/'
      t.title :path => p + 'gmd:title/gco:CharacterString/text()'
      t.publish_dt :path => p + 'gmd:date/gmd:CI_Date/gmd:date/gco:Date/text()'
      t.originator :path => p + 'gmd:citedResponsibleParty/gmd:CI_ResponsibleParty[gmd:role/gmd:CI_RoleCode/@codeListValue="originator"]/gmd:organisationName/gco:CharacterString/text()'

      p = 'gmd:distributionInfo/gmd:MD_Distribution/gmd:distributionFormat/gmd:MD_Format/'
      t.format :path => p + 'gmd:name/gco:CharacterString/text()'#, :index_as => [:facetable]
      
      p = 'gmd:distributionInfo/gmd:MD_Distribution/gmd:transferOptions/gmd:MD_DigitalTransferOptions/gmd:onLine/gmd:CI_OnlineResource/'
      t.layername :path => p + 'gmd:name/gco:CharacterString/text()'
      
      # XXX should define projection as codeSpace + ':' + code in terminology
      p = 'gmd:referenceSystemInfo/gmd:MD_ReferenceSystem/gmd:referenceSystemIdentifier/gmd:RS_Identifier/'
      t.projection :path => p + 'gmd:code/gco:CharacterString/text()'
      t.projection_code_space :path => p + 'gmd:codeSpace/gco:CharacterString/text()'
    end
    
    # @return [Nokogiri::XML::Document] with gmd:MD_Metadata as root node
    # @raise [Dor::ParameterError] if MD_Metadata is missing
    def metadata
      root = ng_xml.xpath('/rdf:RDF/rdf:Description/gmd:MD_Metadata', XMLNS)
      if root.nil? or root.empty?
        raise Dor::ParameterError, "Invalid geoMetadata -- missing MD_Metadata: #{root}" 
      else
        Nokogiri::XML(root.first.to_xml)
      end
    end
    
    # @return [Nokogiri::XML::Document] with gfc:FC_FeatureCatalogue as root node, 
    #     or nil if not provided
    def feature_catalogue
      root = ng_xml.xpath('/rdf:RDF/rdf:Description/gfc:FC_FeatureCatalogue', XMLNS)
      if root.nil? or root.empty?
        nil # Feature catalog is optional
      else
        Nokogiri::XML(root.first.to_xml)
      end
    end

    # @return [Nokogiri::XML::Document] Contains skeleton geoMetadata XML
    #    Add your druid as the suffix to rdf:about attributes.
    #    Includes all possible xmlns for gmd and gfc
    def self.xml_template
      Nokogiri::XML::Builder.new do |xml|
        xml['rdf'].RDF XMLNS, 
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          "xsi:schemaLocation" => NS_XSD.join(' ') do
          xml['rdf'].Description 'rdf:about' => nil do
            xml['gmd'].MD_Metadata
          end
          xml['rdf'].Description 'rdf:about' => nil do
            xml['gfc'].FC_FeatureCatalogue
          end
        end
      end.doc
    end

    # Generates MODS from ISO 19139
    #
    # @return [Nokogiri::XML::Document] Derived MODS metadata record
    # @raise [CrosswalkError] Raises if the generated MODS is empty or has no children
    #
    # Uses GML SimpleFeatures for the geometry type (e.g., Polygon, LineString, etc.)
    # @see http://portal.opengeospatial.org/files/?artifact_id=25355
    #
    def to_mods(params = {})      
      params = params.merge({ 
        'geometryType' => "'#{@geometryType.nil?? 'Polygon' : @geometryType}'",
        'zipName' => "'#{@zipName.nil?? 'data.zip' : @zipName}'",
        'purl' => "'#{@purl}'"
      })
      doc = XSLT_GEOMODS.transform(metadata.document, params.to_a.flatten)
      unless doc.root and doc.root.children.size > 0
        raise CrosswalkError, 'to_mods produced incorrect xml'
      end
      # ap doc
      doc.xpath('/mods:mods' + 
        '/mods:subject' + 
        '/mods:cartographics' + 
        '/mods:projection', 
        'xmlns:mods' => Dor::DescMetadataDS::MODS_NS).each do |e|
        # Retrieve this mapping from config file
        case e.content.downcase
        when 'epsg:4326', 'epsg::4326', 'urn:ogc:def:crs:epsg::4326'
          e.content = 'World Geodetic System (WGS84)'
        when 'epsg:4269', 'epsg::4269', 'urn:ogc:def:crs:epsg::4269'
          e.content = 'North American Datum (NAD83)'
        end
      end
      doc.xpath('/mods:mods' +
        '/mods:subject' +
        '/mods:cartographics' +
        '/mods:coordinates', 
        'xmlns:mods' => Dor::DescMetadataDS::MODS_NS).each do |e|
        e.content = '(' + self.class.to_coordinates_ddmmss(e.content.to_s) + ')'
      end
      doc
    end
    
    def to_dublin_core
      XSLT_DC.transform(to_mods)
    end
    
    # @deprecated stub for GeoBlacklight (not Argo -- use to_solr as usual)
    def to_solr_spatial(solr_doc=Hash.new, *args)
      # There are a whole bunch of namespace-related things that can go
      # wrong with this terminology. Until it's fixed in OM, ignore them all.
      begin
        doc = solr_doc#super solr_doc, *args
        bb = to_bbox
        ap({:doc => doc, :bb => bb, :self => self}) if $DEBUG
        {
          :id => self.id.first,
          :druid => URI(self.id.first).path.gsub(%r{^/}, ''),
          :file_id_s => self.file_id.first,
          :geo_bbox => to_solr_bbox,
          :geo_data_type_s => 'vector',
          :geo_format_s => self.format.first,
          :geo_geometry_type_s => 'Polygon',
          :geo_layername_s => File.basename(self.layername.first, '.shp'),
          :geo_ne_pt => Dor::GeoMetadataDS.to_wkt([bb.e, bb.n]),
          :geo_pt => to_solr_centroid,
          :geo_sw_pt => Dor::GeoMetadataDS.to_wkt([bb.w, bb.s]),
          :geo_proj => self.projection.first,
          :dc_coverage_t => to_dc_coverage,
          :dc_creator_t => self.originator.first,
          :dc_date_i => self.publish_dt.map {|i| i.to_s[0..3]},
          :dc_description_t => [self.abstract.first, self.purpose.first].join(";\n"),
          :dc_format_s => 'application/x-esri-shapefile',
          :dc_language_s => self.metadata_language.first,
          :dc_title_t => self.title.first,
          :text => [self.title.first, self.abstract.first, self.purpose.first].join(";\n")
        }.each do |id, v|
          ::Solrizer::Extractor.insert_solr_field_value(doc, id.to_s, v)
        end

        return doc
      rescue 
        solr_doc
      end
    end
  
    # @return [Struct] in minX minY maxX maxY order 
    #      with .w, .e, .n., .s for west, east, north, south as floats
    def to_bbox
      params = { 'xmlns:gmd' => NS[:gmd], 'xmlns:gco' => NS[:gco] }
      bb = metadata.xpath(
        '//gmd:EX_Extent/gmd:geographicElement' + 
        '/gmd:EX_GeographicBoundingBox', params).first
      Struct.new(:w, :e, :n, :s).new(
        bb.xpath('gmd:westBoundLongitude/gco:Decimal', params).text.to_f,
        bb.xpath('gmd:eastBoundLongitude/gco:Decimal', params).text.to_f,
        bb.xpath('gmd:northBoundLatitude/gco:Decimal', params).text.to_f,
        bb.xpath('gmd:southBoundLatitude/gco:Decimal', params).text.to_f
      )
    end
    
    # @return [Array<Numeric>] (x y) coordinates of center point - assumes #to_bbox
    # @see http://wiki.apache.org/solr/SolrAdaptersForLuceneSpatial4
    def to_centroid
      bb = to_bbox
      [ (bb.w + bb.e)/2, (bb.n + bb.s)/2 ]
    end
  
    # A lat-lon rectangle can be indexed with 4 numbers in minX minY maxX maxY order:
    # 
    #      <field name="geo">-74.093 41.042 -69.347 44.558</field> 
    #      <field name="geo">POLYGON((...))</field>
    #
    # @param [Symbol] either :solr3 or :solr4
    # @return [String] minX minY maxX maxY for :solr3 or POLYGON((...)) for :solr4
    # @see http://wiki.apache.org/solr/SolrAdaptersForLuceneSpatial4
    def to_solr_bbox format = :solr4
      bb = to_bbox
      
      case format
      when :solr3
        [bb.w, bb.s, bb.e, bb.n].join(' ')
      when :solr4
        Dor::GeoMetadataDS.to_wkt [bb.w, bb.s], [bb.e, bb.n]
      else
        raise ArgumentError, "Unsupported format #{format}"
      end
    end
    
    # @return [String] in Dublin Core Coverage format
    def to_dc_coverage
      bb = to_bbox
      "x.min=#{bb.w} x.max=#{bb.e} y.min=#{bb.s} y.max=#{bb.n}"
    end
  
    # A lat-lon point for the centroid of the bounding box:
    # 
    #     <field name="geo">69.4325,-78.085007</field> 
    #     <field name="geo">POINT(-78.085007 69.4325)</field>
    #
    # @param [Symbol] either :solr3 or :solr4
    # @return [String] minX minY maxX maxY for :solr3 or POLYGON((...)) for :solr4
    # @see http://wiki.apache.org/solr/SolrAdaptersForLuceneSpatial4
  
    # @return [String] (y,x) coordinates of center point matching the LatLonType Solr type
    # @see http://wiki.apache.org/solr/SolrAdaptersForLuceneSpatial4
    def to_solr_centroid format = :solr4
      x, y = to_centroid
      
      case format
      when :solr3
        [y,x].join(',') # for solr.LatLonType
      when :solr4
        Dor::GeoMetadataDS.to_wkt [x, y]
      else
        raise ArgumentError, "Unsupported format #{format}"
      end
    end
    
    private
    
    # @param [Array<Numeric>] (x,y) coordinates for point or bounding box
    # @return [String] WKT for point or rectangle
    def self.to_wkt xy, xy2 = nil
      if xy2
        w = [xy[0], xy2[0]].min
        e = [xy[0], xy2[0]].max
        s = [xy[1], xy2[1]].min
        n = [xy[1], xy2[1]].max
        "POLYGON((#{w} #{s}, #{w} #{n}, #{e} #{n}, #{e} #{s}, #{w} #{s}))"
      else
        "POINT(#{xy[0]} #{xy[1]})"
      end
    end
    
    # Convert to MARC 255 DD into DDMMSS
    # westernmost longitude, easternmost longitude, northernmost latitude, and southernmost latitude
    # e.g., -109.758319 -- -88.990844/48.999336 -- 29.423028
    def self.to_coordinates_ddmmss s
      w, e, n, s = s.scanf('%f -- %f/%f -- %f')
      raise ArgumentError, "Out of bounds latitude: #{n} #{s}" unless n >= -90 and n <= 90 and s >= -90 and s <= 90
      raise ArgumentError, "Out of bounds longitude: #{w} #{e}" unless w >= -180 and w <= 180 and e >= -180 and e <= 180
      w = "#{w < 0 ? 'W' : 'E'} #{Dor::GeoMetadataDS::dd2ddmmss_abs w}"
      e = "#{e < 0 ? 'W' : 'E'} #{Dor::GeoMetadataDS::dd2ddmmss_abs e}"
      n = "#{n < 0 ? 'S' : 'N'} #{Dor::GeoMetadataDS::dd2ddmmss_abs n}"
      s = "#{s < 0 ? 'S' : 'N'} #{Dor::GeoMetadataDS::dd2ddmmss_abs s}"
      "#{w}--#{e}/#{n}--#{s}"
    end
    
    # Convert DD.DD to DD MM SS.SS
    # e.g., 
    # * -109.758319 => 109°45ʹ29.9484ʺ
    # * 48.999336 => 48°59ʹ57.609ʺ
    E = 1
    QSEC = 'ʺ'
    QMIN = 'ʹ'
    QDEG = "\u00B0"
    def self.dd2ddmmss_abs f
      dd = f.to_f.abs
      d = dd.floor
      mm = ((dd - d) * 60)
      m = mm.floor
      s = ((mm - mm.floor) * 60).round
      m, s = m+1, 0 if s >= 60
      d, m = d+1, 0 if m >= 60
      "#{d}#{QDEG}" + (m>0 ? "#{m}#{QMIN}" : '') + (s>0 ? "#{s}#{QSEC}" : '')
    end
  end
end
