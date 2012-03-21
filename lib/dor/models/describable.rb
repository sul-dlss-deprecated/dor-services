module Dor
  module Describable
    extend ActiveSupport::Concern

    DESC_MD_FORMATS = {
      "http://www.tei-c.org/ns/1.0" => 'tei',
      "http://www.loc.gov/mods/v3" =>  'mods'
    }
    class CrosswalkError < Exception; end
    
    included do
      has_metadata :name => "descMetadata", :type => Dor::DescMetadataDS, :label => 'Descriptive Metadata', :control_group => 'M'
    end

    def fetch_descMetadata_datastream
      candidates = self.datastreams['identityMetadata'].otherId.collect { |oid| oid.to_s }
      metadata_id = Dor::MetadataService.resolvable(candidates).first
      unless metadata_id.nil?
        return Dor::MetadataService.fetch(metadata_id.to_s)
      else
        return nil
      end
    end

    def build_descMetadata_datastream(ds)
      content = fetch_descMetadata_datastream
      unless content.nil?
        ds.dsLabel = 'Descriptive Metadata'
        ds.ng_xml = Nokogiri::XML(content)
        ds.ng_xml.normalize_text!
        ds.content = ds.ng_xml.to_xml
      end
    end
    
    # Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
    #   Should not be used for the Fedora DC datastream
    # @raise [Exception] Raises an Exception if the generated DC is empty or has no children
    def generate_dublin_core
      format = self.metadata_format
      if format.nil?
        raise CrosswalkError, "Unknown descMetadata namespace: #{metadata_namespace.inspect}"
      end
      xslt = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__) + "/#{format}2dc.xslt")) )
      dc_doc = xslt.transform(self.datastreams['descMetadata'].ng_xml)
      # Remove empty nodes
      dc_doc.xpath('/oai_dc:dc/*[count(text()) = 0]').remove
      if(dc_doc.root.nil? || dc_doc.root.children.size == 0)
        raise "Dor::Item#generate_dublin_core produced incorrect xml:\n#{dc_doc.to_xml}"
      end
      dc_doc
    end
   
    def metadata_namespace
      desc_md = self.datastreams['descMetadata'].ng_xml
      if desc_md.nil? or desc_md.root.nil? or desc_md.root.namespace.nil?
        return nil 
      else
        return desc_md.root.namespace.href
      end
    end
    
    def metadata_format
      DESC_MD_FORMATS[metadata_namespace]
    end
    
    def to_solr(solr_doc=Hash.new, *args)
      super solr_doc, *args
      add_solr_value(solr_doc, "metadata_format", self.metadata_format, :string, [:searchable, :facetable])
      begin
        dc_doc = self.generate_dublin_core
        dc_doc.xpath('/oai_dc:dc/*').each do |node|
          add_solr_value(solr_doc, "public_dc_#{node.name}", node.text, :string, [:searchable])
        end
      rescue CrosswalkError => e
        ActiveFedora.logger.warn "Cannot index #{self.pid}.descMetadata: #{e.message}"
      end
      solr_doc
    end
    
  end
end