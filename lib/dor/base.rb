require 'active_fedora'
require 'datastreams/identity_metadata_ds'
require 'datastreams/simple_dublin_core_ds'
require 'datastreams/workflow_ds'
require 'dor/suri_service'

module Dor

  class Base < ::ActiveFedora::Base
    
    attr_reader :workflows

    has_metadata :name => "DC", :type => SimpleDublinCoreDs
    has_metadata :name => "RELS-EXT", :type => ActiveFedora::NokogiriDatastream
    has_metadata :name => "identityMetadata", :type => IdentityMetadataDS
    has_metadata :name => "technicalMetadata", :type => ActiveFedora::NokogiriDatastream

    # Make a random (and harmless) API-M call to get gsearch to reindex the object
    def self.touch(pid)
      client = RestClient::Resource.new(
        Dor::Config.fedora.url,
        :ssl_client_cert  =>  OpenSSL::X509::Certificate.new(File.read(Dor::Config.fedora.cert_file)),
        :ssl_client_key   =>  OpenSSL::PKey::RSA.new(File.read(Dor::Config.fedora.key_file), Dor::Config.fedora.key_pass)
      )
      response = client["objects/#{pid}/datastreams/DC?dsState=A&ignoreContent=true"].put('', :content_type => 'text/xml')
      response.code
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
      # Touch the DC datastream to force gsearch to reindex
      datastreams['DC'].save
    end

  end
end