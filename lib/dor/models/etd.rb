# frozen_string_literal: true

module Dor
  class Etd < Abstract
    include Dor::Embargoable

    # This relationship was modeled incorrectly when first implemented.
    # It should have been has_and_belongs_to_many so that the ETD is aware of
    # its component parts.  Presently there is no way to discover which parts
    # belong to the ETD without doing a Solr query.
    has_many :parts, property: :is_part_of, class_name: 'Part'
    has_many :supplemental_files, property: :is_constituent_of, class_name: 'Part'
    has_many :permission_files, property: :is_dependent_of, class_name: 'Part'

    has_attributes :name, :prefix, :suffix, :major, :degree, :advisor, :etd_type,
                   :title, :abstract, :containscopyright, :copyrightclearance,
                   :sulicense, :cclicense, :cclicensetype, :embargo,
                   :external_visibility, :term, :sub, :univid, :sunetid, :ps_career,
                   :ps_program, :ps_plan, :ps_subplan, :dissertation_id, :provost,
                   :degreeconfyr, :schoolname, :department, :readerapproval,
                   :readercomment, :readeractiondttm, :regapproval, :regcomment,
                   :regactiondttm, :documentaccess, :submit_date, :symphonyStatus,
                   datastream: 'properties', multiple: false

    has_attributes :citation_verified, :abstract_provided, :format_reviewed,
                   :dissertation_uploaded, :supplemental_files_uploaded,
                   :permissions_provided, :permission_files_uploaded,
                   :rights_selected, :cc_license_selected,
                   :submitted_to_registrar,
                   datastream: 'workflow', multiple: false

    has_metadata name: 'properties', type: ActiveFedora::SimpleDatastream, versionable: false do |m|
      m.field 'name',  :string                    # PS:name
      m.field 'prefix', :string                   # PS:prefix
      m.field 'suffix', :string                   # PS:suffix
      m.field 'major', :string                    # PS:plan
      m.field 'degree', :string                   # PS:degree
      m.field 'advisor', :string                  # one of the readers?
      m.field 'etd_type', :string                 # PS:type
      m.field 'title', :string                    # PS:title
      m.field 'abstract', :text
      m.field 'containscopyright', :string
      m.field 'copyrightclearance', :string
      m.field 'sulicense', :string
      m.field 'cclicense', :string
      m.field 'cclicensetype', :string
      m.field 'embargo', :string
      m.field 'external_visibility', :string

      m.field 'term', :string
      m.field 'sub', :string

      m.field 'univid', :string                   # PS:univid
      m.field 'sunetid', :string                  # PS:sunetid
      m.field 'ps_career', :string                # PS:career
      m.field 'ps_program', :string               # PS:program
      m.field 'ps_plan', :string                  # PS:plan
      m.field 'ps_subplan', :string               # PS:subplan
      m.field 'dissertation_id', :string          # PS:dissertationid
      m.field 'provost', :string                  # PS:vpname

      # from latest ps revision
      m.field 'degreeconfyr', :string
      m.field 'schoolname', :string               # Display value derived from ps_career
      m.field 'department', :string               # Display value derived from ps_program
      m.field 'readerapproval', :string           # Possible Values: Not Submitted, Not Approved, Approved, Rejected, Reject with Modification
      m.field 'readercomment', :string
      m.field 'readeractiondttm', :string         # date?
      m.field 'regapproval', :string              # Possible Values: Not Submitted, Not Approved, Approved, Rejected, Reject with Modification
      m.field 'regcomment', :string
      m.field 'regactiondttm', :string
      m.field 'documentaccess', :string

      m.field 'submit_date', :string
      m.field 'symphonyStatus', :string
    end

    has_metadata name: 'workflow', type: ActiveFedora::SimpleDatastream, versionable: false do |m|
      m.field 'citation_verified', :string
      m.field 'abstract_provided', :string
      m.field 'format_reviewed', :string
      m.field 'dissertation_uploaded', :string
      m.field 'supplemental_files_uploaded', :string
      m.field 'permissions_provided', :string
      m.field 'permission_files_uploaded', :string
      m.field 'rights_selected', :string
      m.field 'cc_license_selected', :string
      m.field 'submitted_to_registrar', :string
    end

    def etd_embargo_date
      regaction = properties.regactiondttm.first
      embargo = properties.embargo.first
      if properties.regapproval.first =~ /^approved$/i &&
         !embargo.nil? && embargo != '' &&
         !regaction.nil? && regaction != ''
        embargo_months = case embargo
                         when /6 months/i
                           6
                         when /1 year/i
                           12
                         when /2 years/i
                           24
                         else
                           0
                         end
        return Time.strptime(regaction, '%m/%d/%Y %H:%M:%S') + embargo_months.months
      end
      nil
    end
  end
end
