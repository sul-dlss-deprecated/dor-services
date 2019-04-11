# frozen_string_literal: true

module Dor
  # TODO: class docs
  class WorkflowDs < ActiveFedora::OmDatastream
    before_save :build_location
    set_terminology do |t|
      t.root(path: 'workflows')
      t.workflow do
        t.workflowId(path: { attribute: 'id' })
        t.process do
          t.name_(path: { attribute: 'name' }, index_as: %i[displayable not_searchable])
          t.status(path: { attribute: 'status' }, index_as: %i[displayable not_searchable])
          t.timestamp(path: { attribute: 'datetime' }, index_as: %i[displayable not_searchable]) # , :data_type => :date)
          t.elapsed(path: { attribute: 'elapsed' }, index_as: %i[displayable not_searchable])
          t.lifecycle(path: { attribute: 'lifecycle' }, index_as: %i[displayable not_searchable])
          t.attempts(path: { attribute: 'attempts' }, index_as: %i[displayable not_searchable])
        end
      end
    end

    # Called before saving, but after a pid has been assigned
    def build_location
      return unless new?

      self.dsLocation = File.join(Dor::Config.workflow.url, "dor/objects/#{pid}/workflows")
    end

    # Called by rubydora. This lets us customize the mime-type
    def self.default_attributes
      super.merge(mimeType: 'application/xml')
    end

    def ng_xml
      @ng_xml ||= Nokogiri::XML::Document.parse(content)
    end

    # @param [Boolean] refresh The WorkflowDS caches the content retrieved from the workflow
    # service. This flag will invalidate the cached content and refetch it from the workflow
    # service directly
    def content(refresh = false)
      @content = nil if refresh
      @content ||= Dor::Config.workflow.client.all_workflows_xml pid
    rescue Dor::WorkflowException => e
      # TODO: I don't understand when this would be useful as this block ends up calling the workflow service too.
      # Why not just raise an exception here?
      Dor.logger.warn "Unable to connect to the workflow service #{e}. Falling back to placeholder XML"
      xml = Nokogiri::XML(%(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<workflows objectId="#{pid}"/>))
      digital_object.datastreams.keys.each do |dsid|
        next unless dsid =~ /WF$/

        ds_content = Nokogiri::XML(Dor::Config.workflow.client.workflow_xml('dor', pid, dsid))
        xml.root.add_child(ds_content.root)
      end
      @content ||= xml.to_xml
    end

    def workflows
      @workflows ||= workflow.nodeset.collect { |wf_node| Workflow::Document.new wf_node.to_xml }
    end

    # Finds the first workflow that is expedited, then returns the value of its priority
    #
    # @return [Integer] value of the priority.  Defaults to 0 if none of the workflows are expedited
    def current_priority
      cp = workflows.detect(&:expedited?)
      return 0 if cp.nil?

      cp.priority.to_i
    end

    def to_solr(solr_doc = {}, *_args)
      # noop - indexing is done by the WorkflowsIndexer
      solr_doc
    end

    # maintain AF < 8 indexing behavior
    def prefix
      ''
    end
  end
end
