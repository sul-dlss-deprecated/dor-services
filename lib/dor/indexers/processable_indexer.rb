# frozen_string_literal: true

module Dor
  class ProcessableIndexer
    include SolrDocHelper

    attr_reader :resource
    def initialize(resource:)
      @resource = resource
    end

    # @return [Hash] the partial solr document for processable concerns
    def to_solr
      {}.tap do |solr_doc|
        add_versions(solr_doc)
        add_milestones(solr_doc, resource.milestones)
        solr_doc['modified_latest_dttsi'] = resource.modified_date.to_datetime.utc.strftime('%FT%TZ')
        add_solr_value(solr_doc, 'rights', resource.rights, :string, [:symbol]) if resource.respond_to? :rights
        add_status(solr_doc)
      end
    end

    private

    def current_version
      @current_version ||= begin
                             resource.versionMetadata.current_version_id
                           rescue StandardError
                             '1'
                           end
    end

    def add_status(solr_doc)
      solr_doc['status_ssi'] = resource.status # status is singular (i.e. the current one)
      status_info_hash = resource.status_info
      status_code = status_info_hash[:status_code]
      add_solr_value(solr_doc, 'processing_status_text', simplified_status_code_disp_txt(status_code), :string, [:stored_sortable])
      solr_doc['processing_status_code_isi'] = status_code
    end

    def add_milestones(solr_doc, milestones)
      milestones.each do |milestone|
        timestamp = milestone[:at].utc.xmlschema
        milestone[:version] ||= current_version
        solr_doc['lifecycle_ssim'] ||= []
        solr_doc['lifecycle_ssim'] << milestone[:milestone]
        add_solr_value(solr_doc, 'lifecycle', "#{milestone[:milestone]}:#{timestamp};#{milestone[:version]}", :symbol)
      end

      add_sortable_milestones(solr_doc, milestones)
    end

    def sortable_milestones(milestones)
      sortable = {}
      milestones.each do |milestone|
        sortable[milestone[:milestone]] ||= []
        sortable[milestone[:milestone]] << milestone[:at].utc.xmlschema
      end
      sortable
    end

    def add_sortable_milestones(solr_doc, milestones)
      sortable_milestones(milestones).each do |milestone, unordered_dates|
        dates = unordered_dates.sort
        # create the published_dttsi and published_day fields and the like
        dates.each do |date|
          solr_doc["#{milestone}_dttsim"] ||= []
          solr_doc["#{milestone}_dttsim"] << date unless solr_doc["#{milestone}_dttsim"].include?(date)
        end
        # fields for OAI havester to sort on: _dttsi is trie date +stored +indexed (single valued, i.e. sortable)
        solr_doc["#{milestone}_earliest_dttsi"] = dates.first
        solr_doc["#{milestone}_latest_dttsi"] = dates.last
      end
    end

    def add_versions(solr_doc)
      current_version_num = current_version.to_i
      solr_doc['current_version_isi'] = current_version_num

      return unless resource.respond_to?('versionMetadata')

      # add an entry with version id, tag and description for each version
      while current_version_num > 0
        new_val = "#{current_version_num};#{resource.versionMetadata.tag_for_version(current_version_num.to_s)};#{resource.versionMetadata.description_for_version(current_version_num.to_s)}"
        add_solr_value(solr_doc, 'versions', new_val, :string, [:displayable])
        current_version_num -= 1
      end
    end

    # @return [String] text translation of the status code, minus any trailing parenthetical explanation
    # e.g. 'In accessioning (described)' and 'In accessioning (described, published)' both return 'In accessioning'
    def simplified_status_code_disp_txt(status_code)
      Processable::STATUS_CODE_DISP_TXT[status_code].gsub(/\(.*\)$/, '').strip
    end
  end
end
