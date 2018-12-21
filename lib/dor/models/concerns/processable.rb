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

    # verbiage we want to use to describe an item when it has completed a particular step
    STATUS_CODE_DISP_TXT = {
      0 => 'Unknown Status', # if there are no milestones for the current version, someone likely messed up the versioning process.
      1 => 'Registered',
      2 => 'In accessioning',
      3 => 'In accessioning (described)',
      4 => 'In accessioning (described, published)',
      5 => 'In accessioning (described, published, deposited)',
      6 => 'Accessioned',
      7 => 'Accessioned (indexed)',
      8 => 'Accessioned (indexed, ingested)',
      9 => 'Opened'
    }.freeze

    # milestones from accessioning and the order they happen in
    STEPS = {
      'registered' => 1,
      'submitted' => 2,
      'described' => 3,
      'published' => 4,
      'deposited' => 5,
      'accessioned' => 6,
      'indexed' => 7,
      'shelved' => 8,
      'opened' => 9
    }.freeze

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

    def milestones
      @milestones ||= Dor::Config.workflow.client.get_milestones('dor', pid)
    end

    # @return [Hash{Symbol => Object}] including :current_version, :status_code and :status_time
    def status_info
      current_version = '1'
      begin
        current_version = versionMetadata.current_version_id
      rescue StandardError
      end

      current_milestones = []
      # only get steps that are part of accessioning and part of the current version. That can mean they were archived with the current version
      # number, or they might be active (no version number).
      milestones.each do |m|
        if STEPS.key?(m[:milestone]) && (m[:version].nil? || m[:version] == current_version)
          current_milestones << m unless m[:milestone] == 'registered' && current_version.to_i > 1
        end
      end

      status_code = 0
      status_time = nil
      # for each milestone in the current version, see if it comes after the current 'last' step, if so, make it the last and record the date/time
      current_milestones.each do |m|
        m_name = m[:milestone]
        m_time = m[:at].utc.xmlschema
        next unless STEPS.key?(m_name) && (!status_time || m_time > status_time)

        status_code = STEPS[m_name]
        status_time = m_time
      end

      { current_version: current_version, status_code: status_code, status_time: status_time }
    end

    # @param [Boolean] include_time
    # @return [String] single composed status from status_info
    def status(include_time = false)
      status_info_hash = status_info
      current_version = status_info_hash[:current_version]
      status_code = status_info_hash[:status_code]
      status_time = status_info_hash[:status_time]

      # use the translation table to get the appropriate verbage for the latest step
      result = "v#{current_version} #{STATUS_CODE_DISP_TXT[status_code]}"
      result += " #{format_date(status_time)}" if include_time
      result
    end

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

    private

    # handles formating utc date/time to human readable
    # XXX: bad form to hardcode TZ here.  Code smell abounds.
    def format_date(datetime)
      d =
        if datetime.is_a?(Time)
          datetime
        else
          DateTime.parse(datetime).in_time_zone(ActiveSupport::TimeZone.new('Pacific Time (US & Canada)'))
        end
      I18n.l(d).strftime('%Y-%m-%d %I:%M%p')
    rescue StandardError
      d = datetime.is_a?(Time) ? datetime : Time.parse(datetime.to_s)
      d.strftime('%Y-%m-%d %I:%M%p')
    end
  end
end
