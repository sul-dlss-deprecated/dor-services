class ContentMetadataDS < ActiveFedora::NokogiriDatastream 

  set_terminology do |t|
    t.root :path => 'contentMetadata', :index_as => [:not_searchable]
    t.contentType :path => { :attribute => 'type' }, :index_as => [:not_searchable]
    t.resource(:index_as => [:not_searchable]) do
      t.id_ :path => { :attribute => 'id' }
      t.sequence :path => { :attribute => 'sequence' }#, :data_type => :integer
      t.type_ :path => { :attribute => 'type' }, :index_as => [:displayable]
      t.attribute(:path => 'attr', :index_as => [:not_searchable]) do
        t.name :path => { :attribute => 'name' }, :index_as => [:not_searchable]
      end
      t.file(:index_as => [:not_searchable]) do
        t.id_ :path => { :attribute => 'id' }
        t.format :path => { :attribute => 'format' }, :index_as => [:displayable]
        t.mimeType :path => { :attribute => 'mimeType' }, :index_as => [:displayable]
        t.dataType :path => { :attribute => 'dataType' }, :index_as => [:displayable]
        t.size :path => { :attribute => 'size' }, :index_as => [:displayable]#, :data_type => :long
        t.shelve :path => { :attribute => 'shelve' }, :index_as => [:not_searchable]#, :data_type => :boolean
        t.publish :path => { :attribute => 'publish' }, :index_as => [:not_searchable]#, :data_type => :boolean
        t.preserve :path => { :attribute => 'preserve' }, :index_as => [:not_searchable]#, :data_type => :boolean
        t.checksum(:namespace_prefix => nil) do
          t.type_ :path => { :attribute => 'type' }
        end
      end
      t.shelved_file(:path => 'file', :attributes => {:shelve=>'yes'}, :index_as => [:not_searchable]) do
        t.id_ :path => { :attribute => 'id' }, :index_as => [:displayable, :searchable]
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
