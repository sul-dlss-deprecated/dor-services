module Dor
  
  class AdminPolicyObject < Base
    
    has_metadata :name => "administrativeMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Administrative Metadata'
    has_metadata :name => "roleMetadata", :type => ActiveFedora::NokogiriDatastream, :label => 'Role Metadata'
    has_metadata :name => "defaultObjectRights", :type => ActiveFedora::NokogiriDatastream, :label => 'Default Object Rights'
    
  end
  Base.register_type('adminpolicy', AdminPolicyObject)
  
end