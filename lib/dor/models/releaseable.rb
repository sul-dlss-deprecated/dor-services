module Dor
  module Releaseable
    extend ActiveSupport::Concern
    include Itemizable
    @@release_prefix = "release:"
    @@item_embargo_tag = "embargo"
    @@collection_global_release = "all"
    
    #Determine if an item is released for a specific namespace or not
    #
    #
    #
    #@return
    #TODO: Finish me once this function stabilizes 
    def released_for(options = {})
      #Get All Release Tags
      tags = self.release_tags
      
      #Detect if any namespace(s) supplied in options
      single_return = options[:namespace]
      
      #Determine if released for each namespace
      released_hash = self.released_yes_no_by_tags(tags)
      
      if single_return
        return released_hash[options[:namespace]] || false #If it doesn't exist it will come back as a nil, so return false
      end
    
      return released_hash
    end
    
    #Parses all tags for each namespace and determines if an item is released for that namespace or not
    #
    #@return [hash] of namespaces and booleans, such as {searchworks => true, frda => false, revs => true}
    #
    #@params [hash] of all tags in the form of {namespace => ["tag1", "tag2"]}
    def released_yes_no_by_tags(tags)
      released_yn = {}
      tags.keys.each do |key|
        #If the item has specifically blocked itself from release to this namespace, false and no more operations
        if tags[key].include? @@item_embargo_tag
          released_yn[key] = false 
        else
          #Does the Collection have a Global Release for these items?
          if tags[key].include?  @@collection_global_release
            released_yn[key] = true
          #If we don't have a global release for the item, it must be a specific tag of a collection has been released
          else
            item_tags = self.tags
            release = false
            tags[key].each do |tag|
              #These should be in the form of something such as {:searchworkers => ["tag:fitch1", "tag:fitch2"]} due to how we process tags
              release = true if item_tags.include?(self.normalize_tag(tag))
            end
            #Item has some kind of release tag on it that does not match :all for a collection or a specific tag it has, set to false
            released_yn[key] = release
          end
          
        end   
      end
      return released_yn
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
      all_tags += self.tags
      
      release_governed_by = self.collections
  
      release_governed_by.each do |parent|
        all_tags += Dor::Item.find(parent.id).get_all_tags_on_item_and_parents
      end
      
      return all_tags.uniq
      
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
        
        if release_value != nil
          #Add the info to the return hash, append to exsisting list if needed 
          if release_tags.keys.include?(release_value[:namespace])
            release_tags[release_value[:namespace]] << release_value[:release_info] 
          else
            release_tags[release_value[:namespace]] = [release_value[:release_info]]
          end
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
        release_info = value[1][i+1..value[1].size-1] #TODO: Catch the lack of an instruction after namespace, as in a tag that is 'release:searchworks:'
        return {:namespace => namespace, :release_info => release_info}
      end
      return nil
    end
    
    
  end
end
