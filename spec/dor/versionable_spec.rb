require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class VersionableItem < ActiveFedora::Base
  include Dor::Versionable
end

describe Dor::Versionable do

  let(:dr) { 'ab12cd3456' }

  let(:obj) { 
    v = VersionableItem.new  
    v.stub!(:pid).and_return(dr)
    v
  }

  let(:ds) { obj.datastreams['versionMetadata'] }

  before(:each) do
    obj.inner_object.stub!(:repository).and_return(stub('frepo').as_null_object)
  end
	
  describe "#open_new_version" do

    context "normal behavior" do
      before(:each) do        
        Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        obj.should_receive(:initialize_workflow).with('versioningWF')
        obj.stub!(:new_object?).and_return(false)
        ds.should_receive(:save)
        obj.open_new_version
      end

      it "checks if an object has been accessioned and not yet opened" do
        # checked in before block
      end

      it "creates the versionMetadata datastream" do
        ds.ng_xml.to_xml.should =~ /Initial Version/
      end

      it "adds versioningWF" do
        # checked in before block
      end
      
      it "sets the content with the new ng_xml" do
        
      end
      
      it "saves the datastream" do
        
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

  describe "#close_version" do
    it "kicks off common-accesioning" do
      pending 'just mocking calls to workflow'
    end

    it "prevents instaniating common-accessioning if version is already closed" do
      pending 'just mocking calls to workflow'
    end
    
    context "error handling" do
      it "raises an exception if the object has not been opened for versioning" do
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        lambda { obj.close_version }.should raise_error Dor::Exception
      end
      
      it "raises an exception if the object has already has an active instance of accesssionWF" do
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(Time.new)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'submitted').and_return(true)
        lambda { obj.submit_version }.should raise_error Dor::Exception
      end
    end
  end
end