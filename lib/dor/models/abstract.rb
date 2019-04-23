# frozen_string_literal: true

module Dor
  class Abstract < ::ActiveFedora::Base
    include Identifiable
    include Governable
    include Describable

    has_metadata name: 'provenanceMetadata',
                 type: ProvenanceMetadataDS,
                 label: 'Provenance Metadata'
    has_metadata name: 'workflows',
                 type: WorkflowDs,
                 label: 'Workflows',
                 control_group: 'E',
                 autocreate: true
    has_metadata name: 'rightsMetadata',
                 type: RightsMetadataDS,
                 label: 'Rights metadata'
    has_metadata name: 'events',
                 type: EventsDS,
                 label: 'Events'
    has_metadata name: 'versionMetadata',
                 type: VersionMetadataDS,
                 label: 'Version Metadata',
                 autocreate: true
    has_metadata name: 'DC',
                 type: SimpleDublinCoreDs,
                 label: 'Dublin Core Record for self object'
    has_metadata name: 'identityMetadata',
                 type: Dor::IdentityMetadataDS,
                 label: 'Identity Metadata'

    class_attribute :resource_indexer
    class_attribute :object_type

    def self.has_object_type(str)
      self.object_type = str
      Dor.registered_classes[str] = self
    end

    # Overrides the method in ActiveFedora to mint a pid using SURI rather
    # than the default Fedora sequence
    def self.assign_pid(_obj)
      return Dor::SuriService.mint_id if Dor::Config.suri.mint_ids

      super
    end

    # Overrides the method in ActiveFedora
    def to_solr
      resource_indexer.new(resource: self).to_solr
    end

    # Override ActiveFedora::Core#adapt_to_cmodel (used with associations, among other places) to
    # preferentially use the objectType asserted in the identityMetadata.
    def adapt_to_cmodel
      object_type = identityMetadata.objectType.first
      object_class = Dor.registered_classes[object_type]

      if object_class
        instance_of?(object_class) ? self : adapt_to(object_class)
      else
        begin
          super
        rescue ActiveFedora::ModelNotAsserted
          adapt_to(Dor::Item)
        end
      end
    end

    # a regex that can be used to identify the last part of a druid (e.g. oo000oo0001)
    # @return [Regex] a regular expression to identify the ID part of the druid
    def pid_regex
      /[a-zA-Z]{2}[0-9]{3}[a-zA-Z]{2}[0-9]{4}/
    end

    # a regex that can be used to identify a full druid with prefix (e.g. druid:oo000oo0001)
    # @return [Regex] a regular expression to identify a full druid
    def druid_regex
      /druid:#{pid_regex}/
    end

    # Since purl does not use the druid: prefix but much of dor does, use this function to strip the druid: if needed
    # @return [String] the druid sans the druid: or if there was no druid: prefix, the entire string you passed
    def remove_druid_prefix(druid = id)
      result = druid.match(/#{pid_regex}/)
      result.nil? ? druid : result[0] # if no matches, return the string passed in, otherwise return the match
    end

    # This is used by Argo and the MergeService
    # @return [Boolean] true if the object is in a state that allows it to be modified.
    #  States that will allow modification are: has not been submitted for accessioning, has an open version or has sdr-ingest set to hold
    # @todo this could be a workflow service endpoint
    def allows_modification?
      client = Dor::Config.workflow.client
      !client.lifecycle('dor', pid, 'submitted') ||
        client.active_lifecycle('dor', pid, 'opened') ||
        client.workflow_status('dor', pid, 'accessionWF', 'sdr-ingest-transfer') == 'hold'
    end

    def current_version
      versionMetadata.current_version_id
    end

    delegate :rights, to: :rightsMetadata
  end
end
