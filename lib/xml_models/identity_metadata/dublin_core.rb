require 'rubygems'
require 'nokogiri'

#<oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"
#xmlns:srw_dc="info:srw/schema/1/dc-schema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
#xsi:schemaLocation="http://www.openarchives.org/OAI/2.0/oai_dc/ http://cosimo.stanford.edu/standards/oai_dc/v2/oai_dc.xsd">
#  <dc:title>Life of Abraham Lincoln, sixteenth president of the United States: Containing his early
#history and political career; together with the speeches, messages, proclamations and other official
#documents illus. of his eventful administration</dc:title>
#  <dc:creator>Crosby, Frank.</dc:creator>
#  <dc:format>text</dc:format>
#  <dc:language>eng</dc:language>
#  <dc:subject>E457 .C94</dc:subject>
#  <dc:identifier>lccn:11030686</dc:identifier>
#  <dc:identifier>callseq:1</dc:identifier>
#  <dc:identifier>shelfseq:973.7111 .L731CR</dc:identifier>
#  <dc:identifier>catkey:1206382</dc:identifier>
#  <dc:identifier>barcode:36105005459602</dc:identifier>
#  <dc:identifier>uuid:ddcf5f1a-0331-4345-beca-e66f7db276eb</dc:identifier>
#  <dc:identifier>google:STANFORD_36105005459602</dc:identifier>
#  <dc:identifier>druid:ng786kn0371</dc:identifier>
#</oai_dc:dc>

class DublinCore 
  
  
  attr_accessor :xml
  
  attr_accessor :title
  attr_accessor :creator
  attr_accessor :subject
  attr_accessor :description
  attr_accessor :publisher
  attr_accessor :contributor
  attr_accessor :date
  attr_accessor :type
  attr_accessor :format
  attr_accessor :identifier
  attr_accessor :source
  attr_accessor :language
  attr_accessor :relation
  attr_accessor :coverage
  attr_accessor :rights
  



  def initialize(xml = nil)  
   
    @title ||= []  
    @creator ||= []  
    @subject ||= []  
    @description ||= []  
    @publisher ||= []  
    @contributor ||= []  
    @date ||= []  
    @type ||= []  
    @format ||= []  
    @identifier ||= []  
    @source ||= []  
    @language ||= []  
    @relation ||= []  
    @coverage ||= []   
    @rights ||= []
    
    # if the new is given an xml string, store that in the xml attr_accessor and don't rebuild.
    # this will allow users to access the raw unprocessed  XML string via @xml. 
    if xml.nil?
      build_xml()
    else
      @xml = xml
    end
      
  end #initalize
  
  
  def build_xml()
      builder = Nokogiri::XML::Builder.new do |xml|
        xml.dc('xmlns:dc' => 'http://purl.org/dc/elements/1.1/', 'xmlns:srw_dc' => 'info:srw/schema/1/dc-schema', "xmlns:xsi" => "http://www.w3.org/2001/XMLSchema-instance"   ) {
          xml.parent.namespace = xml.parent.add_namespace_definition('oai_dc','http://www.openarchives.org/OAI/2.0/oai_dc/')
          xml.parent.add_namespace_definition("xsi:schemaLocation", "http://www.openarchives.org/OAI/2.0/oai_dc/ http://cosimo.stanford.edu/standards/oai_dc/v2/oai_dc.xsd")
          self.instance_variables.each do |var|
            unless var == "@xml"         
              self.instance_variable_get(var).each { |v| xml['dc'].send("#{var.gsub('@','')}_", v) }
            end #unless
          end #instance_Variables.each
        }
      end
      @xml = builder.to_xml
  end
  
  
  
  # This method rebuilds the xml attr_accesor and returns it as a string.   
  def to_xml
    build_xml
    return self.xml
  end #to_xml


  # This method takes DC XML as a string, and maps the root child node to their proper attr_accesor. 
  
  def self.from_xml(xml="")
    dc = DublinCore.new(xml)
    doc = Nokogiri::XML(xml)
    children = doc.root.element_children
    children.each do |c|
      if dc.instance_variables.include?("@#{c.name}")
        dc.send("#{c.name}").send("<<", c.text.strip)
      end #if
    end  #each
    return dc
  end #from_xml


  
end #dublin_core
