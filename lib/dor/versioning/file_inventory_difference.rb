module Dor
module Versioning
  class FileInventoryDifference
    include OM::XML::Document
    
    set_terminology do |t|
      t.root(:path => 'fileInventoryDifference')
      t.content(:path => 'fileGroupDifference', :attributes => { :groupId => 'content' }) do
        t.subset                                                                 do t.file { t.fileSignature } end
        t.identical :path => 'subset', :attributes => { :change => 'identical' } do t.file { t.fileSignature } end
        t.added     :path => 'subset', :attributes => { :change => 'added'     } do t.file { t.fileSignature } end
        t.renamed   :path => 'subset', :attributes => { :change => 'renamed'   } do t.file { t.fileSignature } end
        t.modified  :path => 'subset', :attributes => { :change => 'modified'  } do t.file { t.fileSignature } end
        t.deleted   :path => 'subset', :attributes => { :change => 'deleted'   } do t.file { t.fileSignature } end
      end
      t.metadata(:path => 'fileGroupDifference', :attributes => { :groupId => 'metadata' }) do
        t.subset                                                                 do t.file { t.fileSignature } end
        t.identical :path => 'subset', :attributes => { :change => 'identical' } do t.file { t.fileSignature } end
        t.added     :path => 'subset', :attributes => { :change => 'added'     } do t.file { t.fileSignature } end
        t.renamed   :path => 'subset', :attributes => { :change => 'renamed'   } do t.file { t.fileSignature } end
        t.modified  :path => 'subset', :attributes => { :change => 'modified'  } do t.file { t.fileSignature } end
        t.deleted   :path => 'subset', :attributes => { :change => 'deleted'   } do t.file { t.fileSignature } end
      end

      t.identical_content_files  :proxy => [:content,  :identical, :file]
      t.added_content_files      :proxy => [:content,  :added,     :file]
      t.renamed_content_files    :proxy => [:content,  :renamed,   :file]
      t.modified_content_files   :proxy => [:content,  :modified,  :file]
      t.deleted_content_files    :proxy => [:content,  :deleted,   :file]

      t.identical_metadata_files :proxy => [:metadata, :identical, :file]
      t.added_metadata_files     :proxy => [:metadata, :added,     :file]
      t.renamed_metadata_files   :proxy => [:metadata, :renamed,   :file]
      t.modified_metadata_files  :proxy => [:metadata, :modified,  :file]
      t.deleted_metadata_files   :proxy => [:metadata, :deleted,   :file]
    end
    
    def initialize content
      super()
      if content.is_a?(Nokogiri::XML::Node)
        self.ng_xml = content
      else
        self.ng_xml = Nokogiri::XML(content)
      end
    end
    
    def file_sets(change, groupId=:content)
      self.ng_xml.xpath(self.class.terminology.xpath_for(groupId.to_sym, change.to_sym, :file)).collect do |node|
        result = [node['basisPath'],node['otherPath']].select { |s| not ['','same', nil].include?(s) }
        result.length == 1 ? result.first : result
      end
    end
  end
end
end