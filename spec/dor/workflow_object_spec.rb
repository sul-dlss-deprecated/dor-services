require 'spec_helper'

describe Dor::WorkflowObject do

  # before :all do
  #   Dor::Config.push! { suri.mint_ids false }
  #   ActiveFedora.stub(:fedora).and_return(stub('frepo').as_null_object)
  #   FakeWeb.allow_net_connect = false
  # end
  # 
  # after :all do
  #   FakeWeb.allow_net_connect = true
  #   Dor::Config.pop
  # end
  # 
  # after :each do
  #   FakeWeb.clean_registry
  # end
  # 
  # it "should be findable by name" do
  #   pending
  #   solr_response = JSON.parse('{"responseHeader":{"status":0,"QTime":2,"params":{"q":"object_type_field:workflow dc_title_field:accessionWF","wt":"json"}},"response":{"numFound":1,"start":0,"docs":[{"dc_creator_field":["DOR"],"tag_field":["Project : DOR"],"namespace_facet":["druid"],"PID":["druid:tm388wy6148"],"fgs_lastModifiedDate_date":["2011-10-26T23:24:00.253Z"],"fgs_label_field":["accessionWF"],"fgs_state_field":["Active"],"dc_creator_text":["DOR"],"id":["druid:tm388wy6148"],"dor_uuid_id_field":["9446c4fe-0029-11e1-b134-dc2b61fffec6"],"object_type_field":["workflow"],"project_tag_facet":["DOR"],"dc_identifier_text":["druid:tm388wy6148"],"tag_facet":["Project : DOR"],"link_text_display":["accessionWF"],"hasModel_id_field":["afmodel:Dor_WorkflowObject"],"project_tag_field":["DOR"],"fgs_ownerId_field":["fedoraAdmin"],"dor_id_field":["uuid:9446c4fe-0029-11e1-b134-dc2b61fffec6"],"fgs_createdDate_date":["2011-10-26T23:23:57.961Z"],"index_version_field":["1.2.2011092901"],"dc_title_field":["accessionWF"],"dc_identifier_field":["druid:tm388wy6148"],"hasModel_id_facet":["afmodel:Dor_WorkflowObject"],"dc_title_text":["accessionWF"],"fedora_has_model_field":["info:fedora/afmodel:Dor_WorkflowObject"],"namespace_field":["druid"]}]}}')
  #   empty_response = JSON.parse('{"responseHeader":{"status":0,"QTime":4,"params":{"q":"object_type_field:workflow dc_title_field:missingWF","wt":"json"}},"response":{"numFound":0,"start":0,"docs":[]}}')
  #   FakeWeb.register_uri(:get, 'http://dor-dev.stanford.edu/solr/select?q=object_type_field:workflow%20dc_title_field:%22accessionWF%22&wt=json', :body => solr_response)
  #   FakeWeb.register_uri(:get, %r[http://dor-dev\.stanford\.edu/select/?\?.+], :body => empty_response)
  #   Dor::WorkflowObject.stub(:load_instance, Dor::WorkflowObject.new)
  #   Dor::WorkflowObject.find_by_name('accessionWF').should be_kind_of(Dor::WorkflowObject)
  #   Dor::WorkflowObject.find_by_name('missingWF').should be_nil
  # end
  
  # return @@xml_cache[name] if(@@xml_cache.include?(name))
  # 
  # wobj = self.find_by_name(name)
  # wf_xml = wobj.generate_intial_workflow
  # @@xml_cache[name] = wf_xml
  # wf_xml
  
  describe ".initial_workflow" do
    it "caches the intial workflow xml for subsequent requests" do
      wobj = double('workflow_object').as_null_object
      Dor::WorkflowObject.should_receive(:find_by_name).once.and_return(wobj)

      # First call, object not in cache
      Dor::WorkflowObject.initial_workflow('accessionWF')
      # Second call, object in cache
      Dor::WorkflowObject.initial_workflow('accessionWF').should == wobj
    end
  end
  
end
