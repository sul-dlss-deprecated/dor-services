require 'open-uri'
require 'retries'

module Dor
  module Releaseable
    extend ActiveSupport::Concern
    include Itemizable

    # Add release tags to an item and initialize the item release workflow
    # Each tag should be of the form !{:tag => 'Fitch : Batch2', :what => 'self', :to => 'Searchworks', :who => 'petucket', :release => true}
    # @param release_tags [Hash, Array<Hash>] hash of a single release tag or an array of many such hashes
    # @raise [ArgumentError] Raised if the tags are improperly supplied
    def add_release_nodes_and_start_releaseWF(release_tags)
      release_tags = [release_tags] unless release_tags.is_a?(Array)

      # Add in each tag
      release_tags.each do |r_tag|
        add_release_node(r_tag[:release], r_tag)
      end

      # Save item to dor so the robots work with the latest data
      save
      create_workflow('releaseWF')
    end

    # Generate XML structure for inclusion to Purl
    # @return [String] The XML release node as a string, with ReleaseDigest as the root document
    def generate_release_xml
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.releaseData {
          released_for.each do |project, released_value|
            xml.release(released_value['release'], :to => project)
          end
        }
      end
      builder.to_xml
    end

    # Determine projects in which an item is released
    # @param [Boolean] skip_live_purl set true to skip requesting from purl backend
    # @return [Hash{String => Boolean}] all namespaces, keys are Project name Strings, values are Boolean
    def released_for(skip_live_purl = false)
      released_hash = {}

      # Get the most recent self tag for all targets and retain their result since most recent self always trumps any other non self tags
      latest_self_tags = get_newest_release_tag get_self_release_tags(release_nodes)
      latest_self_tags.each do |key, payload|
        released_hash[key] = {'release' => payload['release']}
      end

      # With Self Tags resolved we now need to deal with tags on all sets this object is part of.
      # Get all release tags on the item and strip out the what = self ones, we've already processed all the self tags on this item.
      # This will be where we store all tags that apply, regardless of their timestamp:
      potential_applicable_release_tags = get_tags_for_what_value(get_release_tags_for_item_and_all_governing_sets, 'collection')
      administrative_tags = tags  # Get admin tags once here and pass them down

      # We now have the keys for all potential releases, we need to check the tags: the most recent timestamp with an explicit true or false wins.
      # In a nil case, the lack of an explicit false tag we do nothing.
      (potential_applicable_release_tags.keys - released_hash.keys).each do |key|  # don't bother checking if already added to the release hash, they were added due to a self tag so that has won
        latest_tag = latest_applicable_release_tag_in_array(potential_applicable_release_tags[key], administrative_tags)
        next if latest_tag.nil? # Otherwise, we have a valid tag, record it
        released_hash[key] = {'release' => latest_tag['release']}
      end

      # See what the application is currently released for on Purl.  If released in purl but not listed here, it needs to be added as a false
      add_tags_from_purl(released_hash) unless skip_live_purl
      released_hash
    end

    # Take a hash of tags as obtained via Dor::Item.release_tags and returns all self tags
    # @param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @return [Hash] a hash of self tags for each to value
    def get_self_release_tags(tags)
      get_tags_for_what_value(tags, 'self')
    end

    # Take an item and get all of its release tags and all tags on collections it is a member of it
    # @return [Hash] a hash of all tags
    def get_release_tags_for_item_and_all_governing_sets
      return_tags = release_nodes || {}
      collections.each do |collection|
        return_tags = combine_two_release_tag_hashes(return_tags, Dor::Item.find(collection.id).get_release_tags_for_item_and_all_governing_sets) # recurvise so parents of parents are found
      end
      return_tags
    end

    # Take two hashes of tags and combine them, will not overwrite but will enforce uniqueness of the tags
    # @param hash_one [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @param hash_two [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @return [Hash] the combined hash with uniquiness enforced
    def combine_two_release_tag_hashes(hash_one, hash_two)
      hash_two.keys.each do |key|
        hash_one[key] = hash_two[key] if hash_one[key].nil?
        hash_one[key] = (hash_one[key] + hash_two[key]).uniq unless hash_one[key].nil?
      end
      hash_one
    end

    # Take a hash of tags and return all tags with the matching what target
    # @param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @param what_target [String] the target for the 'what' key, self or collection
    # @return [Hash] a hash of self tags for each to value
    def get_tags_for_what_value(tags, what_target)
      return_hash = {}
      tags.keys.each do |key|
        self_tags = tags[key].select {|tag| tag['what'].casecmp(what_target) == 0}
        return_hash[key] = self_tags if self_tags.size > 0
      end
      return_hash
    end

    # Take a hash of tags as obtained via Dor::Item.release_tags and returns the newest tag for each namespace
    # @param tags [Hash] a hash of tags obtained via Dor::Item.release_tags or matching format
    # @return [Hash] a hash of latest tags for each to value
    def get_newest_release_tag(tags)
      Hash[tags.map {|key, val| [key, newest_release_tag_in_an_array(val)]}]
    end

    # Takes an array of release tags and returns the most recent one
    # @param array_of_tags [Array] an array of hashes, each hash a release tag
    # @return [Hash] the most recent tag
    def newest_release_tag_in_an_array(array_of_tags)
      latest_tag_in_array = array_of_tags[0] || {}
      array_of_tags.each do |tag|
        latest_tag_in_array = tag if tag['when'] > latest_tag_in_array['when']
      end
      latest_tag_in_array
    end

    # Takes a tag and returns true or false if it applies to the specific item
    # @param release_tag [Hash] the tag in a hashed form
    # @param admin_tags [Array] the administrative tags on an item, if not supplied it will attempt to retrieve them
    # @return [Boolean] true or false if it applies (not true or false if it is released, that is the release_tag data)
    def does_release_tag_apply(release_tag, admin_tags = false)
      # Is the tag global or restricted
      return true if release_tag['tag'].nil?  # no specific tag specificied means this tag is global to all members of the collection
      admin_tags = tags unless admin_tags     # We use false instead of [], since an item can have no admin_tags at which point we'd be passing this var as [] and would not attempt to retrieve it
      admin_tags.include?(release_tag['tag'])
    end

    # Takes an array of release tags and returns the most recent one that applies to this item
    # @param release_tags [Array] an array of release tags in hashed form
    # @param admin_tags [Array] the administrative tags on an on item
    # @return [Hash] the tag, or nil if none applicable
    def latest_applicable_release_tag_in_array(release_tags, admin_tags)
      newest_tag = newest_release_tag_in_an_array(release_tags)
      return newest_tag if does_release_tag_apply(newest_tag, admin_tags)

      # The latest tag wasn't applicable, slice it off and try again
      # This could be optimized by reordering on the timestamp and just running down it instead of constantly resorting, at least if we end up getting numerous release tags on an item
      release_tags.slice!(release_tags.index(newest_tag))

      return latest_applicable_release_tag_in_array(release_tags, admin_tags) if release_tags.size > 0 # Try again after dropping the inapplicable
      nil # We're out of tags, no applicable ones
    end

    # Helper method to get the release tags as a nodeset
    # @return [Nokogiri::XML::NodeSet] all release tags and their attributes
    def release_tags
      release_tags = identityMetadata.ng_xml.xpath('//release')
      return_hash = {}
      release_tags.each do |release_tag|
        hashed_node = release_tag_node_to_hash(release_tag)
        if !return_hash[hashed_node[:to]].nil?
          return_hash[hashed_node[:to]] << hashed_node[:attrs]
        else
          return_hash[hashed_node[:to]] = [hashed_node[:attrs]]
        end
      end
      return_hash
    end

    # Convert one release element into a Hash
    # @param rtag [Nokogiri::XML::Element] the release tag element
    # @return [Hash{:to, :attrs => String, Hash}] in the form of !{:to => String :attrs = Hash}
    def release_tag_node_to_hash(rtag)
      to = 'to'
      release = 'release'
      when_word = 'when' # TODO: Make to and when_word load from some config file instead of hardcoded here
      attrs = rtag.attributes
      return_hash = { :to => attrs[to].value }
      attrs.tap { |a| a.delete(to) }
      attrs[release] = rtag.text.casecmp('true') == 0 # save release as a boolean
      return_hash[:attrs] = attrs

      # convert all the attrs beside :to to strings, they are currently Nokogiri::XML::Attr
      (return_hash[:attrs].keys - [to]).each do |a|
        return_hash[:attrs][a] = return_hash[:attrs][a].to_s if a != release
      end

      return_hash[:attrs][when_word] = Time.parse(return_hash[:attrs][when_word]) # convert when to a datetime
      return_hash
    end

    # Determine if the supplied tag is a valid release tag that meets all requirements
    #
    # @param attrs [hash] A hash of attributes for the tag, must contain: :when, a ISO 8601 timestamp; :who, to identify who or what added the tag; and :to, a string identifying the release target
    # @raise [RuntimeError]  Raises an error of the first fault in the release tag
    # @return [Boolean] Returns true if no errors found
    def valid_release_attributes_and_tag(tag, attrs = {})
      raise ArgumentError, ':when is not iso8601' if attrs[:when].match('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z').nil?
      [:who, :to, :what].each do |check_attr|
        raise ArgumentError, "#{check_attr} not supplied as a String" if attrs[check_attr].class != String
      end

      what_correct = false
      %w(self collection).each do |allowed_what_value|
        what_correct = true if attrs[:what] == allowed_what_value
      end
      raise ArgumentError, ':what must be self or collection' unless what_correct
      raise ArgumentError, 'the value set for this tag is not a boolean' if !!tag != tag # rubocop:disable Style/DoubleNegation
      validate_tag_format(attrs[:tag]) unless attrs[:tag].nil? # Will Raise exception if invalid tag
      true
    end

    # Add a release node for the item
    # Will use the current time if timestamp not supplied. You can supply a timestap for correcting history, etc if desired
    # Timestamp will be calculated by the function
    #
    # @param release [Boolean] True or false for the release node
    # @param attrs [hash]  A hash of any attributes to be placed onto the tag
    # @return [Nokogiri::XML::Element] the tag added if successful
    # @raise [ArgumentError] Raised if attributes are improperly supplied
    #
    # @example
    #  item.add_release_node(true,{:tag=>'Fitch : Batch2',:what=>'self',:to=>'Searchworks',:who=>'petucket'})
    def add_release_node(release, attrs = {})
      allowed_release_attributes=[:tag,:what,:to,:who,:when] # any other release attributes sent in will be rejected and not stored
      identity_metadata_ds = identityMetadata
      attrs.delete_if { |key, value| !allowed_release_attributes.include?(key) }
      attrs[:when] = Time.now.utc.iso8601 if attrs[:when].nil? # add the timestamp
      valid_release_attributes(release, attrs)
      identity_metadata_ds.add_value(:release, release.to_s, attrs)
    end

    # Determine if the supplied tag is a valid release node that meets all requirements
    #
    # @param tag [Boolean] True or false for the release node
    # @param attrs [hash] A hash of attributes for the tag, must contain :when, a ISO 8601 timestamp and :who to identify who or what added the tag, :to,
    # @raise [ArgumentError]  Raises an error of the first fault in the release tag
    # @return [Boolean] Returns true if no errors found
    def valid_release_attributes(tag, attrs = {})
      raise ArgumentError, ':when is not iso8601' if attrs[:when].match('\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}Z').nil?
      [:who, :to, :what].each do |check_attr|
        raise ArgumentError, "#{check_attr} not supplied as a String" if attrs[check_attr].class != String
      end

      what_correct = false
      %w(self collection).each do |allowed_what_value|
        what_correct = true if attrs[:what] == allowed_what_value
      end
      raise ArgumentError, ':what must be self or collection' unless what_correct
      raise ArgumentError, 'the value set for this tag is not a boolean' if !!tag != tag # rubocop:disable Style/DoubleNegation

      validate_tag_format(attrs[:tag]) unless attrs[:tag].nil? # Will Raise exception if invalid tag
      true
    end

    # Helper method to get the release nodes as a nodeset
    # @return [Nokogiri::XML::NodeSet] of all release tags and their attributes
    def release_nodes
      release_tags = identityMetadata.ng_xml.xpath('//release')
      return_hash = {}
      release_tags.each do |release_tag|
        hashed_node = release_tag_node_to_hash(release_tag)
        if !return_hash[hashed_node[:to]].nil?
          return_hash[hashed_node[:to]] << hashed_node[:attrs]
        else
          return_hash[hashed_node[:to]] = [hashed_node[:attrs]]
        end
      end
      return_hash
    end

    # Get a list of all release nodes found in a purl document
    # Fetches purl xml for a druid
    # @raise [OpenURI::HTTPError]
    # @return [Nokogiri::HTML::Document] parsed XML for the druid or an empty document if no purl is found
    def get_xml_from_purl
      url = form_purl_url
      handler = proc do |exception, attempt_number, total_delay|
        # We assume a 404 means the document has never been published before and thus has no purl
        Dor.logger.warn "[Attempt #{attempt_number}] GET #{url} -- #{exception.class}: #{exception.message}; #{total_delay} seconds elapsed."
        raise exception unless exception.is_a? OpenURI::HTTPError
        return Nokogiri::HTML::Document.new if exception.io.status.first == '404' # ["404", "Not Found"] from OpenURI::Meta.status
      end

      with_retries(:max_retries => 3, :base_sleep_seconds => 3, :max_sleep_seconds => 5, :handler => handler) do |attempt|
        # If you change the method used for opening the webpage, you can change the :rescue param to handle the new method's errors
        Dor.logger.info "[Attempt #{attempt}] GET #{url}"
        return Nokogiri::HTML(OpenURI.open_uri(url))
      end
    end

    # Since purl does not use the druid: prefix but much of dor does, use this function to strip the druid: if needed
    # @return [String] the druid sans the druid: or if there was no druid: prefix, the entire string you passed
    def remove_druid_prefix
      druid_prefix = 'druid:'
      return id.split(druid_prefix)[1] if id.split(druid_prefix).size > 1
      druid
    end

    # Take the and create the entire purl url that will usable for the open method in open-uri, returns http
    # @return [String] the full url
    def form_purl_url
      'https://' + Dor::Config.stacks.document_cache_host + "/#{remove_druid_prefix}.xml"
    end

    # Pull all release nodes from the public xml obtained via the purl query
    # @param doc [Nokogiri::HTML::Document] The druid of the object you want
    # @return [Array] An array containing all the release tags
    def get_release_tags_from_purl_xml(doc)
      nodes = doc.xpath('//html/body/publicobject/releasedata').children
      # We only want the nodes with a name that isn't text
      nodes.reject {|n| n.name.nil? || n.name.casecmp('text') == 0 }.map {|n| n.attr('to')}.uniq
    end

    # Pull all release nodes from the public xml obtained via the purl query
    # @return [Array] An array containing all the release tags
    def get_release_tags_from_purl
      get_release_tags_from_purl_xml(get_xml_from_purl)
    end

    # This function calls purl and gets a list of all release tags currently in purl.  It then compares to the list you have generated.
    # Any tag that is on purl, but not in the newly generated list is added to the new list with a value of false.
    # @param new_tags [Hash{String => Boolean}] all new tags in the form of !{"Project" => Boolean}
    # @return [Hash] same form as new_tags, with all missing tags not in new_tags, but in current_tag_names, added in with a Boolean value of false
    def add_tags_from_purl(new_tags)
      tags_currently_in_purl = get_release_tags_from_purl
      missing_tags = tags_currently_in_purl.map(&:downcase) - new_tags.keys.map(&:downcase)
      missing_tags.each do |missing_tag|
        new_tags[missing_tag.capitalize] = {'release' => false}
      end
      new_tags
    end

    def to_solr(solr_doc = {}, *args)
      super(solr_doc, *args)

      # TODO: sort of worried about the performance impact in bulk reindex
      # situations, since released_for recurses all parent collections.  jmartin 2015-07-14
      released_for(true).each { |key, val|
        add_solr_value(solr_doc, 'released_to', key, :symbol, []) if val
      }

      # TODO: need to solrize whether item is released to purl?  does released_for return that?
      # logic is: "True when there is a published lifecycle and Access Rights is anything but Dark"

      solr_doc
    end
  end
end
