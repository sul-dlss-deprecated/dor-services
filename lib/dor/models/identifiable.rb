module Dor
  module Identifiable
    extend ActiveSupport::Concern
    include SolrDocHelper
    
    included do
      has_metadata :name => "DC", :type => SimpleDublinCoreDs, :label => 'Dublin Core Record for this object'
      has_metadata :name => "identityMetadata", :type => Dor::IdentityMetadataDS, :label => 'Identity Metadata'
    end

    module ClassMethods
      def has_object_type str
        Dor.registered_classes[str] = self
      end
    end
    
    def initialize attrs={}
      if Dor::Config.suri.mint_ids
        unless attrs[:pid]
          attrs = attrs.merge!({:pid=>Dor::SuriService.mint_id, :new_object => true})
        end
      end
      super
    end
    
    # Syntactic sugar for identifying applied DOR Concerns
    # e.g., obj.is_identifiable? is the same as obj.is_a?(Dor::Identifiable)
    def method_missing sym, *args
      if sym.to_s =~ /^is_(.+)\?$/
        begin
          klass = Dor.const_get $1.capitalize.to_sym
          return self.is_a?(klass)
        rescue NameError
          return false
        end
      else
        super
      end
    end

    def to_solr(solr_doc=Hash.new, *args)
      self.assert_content_model
      super(solr_doc)
      solr_doc[Dor::INDEX_VERSION_FIELD] = Dor::VERSION
      datastreams.values.each do |ds|
        unless ds.new?
          add_solr_value(solr_doc,'ds_specs',ds.datastream_spec_string,:string,[:displayable])
        end
      end
      
      all_predicates = Hash[ActiveFedora::Predicates.predicate_mappings.collect { |k,v| v.collect { |s,p| ["#{k}#{p}",s] } }.flatten.in_groups_of(2)]
      
      self.relationships.statements.each do |s| 
        field_name = ::ActiveFedora::SolrService.solr_name(all_predicates[s.predicate.to_s], :string, :displayable)
        unless solr_doc[field_name]
          begin
            ref = Dor.find(s.object.to_s.split(/\//).last, :lightweight => true)
            unless ref.nil?
              ::Solrizer::Extractor.insert_solr_field_value(solr_doc,field_name,ref.label) 
            end
          rescue ActiveFedora::ObjectNotFoundError
            # pass
          end
        end
      end
      
      # Fix for ActiveFedora 3.3 to ensure all date fields are properly formatted as UTC XML Schema datetime strings
      solr_doc.each_pair { |k,v| 
        if k =~ /_dt|_date$/
          if v.is_a?(Array)
            solr_doc[k] = v.collect { |t| Time.parse(t.to_s).utc.xmlschema }
          else
            solr_doc[k] = Time.parse(v.to_s).utc.xmlschema
          end
        end
      }
      
      solr_doc
    end
  end
end