# frozen_string_literal: true

module Dor
  # TODO: class docs
  class WorkflowDs < ActiveFedora::OmDatastream
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

    def get_workflow(wf, repo = 'dor')
      xml = Dor::Config.workflow.client.get_workflow_xml(repo, pid, wf)
      xml = Nokogiri::XML(xml)
      return nil if xml.xpath('workflow').length == 0

      Workflow::Document.new(xml.to_s)
    end

    alias [] get_workflow

    def ng_xml
      @ng_xml ||= Nokogiri::XML::Document.parse(content)
    end

    # @param [Boolean] refresh The WorkflowDS caches the content retrieved from the workflow
    # service. This flag will invalidate the cached content and refetch it from the workflow
    # service directly
    def content(refresh = false)
      @content = nil if refresh
      @content ||= Dor::Config.workflow.client.get_workflow_xml 'dor', pid, nil
    rescue Dor::WorkflowException
      xml = Nokogiri::XML(%(<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<workflows objectId="#{pid}"/>))
      digital_object.datastreams.keys.each do |dsid|
        next unless dsid =~ /WF$/

        ds_content = Nokogiri::XML(Dor::Config.workflow.client.get_workflow_xml('dor', pid, dsid))
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

    def to_solr(solr_doc = {}, *args)
      # super solr_doc, *args
      workflows.each { |wf| solr_doc = wf.to_solr(solr_doc, *args) }
      solr_doc
    end

    # maintain AF < 8 indexing behavior
    def prefix
      ''
    end
  end
end
