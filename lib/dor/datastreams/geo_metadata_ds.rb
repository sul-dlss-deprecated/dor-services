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

    # namespaces
    NS = {
      :rdf => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#',
      :gco => 'http://www.isotc211.org/2005/gco',
      :gmd => 'http://www.isotc211.org/2005/gmd',
      :gfc => 'http://www.isotc211.org/2005/gfc'
    }.freeze

    # hash with all namespaces
    XMLNS = Hash[NS.map {|k, v| ["xmlns:#{k}", v]}]

    # schema locations
    NS_XSD = NS.keys.collect {|k| "#{NS[k]} #{NS[k]}/#{k}.xsd"}

    # @return [Nokogiri::XML::Document] with gmd:MD_Metadata as root node
    # @raise [Dor::ParameterError] if MD_Metadata is missing
    def metadata
      root = ng_xml.xpath('/rdf:RDF/rdf:Description/gmd:MD_Metadata', XMLNS)
      if root.nil? || root.empty?
        raise Dor::ParameterError, "Invalid geoMetadata -- missing MD_Metadata: #{root}"
      else
        Nokogiri::XML(root.first.to_xml)
      end
    end

    # @return [Nokogiri::XML::Document] with gfc:FC_FeatureCatalogue as root node,
    #     or nil if not provided
    def feature_catalogue
      root = ng_xml.xpath('/rdf:RDF/rdf:Description/gfc:FC_FeatureCatalogue', XMLNS)
      return nil if root.nil? || root.empty?  # Feature catalog is optional
      Nokogiri::XML(root.first.to_xml)
    end

    # @return [Nokogiri::XML::Document] Contains skeleton geoMetadata XML
    #    Add your druid as the suffix to rdf:about attributes.
    #    Includes all possible xmlns for gmd and gfc
    def self.xml_template
      Nokogiri::XML::Builder.new do |xml|
        xml['rdf'].RDF XMLNS,
          'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
          'xsi:schemaLocation' => NS_XSD.join(' ') do
          xml['rdf'].Description 'rdf:about' => nil do
            xml['gmd'].MD_Metadata
          end
          xml['rdf'].Description 'rdf:about' => nil do
            xml['gfc'].FC_FeatureCatalogue
          end
        end
      end.doc
    end

    # @return [Struct] in minX minY maxX maxY order
    #      with .w, .e, .n., .s for west, east, north, south as floats
    def to_bbox
      params = { 'xmlns:gmd' => NS[:gmd], 'xmlns:gco' => NS[:gco] }
      bb = metadata.xpath('//gmd:EX_Extent/gmd:geographicElement/gmd:EX_GeographicBoundingBox', params).first
      Struct.new(:w, :e, :n, :s).new(
        bb.xpath('gmd:westBoundLongitude/gco:Decimal', params).text.to_f,
        bb.xpath('gmd:eastBoundLongitude/gco:Decimal', params).text.to_f,
        bb.xpath('gmd:northBoundLatitude/gco:Decimal', params).text.to_f,
        bb.xpath('gmd:southBoundLatitude/gco:Decimal', params).text.to_f
      )
    end
  end
end
