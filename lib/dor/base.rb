require 'active_fedora'
require 'datastreams/identity_metadata_ds'
require 'datastreams/simple_dublin_core_ds'
require 'datastreams/workflow_ds'
require 'dor/suri_service'

module Dor

  class Base < ::ActiveFedora::Base
    
    attr_reader :workflows
    @@item_types = {}
    
    has_metadata :name => "DC", :type => SimpleDublinCoreDs, :label => 'Dublin Core Record for this object'
    has_metadata :name => "RELS-EXT", :type => ActiveFedora::RelsExtDatastream, :label => 'RDF Statements about this object'
    has_metadata :name => "identityMetadata", :type => IdentityMetadataDS, :label => 'Identity Metadata'

    class << self
      def load(pid, as=nil)
        if as.nil?
          return Dor::Base.load_instance(pid)
        end
      
        if as.is_a?(String)
          as = self.type_for(as)
        end
        as.load_instance(pid)
      end
    
      def type_for(item_type)
        @@item_types[item_type] || Dor::Base
      end
    
      def register_type(item_type, klass)
        @@item_types[item_type] = klass
      end
    
      # Make an idempotent API-M call to get gsearch to reindex the object
      def touch(*pids)
        client = Dor::Config.fedora.client
        pids.collect { |pid|
          response = begin
            client["objects/#{pid}?state=A"].put('', :content_type => 'text/xml')
          rescue RestClient::ResourceNotFound
            doc = Nokogiri::XML("<update><delete><id>#{pid}</id></delete></update>")
            Dor::Config.gsearch.client['update'].post(doc.to_xml, :content_type => 'application/xml')
          end
          response.code
        }
      end
    end
    
    def initialize(attrs = {})
      unless attrs[:pid]
        attrs = attrs.merge!({:pid=>Dor::SuriService.mint_id})  
        @new_object=true
      else
        @new_object = attrs[:new_object] == false ? false : true
      end
      @inner_object = Fedora::FedoraObject.new(attrs)
      @datastreams = {}
      @workflows = {}
      configure_defined_datastreams
    end  

    def content(dsid, raw=false)
      ds = nil
      data = nil
      if self.datastreams_in_fedora.keys.include?(dsid)
        ds = self.datastreams[dsid]
        data = ds.content
        if ds.attributes['mimeType'] =~ /xml$/ and not raw
          begin
            doc = Nokogiri::XML(data)
            xslt = Nokogiri::XSLT(File.read(File.expand_path('../identity.xsl', __FILE__)))
            data = xslt.transform(doc).to_xml
          rescue
            # Leave the data the way it is if it can't be transformed
          end
        end
      end
      return data
    end

    def identity_metadata
      if self.datastreams.has_key?('identityMetadata')
        IdentityMetadata.from_xml(self.datastreams['identityMetadata'].content)
      else
        nil
      end
    end
    
    # Self-aware datastream builders
    def build_datastream(datastream, force = false)
      ds = datastreams[datastream]
      if force or ds.new_object? or (ds.content.to_s.empty?)
        proc = "build_#{datastream}_datastream".to_sym
        content = self.send(proc, ds)
        ds.save
      end
      return ds
    end
    
    def reindex
      Dor::SearchService.reindex(self.pid)
    end

  end
end