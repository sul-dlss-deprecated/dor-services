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
      #Get All Release Tags
      
      #Detect if any namespace(s) supplied in options
      #If only one namespace was supplied, return true or false for that namespace
      #If multiple namespaces were supplied, return a hash in the form of {:namespace => boolean} for only specified ones
      #If no namespaces were supplied, return hash in the format above, but for all namespaces included in the tags
      
      
    end
    
    #Returns all release tags for an item 
    #
    #@return [hash] of release tags and their values
    #
    #Example:
    #   item.release_tags
    def release_tags
      return self.hash_release_tags_by_namespace(self.get_all_tags_on_item_and_parents)
    end
    
    #Returns a list of all tags on an item and its parents
    #
    #@return [array] array of all tags
    #
    #Example:
    #   item.get_all_tags_on_item_and_parents
    def get_all_tags_on_item_and_parents
      all_tags = []
      
      #Add Tags on the Item Itself
      all_tags << self.tags
      
      release_governed_by = #Get all collections and set (recursively)
      
      release_governed_by.uniq do |parent|
        all_tags << Dor::Item.find(parent).get_all_tags_on_item_and_parents
      end
      
      return all_tags
      
    end
    
    #Takes all supplied tags and creates a hash of just the release ones
    #
    #@return [hash] of release tags and their values
    #
    #@param [array] of all tags to parse
    def hash_release_tags_by_namespace(tags)
      release_tags = {}
      
      #Drop any duplicates (if set multiple times on various collections)
      tags = tags.uniq
      
      #Grab the Release tags
      tags.each do |tag|
        release_value = self.parse_tag(tag)
        
        #Add the info to the return hash, append to exsisting list if needed 
        if t.keys.include?(release_value[:namespace])
          release_tags[release_value[:namespace]] << release_value[:release_info] 
        else
          release_tags[release_value[:namespace]] = [release_value[:release_info]]
        end
      end
      return release_tags
    end
    
    #Takes a tag and returns its namespace and release_info if it is a release tag, returns nil if it is not
    #@return [hash] in the form of {:namespace => str, :release_info => str} if it is a release tag
    #@return [nil] if the tag is not a release tag
    #
    #@param [str] a tag
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
