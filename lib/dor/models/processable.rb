require 'equivalent-xml'

module Dor
  module Processable
    extend ActiveSupport::Concern
    include SolrDocHelper
    include Upgradable

    included do
      has_metadata :name => 'workflows', :type => Dor::WorkflowDs, :label => 'Workflows', :control_group => 'E'
      after_initialize :set_workflows_datastream_location
    end

    #verbiage we want to use to describe an item when it has completed a particular step
    STATUS_CODE_DISP_TXT = {
      0 => 'Unknown Status', #if there are no milestones for the current version, someone likely messed up the versioning process.
      1 => 'Registered',
      2 => 'In accessioning',
      3 => 'In accessioning (described)',
      4 => 'In accessioning (described, published)',
      5 => 'In accessioning (described, published, deposited)',
      6 => 'Accessioned',
      7 => 'Accessioned (indexed)',
      8 => 'Accessioned (indexed, ingested)',
      9 => 'Opened'
    }

    #milestones from accessioning and the order they happen in
    STEPS = {
      'registered' => 1,
      'submitted' => 2,
      'described' => 3,
      'published' => 4,
      'deposited' => 5,
      'accessioned' => 6,
      'indexed' => 7,
      'shelved' => 8,
      'opened' => 1
    }

    def set_workflows_datastream_location
      # This is a work-around for some strange logic in ActiveFedora that
      # don't allow self.workflows.new? to work if we load the object using
      # .load_instance_from_solr.
      return if self.respond_to? :inner_object and self.inner_object.is_a? ActiveFedora::SolrDigitalObject

      if self.workflows.new?
        workflows.mimeType = 'application/xml'
        workflows.dsLocation = File.join(Dor::Config.workflow.url,"dor/objects/#{self.pid}/workflows")
      end
    end

    def empty_datastream?(datastream)
      if datastream.new?
        true
      elsif datastream.class.respond_to?(:xml_template)
        datastream.content.to_s.empty? or EquivalentXml.equivalent?(datastream.content, datastream.class.xml_template)
      else
        datastream.content.to_s.empty?
      end
    end

    # Takes the name of a datastream, as a string.
    # Tries to find a file for the datastream.
    # Returns the path to it or nil.
    def find_metadata_file(datastream)
      druid = DruidTools::Druid.new(pid, Dor::Config.stacks.local_workspace_root)
      return druid.find_metadata("#{datastream}.xml")
    end

    # Takes the name of a datastream, as a string (fooMetadata).
    # Builds that datastream using the content of a file if such a file
    # exists and is newer than the object's current datastream; otherwise,
    # builds the datastream by calling build_fooMetadata_datastream.
    def build_datastream(datastream, force = false, is_required = false)
      # See if the datastream exists as a file and if the file's
      # timestamp is newer than the datastream's timestamp.
      ds       = datastreams[datastream]
      filename = find_metadata_file(datastream)
      use_file = filename && (ds.createDate.nil? || File.mtime(filename) >= ds.createDate)
      # Build datastream.
      if use_file
        content = File.read(filename)
        ds.content = content
        ds.ng_xml = Nokogiri::XML(content) if ds.respond_to?(:ng_xml)
        ds.save unless ds.digital_object.new?
      elsif force or empty_datastream?(ds)
        meth = "build_#{datastream}_datastream".to_sym
        if respond_to?(meth)
          content = self.send(meth, ds)
          ds.save unless ds.digital_object.new?
        end
      end
      # Check for success.
      if is_required && empty_datastream?(ds)
        raise "Required datastream #{datastream} could not be populated!"
      end
      return ds
    end

    def cleanup()
      CleanupService.cleanup(self)
    end

    def milestones
      Dor::WorkflowService.get_milestones('dor',self.pid)
    end

    def status_info()
      current_version = '1'
      begin
        current_version = self.versionMetadata.current_version_id
      rescue
      end

      current_milestones = []
      #only get steps that are part of accessioning and part of the current version. That can mean they were archived with the current version
      #number, or they might be active (no version number).
      milestones.each do |m|
        if STEPS.keys.include?(m[:milestone]) and (m[:version].nil? or m[:version] == current_version)
          current_milestones << m unless m[:milestone] == 'registered' and current_version.to_i > 1
        end
      end

      status_code = 0
      status_time = ''
      #for each milestone in the current version, see if it comes after the current 'last' step, if so, make it the last and record the date/time
      current_milestones.each do |m|
        name = m[:milestone]
        time = m[:at].utc.xmlschema
        if STEPS.keys.include? name
          if STEPS[name] > status_code
            status_code = STEPS[name]
            status_time = time
          end
        end
      end

      return {:current_version => current_version, :status_code => status_code, :status_time => status_time}
    end

    def status(include_time=false)
      status_info_hash = status_info
      current_version, status_code, status_time = status_info_hash[:current_version], status_info_hash[:status_code], status_info_hash[:status_time]

      #use the translation table to get the appropriate verbage for the latest step
      result = "v#{current_version} #{STATUS_CODE_DISP_TXT[status_code]}"
      result += " #{format_date(status_time)}" if include_time
      return result
    end

    def to_solr(solr_doc=Hash.new, *args)
      super(solr_doc, *args)
      sortable_milestones = {}
      current_version='1'
      begin
        current_version = self.versionMetadata.current_version_id
      rescue
      end
      current_version_num=current_version.to_i

      if self.respond_to?('versionMetadata')
        #add an entry with version id, tag and description for each version
        while current_version_num > 0
          add_solr_value(solr_doc, 'versions', current_version_num.to_s + ';' + self.versionMetadata.tag_for_version(current_version_num.to_s) + ';' + self.versionMetadata.description_for_version(current_version_num.to_s), :string, [:displayable])
          current_version_num -= 1
        end
      end

      self.milestones.each do |milestone|
        timestamp = milestone[:at].utc.xmlschema
        sortable_milestones[milestone[:milestone]] ||= []
        sortable_milestones[milestone[:milestone]] << timestamp
        add_solr_value(solr_doc, 'lifecycle', milestone[:milestone], :string, [:searchable, :facetable])
        unless milestone[:version]
          milestone[:version]=current_version
        end
        add_solr_value(solr_doc, 'lifecycle', "#{milestone[:milestone]}:#{timestamp};#{milestone[:version]}", :string, [:displayable])
      end

      sortable_milestones.each do |milestone, unordered_dates|
        dates = unordered_dates.sort
        #create the published_dt and published_day fields and the like
        add_solr_value(solr_doc, milestone+'_day', DateTime.parse(dates.last).beginning_of_day.utc.xmlschema.split('T').first, :string, [:searchable, :facetable])
        add_solr_value(solr_doc, milestone, dates.first, :date, [:searchable, :facetable])

        #fields for OAI havester to sort on
        add_solr_value(solr_doc, "#{milestone}_earliest_dt", dates.first, :date, [:sortable])
        add_solr_value(solr_doc, "#{milestone}_latest_dt", dates.last, :date, [:sortable])

        #for future faceting
        add_solr_value(solr_doc, "#{milestone}_earliest", dates.first, :date, [:searchable, :facetable])
        add_solr_value(solr_doc, "#{milestone}_latest", dates.last, :date, [ :searchable, :facetable])

      end
      add_solr_value(solr_doc,"status",status,:string, [:displayable])

      if sortable_milestones['opened']
        #add a facetable field for the date when the open version was opened
        opened_date=sortable_milestones['opened'].sort.last
        add_solr_value(solr_doc, "version_opened", DateTime.parse(opened_date).beginning_of_day.utc.xmlschema.split('T').first, :string, [ :searchable, :facetable])
      end
      add_solr_value(solr_doc, "current_version", current_version.to_s, :string, [ :displayable , :facetable])
      add_solr_value(solr_doc, "last_modified_day", self.modified_date.to_s.split('T').first, :string, [ :facetable ])
      add_solr_value(solr_doc, "rights", rights, :string, [:facetable]) if self.respond_to? :rights
      solr_doc
    end

    # Initilizes workflow for the object in the workflow service
    #  It will set the priorty of the new workflow to the current_priority if it is > 0
    #  It will set lane_id from the item's APO default workflow lane
    # @param [String] name of the workflow to be initialized
    # @param [String] repo name of the repository to create workflow for
    # @param [Boolean] create_ds create a 'workflows' datastream in Fedora for the object
    def initialize_workflow(name, repo='dor', create_ds=true, priority=0)
      priority = workflows.current_priority if priority == 0
      opts = { :create_ds => create_ds }
      opts[:priority] = priority if(priority > 0)
      opts[:lane_id] = default_workflow_lane
      Dor::WorkflowService.create_workflow(repo, self.pid, name, Dor::WorkflowObject.initial_workflow(name), opts)
    end


    private
    #handles formating utc date/time to human readable
    def format_date datetime
      begin
        zone = ActiveSupport::TimeZone.new("Pacific Time (US & Canada)")
        d = datetime.is_a?(Time) ? datetime : DateTime.parse(datetime).in_time_zone(zone)
        I18n.l(d)
      rescue
        d = datetime.is_a?(Time) ? datetime : Time.parse(datetime.to_s)
        d.strftime('%Y-%m-%d %I:%M%p')
      end
    end
  end


end

