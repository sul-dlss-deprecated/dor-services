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

    # helper method to get the tags as an array
    def tags
      self.identityMetadata.tag
    end

    # helper method to get just the content type tag
    def content_type_tag
     content_tag=tags.select {|tag| tag.include?('Process : Content Type')}
     content_tag.size == 1 ? content_tag[0].split(':').last.strip : ""
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
      add_solr_value(solr_doc, 'indexed_day', Time.now.beginning_of_day.utc.xmlschema, :string, [:searchable, :facetable])
      datastreams.values.each do |ds|
        unless ds.new?
          add_solr_value(solr_doc,'ds_specs',ds.datastream_spec_string,:string,[:displayable])
        end
      end
      add_solr_value(solr_doc,'title', self.label,:string,[:sortable])
      rels_doc = Nokogiri::XML(self.datastreams['RELS-EXT'].content)
       collections=rels_doc.search('//rdf:RDF/rdf:Description/fedora:isMemberOfCollection','fedora' => 'info:fedora/fedora-system:def/relations-external#', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' 	)
       collections.each do |collection_node| 
        druid=collection_node['resource']
        druid=druid.gsub('info:fedora/','')
        begin
        collection_object=Dor.find(druid)
        add_solr_value(solr_doc, "collection_title", collection_object.label, :string, [:searchable, :facetable])
        rescue
        add_solr_value(solr_doc, "collection_title", druid, :string, [:searchable, :facetable])
        end
       end
       
       apos=rels_doc.search('//rdf:RDF/rdf:Description/hydra:isGovernedBy','hydra' => 'http://projecthydra.org/ns/relations#', 'fedora' => 'info:fedora/fedora-system:def/relations-external#', 'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' 	)
       apos.each do |apo_node|
        druid=apo_node['resource']
        druid=druid.gsub('info:fedora/','')
        begin
        apo_object=Dor.find(druid)
        add_solr_value(solr_doc, "apo_title", apo_object.label, :string, [:searchable, :facetable])
        rescue
        add_solr_value(solr_doc, "apo_title", druid, :string, [:searchable, :facetable])
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
    def set_source_id(source_id)
        self.identityMetadata.sourceId = source_id
      end

      def add_other_Id(type,val)
        if self.identityMetadata.otherId(type).length>0        
          raise 'There is an existing entry for '+node_name+', consider using update_other_identifier.'
        end
        identity_metadata_ds = self.identityMetadata
        identity_metadata_ds.add_otherId(type+':'+val)
      end

      def update_other_Id(type,new_val, val=nil)
        identity_metadata_ds = self.identityMetadata
        ds_xml=identity_metadata_ds.ng_xml
        #split the thing they sent in to find the node name
        updated=false
        ds_xml.search('//otherId[@name=\''+type+'\']').each do |node|
          if node.content==val or val==nil
					node.content=new_val
          updated=true
          self.identityMetadata.dirty=true
					end
        end
        return updated
      end
 
      def remove_other_Id(type,val=nil)
        ds_xml=self.identityMetadata.ng_xml
        #split the thing they sent in to find the node name
        removed=false

        ds_xml.search('//otherId[@name=\''+type+'\']').each do |node|
          if node.content===val or val==nil
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
