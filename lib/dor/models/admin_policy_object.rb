module Dor
  class AdminPolicyObject < ::ActiveFedora::Base
    include Identifiable
    include Governable
    include Editable
    include Describable
    include Processable
    include Versionable

    has_many :things, :property => :is_governed_by, :inbound => :true, :class_name => "ActiveFedora::Base"
    has_object_type 'adminPolicy'
    has_metadata :name => "administrativeMetadata", :type => Dor::AdministrativeMetadataDS, :label => 'Administrative Metadata'
    has_metadata :name => "roleMetadata", :type => Dor::RoleMetadataDS, :label => 'Role Metadata'
    has_metadata :name => "defaultObjectRights", :type => Dor::DefaultObjectRightsDS, :label => 'Default Object Rights'
  end
end
