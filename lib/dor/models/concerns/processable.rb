# frozen_string_literal: true

require 'equivalent-xml'

module Dor
  module Processable
    extend ActiveSupport::Concern

    included do
      has_metadata :name => 'workflows', :type => Dor::WorkflowDs, :label => 'Workflows', :control_group => 'E'
      after_initialize :set_workflows_datastream_location
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

    # This is a work-around for some strange logic in ActiveFedora that
    # don't allow self.workflows.new? to work if we load the object using
    # .load_instance_from_solr.
    def set_workflows_datastream_location
      return if self.respond_to?(:inner_object) && inner_object.is_a?(ActiveFedora::SolrDigitalObject)
      return unless workflows.new?

      workflows.mimeType   = 'application/xml'
      workflows.dsLocation = File.join(Dor::Config.workflow.url, "dor/objects/#{pid}/workflows")
    end

    def empty_datastream?(datastream)
      return true if datastream.new?

      if datastream.class.respond_to?(:xml_template)
        datastream.content.to_s.empty? || EquivalentXml.equivalent?(datastream.content, datastream.class.xml_template)
      else
        datastream.content.to_s.empty?
      end
    end

    # Tries to find a file for the datastream.
    # @param [String] datastream name of a datastream
    # @return [String, nil] path to datastream or nil
    def find_metadata_file(datastream)
      druid = DruidTools::Druid.new(pid, Dor::Config.stacks.local_workspace_root)
      druid.find_metadata("#{datastream}.xml")
    end

    # Builds that datastream using the content of a file if such a file
    # exists and is newer than the object's current datastream; otherwise,
    # builds the datastream by calling build_fooMetadata_datastream.
    # @param [String] datastream name of a datastream (e.g. "fooMetadata")
    # @param [Boolean] force overwrite existing datastream
    # @param [Boolean] is_required
    # @return [SomeDatastream]
    def build_datastream(datastream, force = false, is_required = false)
      # See if datastream exists as a file and if the file's timestamp is newer than datastream's timestamp.
      ds       = datastreams[datastream]
      filename = find_metadata_file(datastream)
      use_file = filename && (ds.createDate.nil? || File.mtime(filename) >= ds.createDate)
      # Build datastream.
      if use_file
        content = File.read(filename)
        ds.content = content
        ds.ng_xml = Nokogiri::XML(content) if ds.respond_to?(:ng_xml)
        ds.save unless ds.digital_object.new?
      elsif force || empty_datastream?(ds)
        meth = "build_#{datastream}_datastream".to_sym
        if respond_to?(meth)
          send(meth, ds)
          ds.save unless ds.digital_object.new?
        end
      end
      # Check for success.
      raise "Required datastream #{datastream} could not be populated!" if is_required && empty_datastream?(ds)

      ds
    end

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
      rescue
      end

      current_milestones = []
      # only get steps that are part of accessioning and part of the current version. That can mean they were archived with the current version
      # number, or they might be active (no version number).
      milestones.each do |m|
        if STEPS.keys.include?(m[:milestone]) && (m[:version].nil? || m[:version] == current_version)
          current_milestones << m unless m[:milestone] == 'registered' && current_version.to_i > 1
        end
      end

      status_code = 0
      status_time = nil
      # for each milestone in the current version, see if it comes after the current 'last' step, if so, make it the last and record the date/time
      current_milestones.each do |m|
        m_name = m[:milestone]
        m_time = m[:at].utc.xmlschema
        next unless STEPS.keys.include?(m_name) && (!status_time || m_time > status_time)

        status_code = STEPS[m_name]
        status_time = m_time
      end

      { :current_version => current_version, :status_code => status_code, :status_time => status_time }
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
      priority = workflows.current_priority if priority == 0
      opts = { :create_ds => create_ds, :lane_id => default_workflow_lane }
      opts[:priority] = priority if priority > 0
      Dor::Config.workflow.client.create_workflow(Dor::WorkflowObject.initial_repo(name), pid, name, Dor::WorkflowObject.initial_workflow(name), opts)
      workflows.content(true) # refresh the copy of the workflows datastream
    end

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
    rescue
      d = datetime.is_a?(Time) ? datetime : Time.parse(datetime.to_s)
      d.strftime('%Y-%m-%d %I:%M%p')
    end
  end
end
