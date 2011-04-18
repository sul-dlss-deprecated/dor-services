require 'rubygems'
require 'nokogiri'
#<identityMetadata>
#     <objectId>druid:rt923jk342</objectId>
#     <objectType>item</objectType>
#     <objectLabel>google download barcode 36105049267078</objectLabel>
#     <objectCreator>DOR</objectCreator>
#     <citationTitle>Squirrels of North America</citationTitle>
#     <citationCreator>Eder, Tamara, 1974-</citationCreator>
#     <sourceId source="google">STANFORD_342837261527</sourceId>
#     <otherId name="barcode">342837261527</otherId>
#     <otherId name="catkey">129483625</otherId>
#     <otherId name="uuid">7f3da130-7b02-11de-8a39-0800200c9a66</otherId>
#     <tag>Google Books : Phase 1</tag>
#     <tag>Google Books : Scan source STANFORD</tag>
#</identityMetadata>

# TODO: Rewrite in OM

# this just maps the #value method to return the "text", "source", "name" values form the hash
class SourceId
  attr_reader :source
  attr_reader :value
  
  def xml_values
    [self.value, {:source => self.source}]
  end

  def source=(val)
    @source = val.nil? ? nil : val.to_s
  end
  
  def value=(val)
    @value = val.nil? ? nil : val.to_s
  end
  
  def to_s
    "#{self.source}:#{self.value}"
  end
  
  def empty?
    (self.source.nil? || self.source.empty?) && (self.value.nil? || self.value.empty?)
  end
  
end

class OtherId 
  attr_reader :name
  attr_reader :value
  
  def xml_values
   [self.value, {:name => self.name}]
  end
  
  def name=(val)
    @name = val.nil? ? nil : val.to_s
  end
  
  def value=(val)
    @value = val.nil? ? nil : val.to_s
  end
  
  def to_s
    "#{self.name}:#{self.value}"
  end
  
  def empty?
    (self.name.nil? || self.name.empty?) && (self.value.nil? || self.value.empty?)
  end
  
end

class Tag
  attr_accessor :value
  
  def xml_values
    [self.value]
  end
end


