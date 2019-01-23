# frozen_string_literal: true

module Dor
  class CreateWorkflowService
    # Initilizes workflow for the object in the workflow service
    #  It will set the priorty of the new workflow to the current_priority if it is > 0
    #  It will set lane_id from the item's APO default workflow lane
    # @param [String] name of the workflow to be initialized
    # @param [Boolean] create_ds create a 'workflows' datastream in Fedora for the object
    # @param [Integer] priority the workflow's priority level
    def self.create_workflow(item, name:, create_ds: true, priority: 0)
      new(item).create_workflow(name: name, create_ds: create_ds, priority: priority)
    end

    def initialize(item)
      @item = item
    end

    def create_workflow(name:, create_ds: true, priority: 0)
      priority = item.workflows.current_priority if priority == 0
      opts = { create_ds: create_ds, lane_id: default_workflow_lane }
      opts[:priority] = priority if priority > 0
      Dor::Config.workflow.client.create_workflow(Dor::WorkflowObject.initial_repo(name),
                                                  item.pid,
                                                  name,
                                                  Dor::WorkflowObject.initial_workflow(name),
                                                  opts)
      item.workflows.content(true) # refresh the copy of the workflows datastream
    end

    private

    attr_reader :item
    delegate :admin_policy_object, to: :item

    # Returns the default lane_id from the item's APO.  Will return 'default' if the item does not have
    #   and APO, or if the APO does not have a default_lane
    # @return [String] the lane id
    def default_workflow_lane
      return 'default' if admin_policy_object.nil? # TODO: log warning?

      admin_md = admin_policy_object.datastreams['administrativeMetadata']
      return 'default' unless admin_md.respond_to?(:default_workflow_lane) # Some APOs don't have this datastream

      lane = admin_md.default_workflow_lane
      return lane unless lane.blank?

      'default'
    end
  end
end
