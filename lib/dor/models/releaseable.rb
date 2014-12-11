module Dor
  module Releaseable
    extend ActiveSupport::Concern
    include Itemizable
    @@release_prefix = "release:"
    
    #Determine if an item is released for a specific namespace or not
    #
    #@return
    #TODO: Finish me once this function stabilizes 
    def released_for(options = {})
    end
    
    #Returns all release tags for an item 
    #
    #@return [hash] of release tags and their values
    #
    #Example:
    #   item.release_tags
    def release_tags
      #Convert document to solr hash
      solr_hash = self.to_solr
      
      #First get the item type
      #TODO: Don't hardcode name
      type = solr_hash['identityMetadata_objectType_t']
      
    end
    
    #Takes all supplied tags and creates a hash of just the release ones
    #
    #@return [hash] of release tags and their values
    #
    #@param [array] of all tags to parse
    def hash_tags_by_namespace(tags)
      release_tags = {}
      
      #Drop any duplicates (if set multiple times on various collections)
      tags = tags.uniq
      
      #Grab the Release tags
      tags.each do |tag|
        release_value = self.parse_tag(tag)
        
        #Add the info to the return hash
        t[release_value[:namespace]] << release_value[:release_info] if t.keys.include 
        
      end
    end
    
    #Takes a tag and returns its namespace and release_info if it is a release tag, returns nil if it is not
    #@return [hash] in the form of {:namespace => str, :release_info => str} if it is a release tag
    #@return [nil] if the tag is not a release tag
    #
    #@paran [str] a tag
    def parse_tag(tag)
      tag = tag.delete(' ') #delete whitespace
      value = tag.split(@@release_prefix) #split the tag up
      if value[0] == "" #If release: was the first part it should now be dropped
        
        #TODO: Catch the lack of a value[1], aka nothing after release:
        i = value[1].index(":")
        namespace = value[1][0..i-1]
        release_info = value[1][i+1..value[1].size] #TODO: Catch the lack of an instruction after namespace, as in a tag that is 'release:searchworks:'
        return {:namespace => namespace, :release_info => release_info}
      end
      return nil
    end
    
    
  end
end
