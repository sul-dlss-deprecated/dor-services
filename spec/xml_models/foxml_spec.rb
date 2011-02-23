require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml'
require 'xml_models/foxml'

describe Foxml do
  
  before :all do
    @specdir = File.join(File.dirname(__FILE__),"..")
    @pid = 'druid:abc123def'
    @idm = Nokogiri::XML(File.read(File.join(@specdir,"test_data/identity_metadata_full.xml")))
    @admin_policy_object = 'druid:hx23ke9928'
    @label = "Foxml Test Object"
    @model = 'testObject'
    
    @empty_result = File.read(File.join(@specdir,"test_data/foxml_empty.xml"))
    @full_result = File.read(File.join(@specdir,"test_data/foxml_full.xml"))
  end
  
  it "should initialize empty" do
    foxml = Foxml.new
    EquivalentXml.equivalent?(foxml.to_xml, @empty_result).should == true
  end
  
  it "should initialize with passed values" do
    foxml = Foxml.new(@pid,@label,@model,@idm,@admin_policy_object)
    EquivalentXml.equivalent?(foxml.to_xml, @full_result).should == true
  end
  
  it "should set values properly" do
    foxml = Foxml.new
    EquivalentXml.equivalent?(foxml.to_xml, @empty_result).should == true
    
    foxml.pid = @pid
    EquivalentXml.equivalent?(foxml.to_xml, @empty_result).should == false
    EquivalentXml.equivalent?(foxml.to_xml, @full_result).should == false

    foxml.label = @label
    EquivalentXml.equivalent?(foxml.to_xml, @empty_result).should == false
    EquivalentXml.equivalent?(foxml.to_xml, @full_result).should == false

    foxml.content_model = @model
    EquivalentXml.equivalent?(foxml.to_xml, @empty_result).should == false
    EquivalentXml.equivalent?(foxml.to_xml, @full_result).should == false

    foxml.identity_metadata = @idm
    EquivalentXml.equivalent?(foxml.to_xml, @empty_result).should == false
    EquivalentXml.equivalent?(foxml.to_xml, @full_result).should == false

    foxml.admin_policy_object = @admin_policy_object
    EquivalentXml.equivalent?(foxml.to_xml, @empty_result).should == false
    EquivalentXml.equivalent?(foxml.to_xml, @full_result).should == true
  end
  
end
