# frozen_string_literal: true

require 'equivalent-xml'

module Dor
  module Processable
    extend ActiveSupport::Concern
    extend Deprecation
    self.deprecation_horizon = 'dor-services version 7.0.0'

    included do
      has_metadata name: 'workflows',
                   type: Dor::WorkflowDs,
                   label: 'Workflows',
                   control_group: 'E',
                   autocreate: true
    end

    # The ContentMetadata and DescMetadata robot are allowed to build the
    # datastream by reading a file from the /dor/workspace that matches the
    # datastream name. This allows assembly or pre-assembly to prebuild the
    # datastreams from templates or using other means
    # (like the assembly-objectfile gem) and then have those datastreams picked
    # up and added to the object during accessionWF.
    #
    # This method builds that datastream using the content of a file if such a file
    # exists and is newer than the object's current datastream (see above); otherwise,
    # builds the datastream by calling build_fooMetadata_datastream.
    # @param [String] datastream name of a datastream (e.g. "fooMetadata")
    # @param [Boolean] force overwrite existing datastream
    # @param [Boolean] is_required
    # @return [ActiveFedora::Datastream]
    def build_datastream(datastream, force = false, is_required = false)
      ds = datastreams[datastream]
      builder = Dor::DatastreamBuilder.new(object: self,
                                           datastream: ds,
                                           force: force,
                                           required: is_required)
      builder.build

      ds
    end
    deprecation_deprecate build_datastream: 'Use Dor::DatastreamBuilder instead'

    def cleanup
      CleanupService.cleanup(self)
    end

    # @return [Hash{Symbol => Object}] including :current_version, :status_code and :status_time
    def status_info
      StatusService.status_info(self)
    end
    deprecation_deprecate status_info: 'Use StatusService.status_info instead'

    # @param [Boolean] include_time
    # @return [String] single composed status from status_info
    def status(include_time = false)
      StatusService.status(self, include_time)
    end
    deprecation_deprecate status: 'Use StatusService.status instead'

    def milestones
      StatusService.new(self).milestones
    end
    deprecation_deprecate status_info: 'Use StatusService#milestones instead'

    # Initilizes workflow for the object in the workflow service
    #  It will set the priorty of the new workflow to the current_priority if it is > 0
    #  It will set lane_id from the item's APO default workflow lane
    # @param [String] name of the workflow to be initialized
    # @param [Boolean] create_ds create a 'workflows' datastream in Fedora for the object
    # @param [Integer] priority the workflow's priority level
    def create_workflow(name, create_ds = true, priority = 0)
      CreateWorkflowService.create_workflow(self, name: name, create_ds: create_ds, priority: priority)
    end
    deprecation_deprecate create_workflow: 'Use CreateWorkflowService.create_workflow'

    def initialize_workflow(name, create_ds = true, priority = 0)
      warn 'WARNING: initialize_workflow is deprecated, use create_workflow instead'
      create_workflow(name, create_ds, priority)
    end
  end
end
