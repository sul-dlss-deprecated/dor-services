module Dor
  class AdminPolicyObject < ::ActiveFedora::Base
    include Identifiable
    include Governable
    
    has_many :items, :property => :is_governed_by
    
    has_metadata :name => "administrativeMetadata", :type => AdministrativeMetadataDS, :label => 'Administrative Metadata'
    has_metadata :name => "roleMetadata", :type => RoleMetadataDS, :label => 'Role Metadata'
    has_metadata :name => "defaultObjectRights", :type => ActiveFedora::NokogiriDatastream, :label => 'Default Object Rights'
    
  end
end