class IdentityMetadata
  
  
  
  # these are single values
  attr_accessor :objectId
  attr_reader :sourceId, :tags
  # these instance vars map to nodes in the identityMetadata XML
  attr_accessor :objectTypes, :objectLabels, :objectCreators, :citationCreators, :citationTitle, 
                :otherIds, :adminPolicy
  # this stores the Nokogiri XML
  attr_reader :ng_xml
  
  
  def initialize(xml = nil)  
    
     @objectId, @citationTitle, @adminPolicy = "", "", "" #there can only be one of these values
     @sourceId = SourceId.new #there can be only one. 
     @otherIds, @tags = [], [] # this is an array that will be filled with OtherId and Tag objects
     @objectTypes, @objectLabels, @objectCreators, @citationCreators =  [], [], [], []
      
  
     # if the new is given an xml string, store that in the xml attr_accessor and don't rebuild.
     # this will allow users to access the raw unprocessed  XML string via @xml. 
     if xml.nil?
       build_xml()
     else
       @xml = xml
     end
  end #def init
  
  #this builds the xml based on the instance variables in the object. If it's a hash, this assumes that we want to 
  #use attributes ==> {"text"=> "7f3da130-7b02-11de-8a39-0800200c9a66", "name" => "uuid" }. If the instance var is 
  # an array, we assume we don't need attrs, so all values get put into the text node. 
  def build_xml()
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.identityMetadata {
          self.instance_variables.each do |var_name|
            unless var_name == "@xml"
              var = self.instance_variable_get(var_name)
              tag_name = var_name[1..-1]
              if var.is_a?(Array)
                tag_name.chomp!('s')
              end
              # wrap the singleton properties in a one-element array
              var = Array(var)
              var.each do |v| 
                if v.respond_to?(:xml_values)
                  unless (v.respond_to?(:empty?) && v.empty?)
                    xml.send(tag_name, *(v.xml_values))
                  end
                else
                  xml.send(tag_name, v.to_s)
                end
              end #var.each
            end #unless
          end #instance_variables.each
        }
      end
      @ng_xml = builder.doc
  end

  def xml
    @ng_xml.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION, :indent => 2)
  end
  
  def xml=(value)
    @ng_xml = Nokogiri::XML(value)
  end
  
  # This method rebuilds the xml attr_accesor and returns it as a string.   
  def to_xml
    build_xml
    return self.xml
  end #to_xml
  
  #
  # The following methods are convience methods 
  #
  
  
  # Add a new tag to the IdentityMetadata instance
   def add_tag(new_tag_value)
     # Make sure tag is not already present
     unless self.get_tags.include?(new_tag_value)
       tag = Tag.new
       tag.value = new_tag_value
       self.tags << tag
     end
     return self.get_tags   
   end
   
   alias :tag :add_tag
   
   # Returns an array of tag values
  def get_tags()
     self.tags.collect { |t| t.value }
  end
     
   
  # Return the OtherId hash for the specified identier name
   def get_other_id(name)
     self.otherIds.each do |oi|
       if oi.name == name
         return oi
       end
     end
     return nil
   end
       
   # Return the identifier value for the specified identier name
   def get_identifier_value(key)
     other_id = self.get_other_id(key)
     if other_id != nil && other_id.value != nil
       return other_id.value
     end
     raise "No #{key} indentifier found for druid #{@objectId}"
   end
     
   # Add a new name,value pair to the set of identifiers
   def add_identifier(*args)
     (key,value) = args.collect { |arg| arg.to_s }
     if value.nil? and key =~ /:/
       (key,value) = key.split(/:/,2)
     end
     
     other_id = self.get_other_id(key)
     if (other_id != nil)
       other_id.value = value
     else
       other_id = OtherId.new
       other_id.name = key
       other_id.value = value
       @otherIds << other_id
     end
   end
   
   def sourceId=(value)
     if value.nil?
       @sourceId.source = nil
       @sourceId.value = nil
     else
       (source,value) = value.split(/:/,2)
     
       @sourceId.source = source
       @sourceId.value = value
     end
   end
   
   # Return an array of strings where each entry consists of name:value
   def get_id_pairs
     pairs=Array.new  
     self.otherIds.collect do |other_id|
         other_id.to_s
     end
   end
  
  #another convience method to allow citationCreator=
  def citationCreator=(creator)
    if creator.is_a?(Array)
      self.citationCreators = creator
    elsif creator.is_a?(String)
      self.citationCreators = [creator]
    else
      raise "Identity_metadata.citationCreator requires either a string or array. "
    end
  end
  
  #takes a string of XML and constructs the object with all the instance variables added to the correct location. 
  def self.from_xml(xml="")
     if xml.is_a?(File)
       xml = xml.read
     end
        
     im = self.new(xml)
     doc = Nokogiri::XML(xml)
     
     children = doc.root.element_children #iterate through the nodes and map them to instance vars in the object. 
     children.each do |c|
       if im.instance_variables.include?("@#{c.name}") or im.instance_variables.include?("@#{c.name}s")
         if c.name == "sourceId" #SourceID already has a SourceID object made
           im.sourceId.source = c["source"]
           im.sourceId.value = c.text.strip
         elsif c.name == "otherId" #otherID needs to be cast as an object and stored in an array
           im.add_identifier(c['name'],c.text.strip)
         elsif c.name == "tag" #tags also need to have objects created and stored in an array
           im.add_tag(c.text.strip)
         elsif c.name == "objectId" # objectId needs to be mapped to objectId attr_access
           im.objectId = c.text.strip
         elsif c.name == "citationTitle" #citationTitle also needs to be mapped to citationTitle attr_accessor
           im.citationTitle = c.text.strip
         elsif c.name == "adminPolicy"
           im.adminPolicy = c.text.strip
         else # everything else gets put into an attr_accessor array (note the added 's' on the attr_accessor.)
           im.send("#{c.name}s").send("<<", c.text.strip)
         end #if
       end #if
     end  #each
     
     return im
  
  end #from_xml
  
end #class IdentityMetadata