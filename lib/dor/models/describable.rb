module Dor
	module Describable
		extend ActiveSupport::Concern

		DESC_MD_FORMATS = {
			"http://www.tei-c.org/ns/1.0" => 'tei',
			"http://www.loc.gov/mods/v3" =>	 'mods'
		}
		class CrosswalkError < Exception; end

		included do
			has_metadata :name => "descMetadata", :type => Dor::DescMetadataDS, :label => 'Descriptive Metadata', :control_group => 'M'
		end

		def fetch_descMetadata_datastream
			candidates = self.datastreams['identityMetadata'].otherId.collect { |oid| oid.to_s }
			metadata_id = Dor::MetadataService.resolvable(candidates).first
			unless metadata_id.nil?
				return Dor::MetadataService.fetch(metadata_id.to_s)
			else
				return nil
			end
		end

		def build_descMetadata_datastream(ds)
			content = fetch_descMetadata_datastream
			unless content.nil?
				ds.dsLabel = 'Descriptive Metadata'
				ds.ng_xml = Nokogiri::XML(content)
				ds.ng_xml.normalize_text!
				ds.content = ds.ng_xml.to_xml
			end
		end

		# Generates Dublin Core from the MODS in the descMetadata datastream using the LoC mods2dc stylesheet
		#		Should not be used for the Fedora DC datastream
		# @raise [Exception] Raises an Exception if the generated DC is empty or has no children
		def generate_dublin_core
			format = self.metadata_format
			if format.nil?
				raise CrosswalkError, "Unknown descMetadata namespace: #{metadata_namespace.inspect}"
			end
			xslt = Nokogiri::XSLT(File.new(File.expand_path(File.dirname(__FILE__) + "/#{format}2dc.xslt")) )
			desc_md = self.descMetadata.ng_xml.dup(1)
			self.add_collection_reference(desc_md)
			dc_doc = xslt.transform(desc_md)
			# Remove empty nodes
			dc_doc.xpath('/oai_dc:dc/*[count(text()) = 0]').remove
			if(dc_doc.root.nil? || dc_doc.root.children.size == 0)
				raise CrosswalkError, "Dor::Item#generate_dublin_core produced incorrect xml:\n#{dc_doc.to_xml}"
			end
			dc_doc
		end

    def generate_public_desc_md
      doc = self.descMetadata.ng_xml.dup(1)
      add_collection_reference(doc)
      add_access_conditions(doc)
      new_doc = Nokogiri::XML(doc.to_xml) { |x| x.noblanks }
      new_doc.encoding = 'UTF-8'
      new_doc.to_xml
	  end

    # Create MODS accessCondition statements from rightsMetadata
    # @param [Nokogiri::XML::Document] doc Document representing the descriptiveMetadata of the object
    # @note this method modifies the passed in doc
    def add_access_conditions(doc)
      # clear out any existing accessConditions
      doc.xpath('//mods:accessCondition', 'mods' => 'http://www.loc.gov/mods/v3').each {|n| n.remove}
      rights = self.datastreams['rightsMetadata'].ng_xml

      rights.xpath('//use/human[@type="useAndReproduction"]').each do |use|
        txt = use.text.strip
        next if txt.empty?
        new_use =  doc.create_element("accessCondition", use.text.strip, :type => 'useAndReproduction')
        doc.root.element_children.last.add_next_sibling new_use
      end
      rights.xpath('//copyright/human[@type="copyright"]').each do |cr|
        txt = cr.text.strip
        next if txt.empty?
        new_use =  doc.create_element("accessCondition", cr.text.strip, :type => 'copyright')
        doc.root.element_children.last.add_next_sibling new_use
      end
      rights.xpath("//use/machine[#{ci_compare('type', 'creativecommons')}]").each do |lic_type|
        next if lic_type.text =~ /none/i
        lic_text = rights.at_xpath("//use/human[#{ci_compare('type', 'creativecommons')}]").text.strip
        next if lic_text.empty?
        new_text = "CC #{lic_type.text}: #{lic_text}"
        new_lic =  doc.create_element("accessCondition", new_text, :type => 'license')
        doc.root.element_children.last.add_next_sibling new_lic
      end
      rights.xpath("//use/machine[#{ci_compare('type', 'opendatacommons')}]").each do |lic_type|
        next if lic_type.text =~ /none/i
        lic_text = rights.at_xpath("//use/human[#{ci_compare('type', 'opendatacommons')}]").text.strip
        next if lic_text.empty?
        new_text = "ODC #{lic_type.text}: #{lic_text}"
        new_lic =  doc.create_element("accessCondition", new_text, :type => 'license')
        doc.root.element_children.last.add_next_sibling new_lic
      end
	  end

    # returns the desc metadata a relatedItem with information about the collection this object belongs to for use in published mods and mods to DC conversion
    # @param [Nokogiri::XML::Document] doc A copy of the descriptiveMetadata of the object
    # @note this method modifies the passed in doc
    def add_collection_reference(doc)
	    return unless self.methods.include? :public_relationships
	    collections=self.public_relationships.search('//rdf:RDF/rdf:Description/fedora:isMemberOfCollection',
	                                     'fedora' => 'info:fedora/fedora-system:def/relations-external#',
	                                     'rdf' => 'http://www.w3.org/1999/02/22-rdf-syntax-ns#' )
	    return if collections.empty?

	    # Remove any existing collections in the descMetadata
      doc.search('/mods:mods/mods:relatedItem[@type="host"]/mods:typeOfResource[@collection=\'yes\']', 'mods' => 'http://www.loc.gov/mods/v3').each do |node|
        node.parent.remove
      end

      collections.each do |collection_node|
        druid=collection_node['rdf:resource']
        druid=druid.gsub('info:fedora/','')
        collection_obj=Dor::Item.find(druid)
        collection_title = Dor::Describable.get_collection_title(collection_obj)
        related_item_node=Nokogiri::XML::Node.new('relatedItem',doc)
        related_item_node['type']='host'
        title_info_node=Nokogiri::XML::Node.new('titleInfo',doc)
        title_node=Nokogiri::XML::Node.new('title',doc)
        title_node.content=collection_title

        id_node=Nokogiri::XML::Node.new('identifier',doc)
        id_node['type'] = 'uri'
        id_node.content = "http://#{Dor::Config.stacks.document_cache_host}/#{druid.split(':').last}"

        type_node=Nokogiri::XML::Node.new('typeOfResource',doc)
        type_node['collection'] = 'yes'
        doc.root.add_child(related_item_node)
        related_item_node.add_child(title_info_node)
        title_info_node.add_child(title_node)
        related_item_node.add_child(id_node)
        related_item_node.add_child(type_node)
      end
    end
		def metadata_namespace
			desc_md = self.datastreams['descMetadata'].ng_xml
			if desc_md.nil? or desc_md.root.nil? or desc_md.root.namespace.nil?
				return nil
			else
				return desc_md.root.namespace.href
			end
		end

		def metadata_format
			DESC_MD_FORMATS[metadata_namespace]
		end

		def to_solr(solr_doc=Hash.new, *args)
			super solr_doc, *args
			add_solr_value(solr_doc, "metadata_format", self.metadata_format, :string, [:symbol, :searchable, :facetable])
			begin
				dc_doc = self.generate_dublin_core
				dc_doc.xpath('/oai_dc:dc/*').each do |node|
					add_solr_value(solr_doc, "public_dc_#{node.name}", node.text, :string, [:stored_searchable])
				end
				creator=''
				dc_doc.xpath('//dc:creator').each do |node|
				  creator=node.text
				end
				title=''
				dc_doc.xpath('//dc:title').each do |node|
				  title=node.text
				end
        creator_title=creator+title
        add_solr_value(solr_doc, 'creator_title', creator_title , :string, [:sortable])
			rescue CrosswalkError => e
				ActiveFedora.logger.warn "Cannot index #{self.pid}.descMetadata: #{e.message}"
			end
			solr_doc
		end
		def update_title(new_title)
				if not update_simple_field('mods:mods/mods:titleInfo/mods:title',new_title)
					raise 'Descriptive metadata has no title to update!'
				end
			end
			def add_identifier(type, value)
				ds_xml=self.descMetadata.ng_xml
				ds_xml.search('//mods:mods','mods' => 'http://www.loc.gov/mods/v3').each do |node|
				new_node=Nokogiri::XML::Node.new('identifier',ds_xml) #this ends up being mods:identifier without having to specify the namespace
				new_node['type']=type
				new_node.content=value
				node.add_child(new_node)
				end
			end
			def delete_identifier(type,value=nil)

				ds_xml=self.descMetadata.ng_xml
				ds_xml.search('//mods:identifier','mods' => 'http://www.loc.gov/mods/v3').each do |node|
					if node.content == value or value==nil
						node.remove
						return true
					end
				end
				return false
			end

			def set_desc_metadata_using_label(force=false)
				ds=self.descMetadata
				unless force or ds.new?#22 is the length of <?xml version="1.0"?>
					raise 'Cannot proceed, there is already content in the descriptive metadata datastream.'+ds.content.to_s
				end
				label=self.label
				builder = Nokogiri::XML::Builder.new { |xml|
				xml.mods( 'xmlns' => 'http://www.loc.gov/mods/v3', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',:version => '3.3', "xsi:schemaLocation" => 'http://www.loc.gov/mods/v3 http://www.loc.gov/standards/mods/v3/mods-3-3.xsd'){
					xml.titleInfo{
						xml.title label
						}
					}
				}
				self.descMetadata.content=builder.to_xml
			end

			def self.get_collection_title(obj)
			  xml=obj.descMetadata.ng_xml
			  title=''
        title_node = xml.at_xpath('//mods:mods/mods:titleInfo/mods:title','mods' => 'http://www.loc.gov/mods/v3')
        if(title_node)
          title = title_node.content
		      subtitle=xml.at_xpath('//mods:mods/mods:titleInfo/mods:subTitle','mods' => 'http://www.loc.gov/mods/v3')
		      if(subtitle)
		        title += ' (' + subtitle.content + ')'
	        end
	      end
	      title
		  end

			private
			#generic updater useful for updating things like title or subtitle which can only have a single occurance and must be present
			def update_simple_field(field,new_val)
				ds_xml=self.descMetadata.ng_xml
				ds_xml.search('//'+field,'mods' => 'http://www.loc.gov/mods/v3').each do |node|
					node.content=new_val
					return true
				end
				return false
			end

			# Builds case-insensitive xpath translate function call that will match the attribute to a value
			def ci_compare(attribute, value)
          "translate(
              @#{attribute},
              'ABCDEFGHIJKLMNOPQRSTUVWXYZ',
              'abcdefghijklmnopqrstuvwxyz'
            ) = '#{value}' "
			end


	end
end
