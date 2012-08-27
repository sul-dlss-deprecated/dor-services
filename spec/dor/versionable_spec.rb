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
    
    context "normal behavior" do
      before(:each) do
        Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        obj.should_receive(:initialize_workflow).with('versioningWF')
        obj.open_new_version
      end

      it "checks if an object has been accessioned and not yet opened" do
        # checked in before block
      end

      it "creates the versionMetadata datastream" do
        obj.datastreams['versionMetadata'].ng_xml.to_xml.should =~ /Initial Version/
      end

      it "adds versioningWF" do
        # checked in before block
      end
    end
    
    context "error handling" do
      it "raises an exception if it the object has not yet been accessioned" do
        Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(false)
        lambda { obj.open_new_version }.should raise_error Dor::Exception
      end
      
      it "raises an exception if the object has already been opened" do
        Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(Time.new)
        lambda { obj.open_new_version }.should raise_error Dor::Exception
      end
    end
  
    
  end
end