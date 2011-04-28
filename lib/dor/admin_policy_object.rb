require 'active_fedora'
require 'datastreams/identity_metadata_ds'
require 'datastreams/simple_dublin_core_ds'

module Dor
  
  class AdminPolicyObject < Base
    
    has_metadata :name => "administrativeMetadata", :type => ActiveFedora::NokogiriDatastream
    has_metadata :name => "roleMetadata", :type => ActiveFedora::NokogiriDatastream
    has_metadata :name => "defaultObjectRights", :type => ActiveFedora::NokogiriDatastream
    
  end
  
end