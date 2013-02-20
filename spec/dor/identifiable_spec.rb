require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

class IdentifiableItem < ActiveFedora::Base
  include Dor::Identifiable
end

describe Dor::Identifiable do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before :each do
    @item = instantiate_fixture('druid:ab123cd4567', IdentifiableItem)
  	@obj=@item
  end

  it "should have an identityMetadata datastream" do
    @item.datastreams['identityMetadata'].should be_a(Dor::IdentityMetadataDS)
  end
  describe 'set_source_id' do
    it 'should set the source_id if one doesnt exist' do
      @obj.identityMetadata.sourceId.should == 'google:STANFORD_342837261527'
      @obj.set_source_id('fake:sourceid')
      @obj.identityMetadata.sourceId.should == 'fake:sourceid'
    end
    it 'should replace the source_id if one exists' do
      @obj.set_source_id('fake:sourceid')
      @obj.identityMetadata.sourceId.should == 'fake:sourceid'
      @obj.set_source_id('new:sourceid2')
      @obj.identityMetadata.sourceId.should == 'new:sourceid2'
    end
  end

  describe 'add_other_Id' do
    it 'should add an other_id record' do
      @obj.add_other_Id('mdtoolkit','someid123')
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
    end
    it 'should raise an exception if a record of that type already exists' do
      @obj.add_other_Id('mdtoolkit','someid123')
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      lambda{@obj.add_other_Id('mdtoolkit','someid123')}.should raise_error
    end
  end

  describe 'update_other_Id' do
    it 'should update an existing id and return true to indicate that it found something to update' do
      @obj.add_other_Id('mdtoolkit','someid123')
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      #return value should be true when it finds something to update
      @obj.update_other_Id('mdtoolkit','someotherid234','someid123').should == true
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someotherid234'
    end
    it 'should return false if there was no existing record to update' do
      @obj.update_other_Id('mdtoolkit','someotherid234').should == false
    end
  end

  describe 'remove_other_Id' do
    it 'should remove an existing otherid when the tag and value match' do
      @obj.add_other_Id('mdtoolkit','someid123')
      @obj.identityMetadata.otherId('mdtoolkit').first.should == 'someid123'
      @obj.remove_other_Id('mdtoolkit','someid123').should == true
      @obj.identityMetadata.otherId('mdtoolkit').length.should == 0
      @obj.identityMetadata.dirty?.should == true
    end
    it 'should return false if there was nothing to delete' do
      @obj.remove_other_Id('mdtoolkit','someid123').should == false
      @obj.identityMetadata.dirty?.should == false
    end
  end

  describe 'add_tag' do
    it 'should add a new tag' do
      @obj.add_tag('sometag:someval')
      @obj.identityMetadata.tags().include?('sometag:someval').should == true
      @obj.identityMetadata.dirty?.should == true
    end
    it 'should raise an exception if there is an existing tag like it' do
      @obj.add_tag('sometag:someval')
      @obj.identityMetadata.tags().include?('sometag:someval').should == true
      lambda {@obj.add_tag('sometag:someval')}.should raise_error
    end
  end
  describe 'update_tag' do
    it 'should update a tag' do
      @obj.add_tag('sometag:someval')
      @obj.identityMetadata.tags().include?('sometag:someval').should == true
      @obj.update_tag('sometag:someval','new:tag').should == true
      @obj.identityMetadata.tags().include?('sometag:someval').should == false
      @obj.identityMetadata.tags().include?('new:tag').should == true
      @obj.identityMetadata.dirty?.should == true
    end
    it 'should return false if there is no matching tag to update' do
      @obj.update_tag('sometag:someval','new:tag').should == false
      @obj.identityMetadata.dirty?.should == false
    end
  end
  describe 'delete_tag' do
    it 'should delete a tag' do
    @obj.add_tag('sometag:someval')
    @obj.identityMetadata.tags().include?('sometag:someval').should == true
    @obj.remove_tag('sometag:someval').should == true
    @obj.identityMetadata.tags().include?('sometag:someval').should == false
    @obj.identityMetadata.dirty?.should == true
    end
  end
  describe 'to_solr' do
    it 'should generate collection and apo title fields' do
      xml='<rdf:RDF xmlns:fedora-model="info:fedora/fedora-system:def/model#" xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"
            xmlns:fedora="info:fedora/fedora-system:def/relations-external#" xmlns:hydra="http://projecthydra.org/ns/relations#">
            <rdf:Description rdf:about="info:fedora/druid:ab123cd4567">
              <fedora-model:hasModel rdf:resource="info:fedora/testObject"/>
              <hydra:isGovernedBy rdf:resource="info:fedora/druid:fg890hi1234"/>
            </rdf:Description>
          </rdf:RDF>'
      @obj.datastreams['RELS-EXT'].stub(:content).and_return(xml)
      doc=@obj.to_solr
      doc['apo_title_facet'].first.should == 'druid:fg890hi1234'
    end
  end
end
