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
			dc_doc = xslt.transform(self.datastreams['descMetadata'].ng_xml)
			# Remove empty nodes
			dc_doc.xpath('/oai_dc:dc/*[count(text()) = 0]').remove
			if(dc_doc.root.nil? || dc_doc.root.children.size == 0)
				raise CrosswalkError, "Dor::Item#generate_dublin_core produced incorrect xml:\n#{dc_doc.to_xml}"
			end
			dc_doc
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
			add_solr_value(solr_doc, "metadata_format", self.metadata_format, :string, [:searchable, :facetable])
			begin
				dc_doc = self.generate_dublin_core
				dc_doc.xpath('/oai_dc:dc/*').each do |node|
					add_solr_value(solr_doc, "public_dc_#{node.name}", node.text, :string, [:searchable])
				end
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
				if(ds.content.length>30 and force==false)#22 is the length of <?xml version="1.0"?>
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
		
	end
end
