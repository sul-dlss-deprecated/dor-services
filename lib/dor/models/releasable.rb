module Dor
  module Releasable
    extend ActiveSupport::Concern
    include Itemizable

    #Generate XML structure for inclusion to Purl 
    #
    #@return [String] The XML release node as a string, with ReleaseDigest as the root document
    def generate_release_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.ReleaseDigest {
          self.released_for.each do |project,released_value|
            xml.release(released_value["release"],:to=>project)
          end  
        }        
      end
      return builder.to_xml
    end
    
    #Determine which projects an item is released for
    #
    #@return [Hash] all namespaces in the form of {"Project" => Boolean}
    def released_for
      released_hash = {}
      
      #Get release tags on the item itself 
      release_tags_on_this_item = self.release_nodes
      
      #Get any self tags on this item
      self_release_tags = self.get_self_release_tags(release_tags_on_this_item)
      
      #Get the most recent self tag for all targets and save their result since most recent self always trumps any other non self tags
      latest_self_tags = self.get_newest_release_tag(self_release_tags)
      latest_self_tags.keys.each do |target|
        released_hash[target] =  self.clean_release_tag_for_purl(latest_self_tags[target])
      end
      
      #With Self Tags Resolved We Now need to deal with tags on all sets this object is part of 
      
      potential_applicable_release_tags = {}  #This will be where we store all tags that apply, regardless of their timestamp
       
      #Get all release tags on the item and strip out the what = self ones, we've already processed all the self tags on this item 
      potential_applicable_release_tags = get_tags_for_what_value(self.get_release_tags_for_item_and_all_governing_sets, 'collection')
      
      administrative_tags = self.tags  #Get them once here and pass them down
      
      #We now have the keys for all potential releases, we need to check the tags and the most recent time stamp with an explicit true or false wins, in a nil case, the lack of an explicit false tag we do nothing
      (potential_applicable_release_tags.keys-released_hash.keys).each do |key|  #don't bother checking the ones already added to the release hash, they were added due to a self tag and that has won
        latest_applicable_tag_for_key = latest_applicable_release_tag_in_array(potential_applicable_release_tags[key], administrative_tags)
        if latest_applicable_tag_for_key != nil #We have a valid tag, record it
          released_hash[key] = self.clean_release_tag_for_purl(latest_applicable_tag_for_key) 
        end
        
      end
        
      return released_hash
    end
    
    #Take a hash of tags as obtained via Dor::Item.release_tags and returns all self tags
    #
    #@param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    #
    #@return [Hash] a hash of self tags for each to value
    def get_self_release_tags(tags)
      return get_tags_for_what_value(tags, 'self')
    end
    
    #Take an item and get all of its release tags and all tags on collections it is a member of it
    #
    #
    #@return [Hash] a hash of all tags
    def get_release_tags_for_item_and_all_governing_sets
      return_tags = self.release_nodes || {}
      self.collections.each do |collection|
        return_tags = combine_two_release_tag_hashes(return_tags, Dor::Item.find(collection.id).get_release_tags_for_item_and_all_governing_sets) #this will function recurvisely so parents of parents are found
      end
      return return_tags  
    end
    
    #Take two hashes of tags and combine them, will not overwrite but will enforce uniqueness of the tags
    #
    #@param hash_one [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    #@param hash_two [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    #
    #@return [Hash] the combined hash with uniquiness enforced 
    def combine_two_release_tag_hashes(hash_one, hash_two)
      hash_two.keys.each do |key|
        hash_one[key] = hash_two[key] if hash_one[key].nil?
        hash_one[key] = (hash_one[key] + hash_two[key]).uniq if hash_one[key] != nil
      end
      return hash_one
    end
    
    #Take a hash of tags and return all tags with the matching what target
    #
    #@param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    #@param what_target [String] the target for the 'what' key, self or collection
    #
    #@return [Hash] a hash of self tags for each to value
    def get_tags_for_what_value(tags, what_target)
      return_hash = {}
      tags.keys.each do |key|
        self_tags =  tags[key].select{|tag| tag['what'] == what_target.downcase}
        return_hash[key] = self_tags if self_tags.size > 0
      end
      return return_hash
    end
    
    #Take a hash of tags as obtained via Dor::Item.release_tags and returns the newest tag for each namespace
    #
    #@params tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    #
    #@return [Hash] a hash of latest tags for each to value
    def get_newest_release_tag(tags)
      return_hash = {}
      tags.keys.each do |key|
        latest_for_key = newest_release_tag_in_an_array(tags[key])
        return_hash[key] = latest_for_key         
      end
      return return_hash
    end
    
    #Take a tag and return only the attributes  we want to put into purl
    #
    #@param tag [Hash] a tag
    #
    #@return [Hash] a hash of the attributes we want for purl
    def clean_release_tag_for_purl(tag)
      for_purl = ['release']
      return_hash = {}
      for_purl.each do |attr|
        return_hash[attr] = tag[attr]
      end
      return return_hash
    end
    
    #Takes an array of release tags and returns the most recent one
    #
    #@params tags [Array] an array of hashes, with the hashes being release tags
    #
    #@return [Hash] the most recent tag
    def newest_release_tag_in_an_array(array_of_tags)
      latest_tag_in_array = array_of_tags[0] || {}
      array_of_tags.each do |tag|
        latest_tag_in_array = tag if tag['when'] > latest_tag_in_array['when']
      end
      return latest_tag_in_array
    end
    
    #Takes a tag and returns true or false if it applies to the specific item
    #
    #@param release_tag [Hash] the tag in a hashed form
    #@param Optional admin_tags [Array] the administrative tags on an item, if not supplied it will attempt to retrieve them
    #
    #@return [Boolean] true or false if it applies (not true or false if it is released, that is the release_tag data)
    def does_release_tag_apply(release_tag, admin_tags=false)
      #Is the tag global or restricted 
      return true if release_tag['tag'].nil?  #there is no specific tag specificied, so that means this tag is global to all members of the collection, it applies, return true
        
      admin_tags = self.tags unless admin_tags #We use false instead of [], since an item can have no admin_tags that which point we'd be passing down this variable as [] and would not an attempt to retrieve it
      return admin_tags.include?(release_tag['tag'])
    end
    
    #Takes an array of release tags and returns the most recent one that applies to this item
    #
    #@param release_tags [Array] an array of release tags in hashed form
    #param admin_tags [Array] the administrative tags on an on item
    #
    #@return [Hash] the tag
    def latest_applicable_release_tag_in_array(release_tags, admin_tags)
      newest_tag = newest_release_tag_in_an_array(release_tags)
      return newest_tag if does_release_tag_apply(newest_tag, admin_tags) #Return true if we have it
      
      #The latest tag wasn't applicable, slice it off and try again
      #This could be optimized by reordering on the timestamp and just running down it instead of constantly resorting, at least if we end up getting numerous release tags on an item
      release_tags.slice!(release_tags.index(newest_tag))
      
      return latest_applicable_release_tag_in_array(release_tags, admin_tags) if release_tags.size > 0 #Try again after dropping the one that wasn't applicable 
      
      return nil #We're out of tags, no applicable ones
    end
    
    #helper method to get the release tags as a nodeset
    #
    #@return [Nokogiri::XML::NodeSet] of all release tags and their attributes
    def release_tags
      release_tags = self.identityMetadata.ng_xml.xpath('//release')
      return_hash = {}
      release_tags.each do |release_tag|
        hashed_node = self.release_tag_node_to_hash(release_tag)
        if return_hash[hashed_node[:to]] != nil
          return_hash[hashed_node[:to]] << hashed_node[:attrs]
        else
           return_hash[hashed_node[:to]] = [hashed_node[:attrs]]
        end
      end
      return return_hash
    end

    #method to convert one release element into an array
    #
    #@param rtag [Nokogiri::XML::Element] the release tag element
    #
    #return [Hash] in the form of {:to => String :attrs = Hash}
    def release_tag_node_to_hash(rtag)
      to = 'to'
      release = 'release'
      when_word = 'when' #TODO: Make to and when_word load from some config file instead of hardcoded here
      attrs = rtag.attributes
      return_hash = { :to => attrs[to].value }
      attrs.tap { |a| a.delete(to)}
      attrs[release] = rtag.text.downcase == "true" #save release as a boolean
      return_hash[:attrs] = attrs

      #convert all the attrs beside :to to strings, they are currently Nokogiri::XML::Attr
      (return_hash[:attrs].keys-[to]).each do |a|
        return_hash[:attrs][a] =  return_hash[:attrs][a].to_s if a != release
      end

      return_hash[:attrs][when_word] = Time.parse(return_hash[:attrs][when_word]) #convert when to a datetime

      return return_hash
    end
    
    #Determine if the supplied tag is a valid release tag that meets all requirements
    #
    #@raises [RuntimeError]  Raises an error of the first fault in the release tag
    #
    #@return [Boolean] Returns true if no errors found
    #
    #@params attrs [hash] A hash of attributes for the tag, must contain: :when, a ISO 8601 timestamp; :who, to identify who or what added the tag; and :to, a string identifying the release target
    def valid_release_attributes_and_tag(tag, attrs={})
      raise ArgumentError, ":when is not iso8601" if attrs[:when].match('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z') == nil
      [:who, :to, :what].each do |check_attr|
        raise ArgumentError, "#{check_attr} not supplied as a String" if attrs[check_attr].class != String
      end

      what_correct = false
      ['self', 'collection'].each do |allowed_what_value|
        what_correct = true if attrs[:what] == allowed_what_value
      end
      raise ArgumentError, ":what must be self or collection" if ! what_correct
      raise ArgumentError, "the value set for this tag is not a boolean" if !!tag != tag
      validate_tag_format(attrs[:tag]) if attrs[:tag] != nil #Will Raise exception if invalid tag
      return true
    end
    
    #Add a release node for the item
    #Will use the current time to add in the timestamp if you do not supply a timestamp, you can supply a timestap for correcting history, etc if desired
    #
    #@return [Nokogiri::XML::Element] the tag added if successful 
    #
    #@raise [RuntimeError] Raised if attributes are improperly supplied
    #
    #@params tag [Boolean] True or false for the release node
    #@params attrs [hash]  A hash of any attributes to be placed onto the tag 
    # release tag example:
    #  item.add_tag(true,:release,{:tag=>'Fitch : Batch2',:what=>'self',:to=>'Searchworks',:who=>'petucket'})
    def add_release_node(release, attrs={})
      identity_metadata_ds = self.identityMetadata
      attrs[:when] = Time.now.utc.iso8601 if attrs[:when] == nil#add the timestamp
      valid_release_attributes(release, attrs)
  
      return identity_metadata_ds.add_value(:release, release.to_s, attrs)
    end

    #Determine if the supplied tag is a valid release node that meets all requirements
    #
    #@raises [ArgumentError]  Raises an error of the first fault in the release tag
    #
    #@return [Boolean] Returns true if no errors found 
    #
    #@params attrs [hash] A hash of attributes for the tag, must contain :when, a ISO 8601 timestamp and :who to identify who or what added the tag, :to, 
    def valid_release_attributes(tag, attrs={})
      raise ArgumentError, ":when is not iso8601" if attrs[:when].match('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z') == nil
      [:who, :to, :what].each do |check_attr|
        raise ArgumentError, "#{check_attr} not supplied as a String" if attrs[check_attr].class != String
      end
  
      what_correct = false
      ['self', 'collection'].each do |allowed_what_value|
        what_correct = true if attrs[:what] == allowed_what_value
      end
      raise ArgumentError, ":what must be self or collection" if ! what_correct
  
      raise ArgumentError, "the value set for this tag is not a boolean" if !!tag != tag
      #identity_metadata_ds = self.identityMetadata
      validate_tag_format(attrs[:tag]) if attrs[:tag] != nil #Will Raise exception if invalid tag
      return true
    end

    #helper method to get the release nodes as a nodeset
    #
    #@return [Nokogiri::XML::NodeSet] of all release tags and their attributes
    def release_nodes
      release_tags = self.identityMetadata.ng_xml.xpath('//release')
      return_hash = {}
      release_tags.each do |release_tag|
        hashed_node = self.release_tag_node_to_hash(release_tag)
        if return_hash[hashed_node[:to]] != nil
          return_hash[hashed_node[:to]] << hashed_node[:attrs]
        else
           return_hash[hashed_node[:to]] = [hashed_node[:attrs]]
        end
      end
      return return_hash
    end

  end
end
