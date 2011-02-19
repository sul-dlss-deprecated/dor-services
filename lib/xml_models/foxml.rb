require 'rubygems'
require 'nokogiri'

# TODO: Rewrite in OM

class Foxml
  attr_reader :xml

  NAMESPACES = {
    "dc"           => "http://purl.org/dc/elements/1.1/", 
    "fedora-model" => "info:fedora/fedora-system:def/model#", 
    "foxml"        => "info:fedora/fedora-system:def/foxml#",
    "oai_dc"       => "http://www.openarchives.org/OAI/2.0/oai_dc/", 
    "rdf"          => "http://www.w3.org/1999/02/22-rdf-syntax-ns#", 
    "rel"          => "info:fedora/fedora-system:def/relations-external#"
  } 
  
  def initialize(pid=nil, label=nil, content_model=nil, identity_metadata=nil)
    @xml = Nokogiri::XML(XML_TEMPLATE) { |config| config.default_xml.noblanks }
    self.pid = pid.to_s
    self.label = label.to_s
    self.content_model = content_model.to_s
    self.identity_metadata = identity_metadata
  end

  def pid
    self.xpath('/foxml:digitalObject/@PID').first.value
  end
  
  def pid=(value)
    self.xpath('/foxml:digitalObject/@PID').first.value = value
    self.get_datastream("RELS-EXT","rdf:RDF/rdf:Description/@rdf:about").value = "info:fedora/#{value}"
  end

  def content_model
    self.get_datastream("RELS-EXT","rdf:RDF/rdf:Description/fedora-model:hasModel/@rdf:resource").value
  end
  
  def content_model=(value)
    self.get_datastream("RELS-EXT","rdf:RDF/rdf:Description/fedora-model:hasModel/@rdf:resource").value = "info:fedora/#{value}"
  end
  
  def dublin_core
    self.get_datastream("DC","oai_dc:dc")
  end
  
  def dublin_core=(value)
    self.set_datastream("DC",value,'<oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"/>')
  end
  
  def identity_metadata
    self.get_datastream("identityMetadata","identityMetadata")
  end
  
  def identity_metadata=(value)
    $stderr.puts(value)
    self.set_datastream("identityMetadata",value,"<identityMetadata/>")
    # strip the namespace Nokogiri attaches to identityMetadata
    self.get_datastream("identityMetadata","*[local-name()='identityMetadata']").traverse { |n| n.namespace = nil }
  end
  
  def label
    self.xpath('//foxml:property[@NAME="info:fedora/fedora-system:def/model#label"]/@VALUE').first
  end
  
  def label=(value)
    self.xpath('//foxml:property[@NAME="info:fedora/fedora-system:def/model#label"]/@VALUE').first.value = value
    if existing_title = self.get_datastream("DC","//dc:title")
      existing_title.remove
    end
    self.dublin_core.add_child('<dc:title/>')
    self.get_datastream("DC","//dc:title").content = value
  end
  
  def get_datastream(ds_name, *paths)
    result = self.xpath(%{//foxml:datastream[@ID="#{ds_name}"]/foxml:datastreamVersion/foxml:xmlContent}).first
    paths.each do |path|
      result = result.xpath(path, NAMESPACES).first
    end
    return result
  end
  
  def set_datastream(ds_name, new_value, nil_value = nil)
    new_value ||= nil_value
    if new_value.is_a?(Nokogiri::XML::Node)
      new_value = new_value.clone
    end
    parent = self.get_datastream(ds_name)
    parent.children.each { |c| c.remove }
    unless new_value.nil?
      parent.add_child(new_value)
    end
  end
  
  def xpath(path)
    @xml.xpath(path, NAMESPACES)
  end
  
  def method_missing(sym,*args)
    if @xml.respond_to?(sym)
      @xml.send(sym,*args)
    end
  end
  
  XML_TEMPLATE = %{
<?xml version="1.0" encoding="UTF-8"?>
<foxml:digitalObject PID="$$PID$$" VERSION="1.1"
  xmlns:foxml="info:fedora/fedora-system:def/foxml#"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="info:fedora/fedora-system:def/foxml# http://www.fedora.info/definitions/1/0/foxml1-1.xsd">
  <foxml:objectProperties>
    <foxml:property NAME="info:fedora/fedora-system:def/model#state" VALUE="Active"/>
    <foxml:property NAME="info:fedora/fedora-system:def/model#label" VALUE="$$LABEL$$"/>
    <foxml:property NAME="info:fedora/fedora-system:def/model#ownerId" VALUE="dor"/>
  </foxml:objectProperties>
  <foxml:datastream CONTROL_GROUP="X" ID="DC" STATE="A" VERSIONABLE="false">
    <foxml:datastreamVersion
      FORMAT_URI="http://www.openarchives.org/OAI/2.0/oai_dc/" ID="DC1.0"
      LABEL="Dublin Core Record for this object" MIMETYPE="text/xml">
        <foxml:xmlContent>
          <oai_dc:dc xmlns:dc="http://purl.org/dc/elements/1.1/" xmlns:oai_dc="http://www.openarchives.org/OAI/2.0/oai_dc/"/>
        </foxml:xmlContent>
    </foxml:datastreamVersion>
  </foxml:datastream>
  <foxml:datastream CONTROL_GROUP="X" ID="identityMetadata" STATE="A" VERSIONABLE="false">
    <foxml:datastreamVersion
      ID="identityMetadata.0" LABEL="Identity Metadata" MIMETYPE="text/xml">
        <foxml:xmlContent>
          <identityMetadata/>
        </foxml:xmlContent>
    </foxml:datastreamVersion>
  </foxml:datastream>
  <foxml:datastream CONTROL_GROUP="X" ID="RELS-EXT" STATE="A">
    <foxml:datastreamVersion
      FORMAT_URI="info:fedora/fedora-system:FedoraRELSExt-1.0" ID="RELS-EXT.0"
      LABEL="RDF Statements about this object" MIMETYPE="application/rdf+xml">
        <foxml:xmlContent>
          <rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" 
              xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#" xmlns:rel="info:fedora/fedora-system:def/relations-external#">
              <rdf:Description rdf:about="info:fedora/$$PID$$">
                <fedora-model:hasModel rdf:resource="info:fedora/$$MODEL$$"/>
              </rdf:Description>
        </rdf:RDF>
      </foxml:xmlContent>
    </foxml:datastreamVersion>
  </foxml:datastream>
</foxml:digitalObject>
}.strip

end