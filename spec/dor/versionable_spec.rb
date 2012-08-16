require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class VersionableItem < ActiveFedora::Base
  include Dor::Versionable
end

describe Dor::Versionable do
  describe "#open_new_version" do
    
    let(:dr) { 'ab12cd3456' }
    
    let(:obj) { 
      v = VersionableItem.new  
      v.stub!(:pid).and_return(dr)
      v
    }
    
    # before(:each) do
    #   Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
    #   Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'opened').and_return(false)
    # end
        
    it "checks if an object has been accessioned and not yet opened" do
      require 'ruby-debug'; debugger
      i = nil
      pending
      obj.open_new_version
    end
    
    it "creates the versionMetadata datastream" do
      pending
      obj.open_new_version
      obj.datastreams['versionMetadata'].ng_xml.to_xml.should =~ /Initial Version/
    end
    
    it "adds versioningWF" do
      pending
      #Dor::WorkflowService.should_receive(:create_workflow).with('dor', dr, 'versioningWF', '<xml/>')
    end
  end
end