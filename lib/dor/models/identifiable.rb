module Dor
  module Identifiable
    extend ActiveSupport::Concern
    include SolrDocHelper
    include Eventable
    include Upgradable

    included do
      has_metadata :name => "DC", :type => SimpleDublinCoreDs, :label => 'Dublin Core Record for self object'
      has_metadata :name => "identityMetadata", :type => Dor::IdentityMetadataDS, :label => 'Identity Metadata'
    end

    module ClassMethods
      attr_reader :object_type
      def has_object_type str
        @object_type = str
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
      solr_doc[solr_name('indexed_at',:date)] = Time.now.utc.xmlschema
      datastreams.values.each do |ds|
        unless ds.new?
          add_solr_value(solr_doc,'ds_specs',ds.datastream_spec_string,:string,[:displayable])
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
    def update_source_id(source_id)
        self.identityMetadata.sourceId = source_id
      end

      def add_other_Id(val)
        node_name=val.split(/:/).first
        if self.identityMetadata.otherId(node_name).length>0        
          raise 'There is an existing entry for '+node_name+', consider using update_other_identifier.'
        end
        identity_metadata_ds = self.identityMetadata
        identity_metadata_ds.add_otherId(val)
      end

      def update_other_Id(val)
        identity_metadata_ds = self.identityMetadata
        ds_xml=identity_metadata_ds.ng_xml
        #split the thing they sent in to find the node name
        node_name=val.split(/:/).first
        new_val=val.split(/:/).last
        updated=false
        ds_xml.search('//otherId[@name=\''+node_name+'\']').each do |node|
          node.content=new_val
          updated=true
          self.identityMetadata.dirty=true
        end
        return updated
      end
 
      def remove_other_Id(val)
        ds_xml=self.identityMetadata.ng_xml
        #split the thing they sent in to find the node name
        node_name=val.split(/:/).first  
        removed=false
        ds_xml.search('//otherId[@name=\''+node_name+'\']').each do |node|
          if node.content===val.split(/:/).last
            node.remove
            removed=true
            self.identityMetadata.dirty=true
          end
        end
        return removed
      end
      
      def add_tag(tag)
        identity_metadata_ds = self.identityMetadata
        prefix=tag.split(/:/).first
        identity_metadata_ds.tags.each do |existing_tag|
          if existing_tag.split(/:/).first ==prefix 
            raise 'An existing tag ('+existing_tag+') has the same prefix, consider using update_tag?'
          end
        end
        identity_metadata_ds.add_value(:tag,tag)
      end
      
      def remove_tag(tag)
        identity_metadata_ds = self.identityMetadata
        ds_xml=identity_metadata_ds.ng_xml
        removed=false
        ds_xml.search('//tag').each do |node|
          if node.content===tag
            node.remove
            removed=true
            self.identityMetadata.dirty=true
          end
        end
        return removed
      end
      
      def update_tag(old_tag,new_tag)
        identity_metadata_ds = self.identityMetadata
        ds_xml=identity_metadata_ds.ng_xml
        updated=false
        ds_xml.search('//tag').each do |node|
          if node.content==old_tag
            node.content=new_tag
            updated = true
            self.identityMetadata.dirty=true
          end
        end
        return updated 
      end
  end
end