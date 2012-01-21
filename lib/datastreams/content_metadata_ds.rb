class ContentMetadataDS < ActiveFedora::NokogiriDatastream 

  set_terminology do |t|
    t.root :path => 'contentMetadata', :xmlns => '', :namespace_prefix => nil, :index_as => [:not_searchable]
    t.contentType :path => { :attribute => 'type' }, :namespace_prefix => nil, :index_as => [:not_searchable]
    t.resource(:namespace_prefix => nil, :index_as => [:not_searchable]) do
      t.id_ :path => { :attribute => 'id' }, :namespace_prefix => nil
      t.sequence :path => { :attribute => 'sequence' }, :namespace_prefix => nil#, :data_type => :integer
      t.type_ :path => { :attribute => 'type' }, :namespace_prefix => nil, :index_as => [:displayable]
      t.attribute(:path => 'attr', :namespace_prefix => nil, :index_as => [:not_searchable]) do
        t.name :path => { :attribute => 'name' }, :index_as => [:not_searchable]
      end
      t.file(:namespace_prefix => nil, :index_as => [:not_searchable]) do
        t.id_ :path => { :attribute => 'id' }, :namespace_prefix => nil
        t.format :path => { :attribute => 'format' }, :namespace_prefix => nil, :index_as => [:displayable]
        t.mimeType :path => { :attribute => 'mimeType' }, :namespace_prefix => nil, :index_as => [:displayable]
        t.dataType :path => { :attribute => 'dataType' }, :namespace_prefix => nil, :index_as => [:displayable]
        t.size :path => { :attribute => 'size' }, :namespace_prefix => nil, :index_as => [:displayable]#, :data_type => :long
        t.shelve :path => { :attribute => 'shelve' }, :namespace_prefix => nil, :index_as => [:not_searchable]#, :data_type => :boolean
        t.publish :path => { :attribute => 'publish' }, :namespace_prefix => nil, :index_as => [:not_searchable]#, :data_type => :boolean
        t.preserve :path => { :attribute => 'preserve' }, :namespace_prefix => nil, :index_as => [:not_searchable]#, :data_type => :boolean
        t.checksum(:namespace_prefix => nil) do
          t.type_ :path => { :attribute => 'type' }, :namespace_prefix => nil
        end
      end
      t.shelved_file(:path => 'file', :attributes => {:shelve=>'yes'}, :namespace_prefix => nil, :index_as => [:not_searchable]) do
        t.id_ :path => { :attribute => 'id' }, :namespace_prefix => nil, :index_as => [:displayable, :searchable]
      end
    end
    t.shelved_file_id :proxy => [:resource, :shelved_file, :id], :index_as => [:displayable, :searchable]
  end
  
  def initialize *args
    super(*args)
    self.controlGroup = 'M'
  end
  
  def public_xml
    result = self.ng_xml.clone
    result.xpath('/contentMetadata/resource[not(file[(@deliver="yes" or @publish="yes")])]').each { |n| n.remove }
    result.xpath('/contentMetadata/resource/file[not(@deliver="yes" or @publish="yes")]').each { |n| n.remove }
    result.xpath('/contentMetadata/resource/file').xpath('@preserve|@shelve|@publish|@deliver').each { |n| n.remove }
    result.xpath('/contentMetadata/resource/file/checksum').each { |n| n.remove }
    result
  end
  
end
