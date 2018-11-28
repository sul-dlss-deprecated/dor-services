module Dor
  class AdminPolicyObject < Dor::Abstract
    include Editable

    has_many :things, :property => :is_governed_by, :class_name => 'ActiveFedora::Base'
    has_object_type 'adminPolicy'
    has_metadata :name => 'administrativeMetadata', :type => Dor::AdministrativeMetadataDS, :label => 'Administrative Metadata'
    has_metadata :name => 'roleMetadata',           :type => Dor::RoleMetadataDS,           :label => 'Role Metadata'
    has_metadata :name => 'defaultObjectRights',    :type => Dor::DefaultObjectRightsDS,    :label => 'Default Object Rights'

    self.resource_indexer = CompositeIndexer.new(
      DataIndexer,
      DescribableIndexer,
      EditableIndexer,
      IdentifiableIndexer,
      ProcessableIndexer
    )
  end
end
