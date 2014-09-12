require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class VersionableItem < ActiveFedora::Base
  include Dor::Versionable
  include Dor::Eventable
end

describe Dor::Versionable do

  let(:dr) { 'ab12cd3456' }

  let(:obj) {
    v = VersionableItem.new
    v.stub(:pid).and_return(dr)
    v
  }

  let(:vmd_ds) { obj.datastreams['versionMetadata'] }
  let(:ev_ds) { obj.datastreams['events'] }

  before(:each) do
    obj.inner_object.stub(:repository).and_return(double('frepo').as_null_object)
  end

  describe "#open_new_version" do

    context "normal behavior" do
      before(:each) do
        Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'submitted').and_return(nil)
        obj.should_receive(:initialize_workflow).with('versioningWF')
        obj.stub(:new_object?).and_return(false)
        vmd_ds.should_receive(:save)
      end

      it "checks if an object has been accessioned and not yet opened" do
        # checked in before block
        obj.open_new_version
      end

      it "creates the versionMetadata datastream" do
        vmd_ds.ng_xml.to_xml.should =~ /Initial Version/
        obj.open_new_version
      end

      it "adds versioningWF" do
        # checked in before block
        obj.open_new_version
      end

      it "sets the content with the new ng_xml" do
        obj.open_new_version
      end

      it "saves the datastream" do
        obj.open_new_version
      end

      it "includes vers_md_upd_info" do
        vers_md_upd_info = {:significance => "real_major", :description => "same as it ever was", :opening_user_name => "sunetid"}
        cur_vers = '2'
        vmd_ds.stub(:current_version).and_return(cur_vers)
        obj.stub(:save)

        ev_ds.should_receive(:add_event).with("open", vers_md_upd_info[:opening_user_name], "Version #{cur_vers} opened")
        vmd_ds.should_receive(:update_current_version).with({:description => vers_md_upd_info[:description], :significance => vers_md_upd_info[:significance].to_sym})
        obj.should_receive(:save)

        obj.open_new_version({:vers_md_upd_info => vers_md_upd_info})
      end

      it "doesn't include vers_md_upd_info" do
        ev_ds.should_not_receive(:add_event)
        vmd_ds.should_not_receive(:update_current_version)
        obj.should_not_receive(:save)

        obj.open_new_version
      end
    end

    context "error handling" do
      it "raises an exception if it the object has not yet been accessioned" do
        Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(false)
        expect { obj.open_new_version }.to raise_error(Dor::Exception, 'Object net yet accessioned')
      end

      it "raises an exception if the object has already been opened" do
        Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(Time.new)
        expect { obj.open_new_version }.to raise_error(Dor::Exception, 'Object already opened for versioning')
      end

      it "raises an exception if the object is still being accessioned" do
        Dor::WorkflowService.should_receive(:get_lifecycle).with('dor', dr, 'accessioned').and_return(true)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'submitted').and_return(Time.new)
        expect { obj.open_new_version }.to raise_error(Dor::Exception, 'Object currently being accessioned')
      end
    end
  end

  describe "#close_version" do
    it "kicks off common-accesioning" do
      pending 'just mocking calls to workflow'
    end

    it "sets versioningWF:submit-version and versioningWF:start-accession to completed" do
      pending 'just mocking calls to workflow'
    end

    it "sets tag and description if passed in as optional paramaters" do
      vmd_ds.stub(:pid).and_return('druid:ab123cd4567')
      Dor::WorkflowService.stub(:get_active_lifecycle).and_return(true, false)

      # Stub out calls to update and archive workflow
      Dor::WorkflowService.stub(:update_workflow_status)
      Dor::WorkflowService.stub(:archive_workflow)
      Dor::WorkflowService.should_receive(:close_version).with('dor', dr , true)

      obj.stub(:initialize_workflow)

      vmd_ds.increment_version
      vmd_ds.should_receive(:save)
      obj.close_version :description => 'closing text', :significance => :major

      vmd_ds.to_xml.should be_equivalent_to( <<-XML
        <versionMetadata objectId="druid:ab123cd4567">
          <version versionId="1" tag="1.0.0">
            <description>Initial Version</description>
          </version>
          <version versionId="2" tag="2.0.0">
            <description>closing text</description>
          </version>
        </versionMetadata>
      XML
      )
    end

    context "error handling" do
      it "raises an exception if the object has not been opened for versioning" do
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(nil)
        expect { obj.close_version }.to raise_error(Dor::Exception, 'Trying to close version on an object not opened for versioning')
      end

      it "raises an exception if the object has already has an active instance of accesssionWF" do
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'opened').and_return(Time.new)
        Dor::WorkflowService.should_receive(:get_active_lifecycle).with('dor', dr, 'submitted').and_return(true)
        expect { obj.submit_version }.to raise_error(Dor::Exception, 'accessionWF already created for versioned object')
      end

      it "raises an exception if the latest version does not have a tag and a description" do
        vmd_ds.increment_version
        expect { obj.close_version }.to raise_error(Dor::Exception, 'latest version in versionMetadata requires tag and description before it can be closed')
      end
    end
  end
  describe "allows_modification?" do
    it 'should allow modification if the object hasnt been submitted' do
      Dor::WorkflowService.stub(:get_lifecycle).and_return(false)
      obj.allows_modification?.should == true
    end
    it 'should allow modification if there is an open version' do
      Dor::WorkflowService.stub(:get_lifecycle).and_return(true)
      obj.stub(:new_version_open?).and_return(true)
      obj.allows_modification?.should == true
    end
    it "should allow modification if the item has sdr-ingest-transfer set to hold" do
      Dor::WorkflowService.stub(:get_lifecycle).and_return(true)
      obj.stub(:new_version_open?).and_return(false)
      Dor::WorkflowService.stub(:get_workflow_status).and_return('hold')
      obj.allows_modification?.should == true
    end
  end
end
