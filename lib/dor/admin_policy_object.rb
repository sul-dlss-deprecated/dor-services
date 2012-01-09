module Dor
  class AdminPolicyObject < ::ActiveFedora::Base
    include Identifiable
    include Governable
    
    has_many :items, :property => :is_governed_by
    
    has_metadata :name => "administrativeMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Administrative Metadata'
    has_metadata :name => "roleMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Role Metadata'
    has_metadata :name => "defaultObjectRights", :type => ActiveFedora::NokogiriDatastream, :label => 'Default Object Rights'
    
  end
end