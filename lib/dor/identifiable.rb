module Dor
  module Identifiable
    extend ActiveSupport::Concern
    
    included do
      has_metadata :name => "identityMetadata", :type => IdentityMetadataDS, :label => 'Identity Metadata'
    end

    def identity_metadata
      if self.datastreams.has_key?('identityMetadata')
        IdentityMetadata.from_xml(self.datastreams['identityMetadata'].content)
      else
        nil
      end
    end
    
  end
end