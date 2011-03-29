require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')
require 'nokogiri'
require 'equivalent-xml/rspec_matchers'
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
    foxml.to_xml.should be_equivalent_to(@empty_result)
  end
  
  it "should initialize with passed values" do
    foxml = Foxml.new(@pid,@label,@model,@idm,@admin_policy_object)
    foxml.to_xml.should be_equivalent_to(@full_result)
  end
  
  it "should set values properly" do
    foxml = Foxml.new
    foxml.to_xml.should be_equivalent_to(@empty_result)
    
    foxml.pid = @pid
    foxml.to_xml.should_not be_equivalent_to(@empty_result)
    foxml.to_xml.should_not be_equivalent_to(@full_result)

    foxml.label = @label
    foxml.to_xml.should_not be_equivalent_to(@empty_result)
    foxml.to_xml.should_not be_equivalent_to(@full_result)

    foxml.content_model = @model
    foxml.to_xml.should_not be_equivalent_to(@empty_result)
    foxml.to_xml.should_not be_equivalent_to(@full_result)

    foxml.identity_metadata = @idm
    foxml.to_xml.should_not be_equivalent_to(@empty_result)
    foxml.to_xml.should_not be_equivalent_to(@full_result)

    foxml.admin_policy_object = @admin_policy_object
    foxml.to_xml.should_not be_equivalent_to(@empty_result)
    foxml.to_xml.should be_equivalent_to(@full_result)
  end
  
end
