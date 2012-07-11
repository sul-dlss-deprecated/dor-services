require File.expand_path(File.dirname(__FILE__) + '/../spec_helper')

describe Dor::SearchService do
  before :all do
    stub_config
  end
  
  after :all do
    unstub_config
  end

  context "indexing functions" do
    before :each do
      FakeWeb.allow_net_connect = false
      FakeWeb.register_uri(:get, 'http://fedora.edu/gsearch/rest/?action=fromPid&operation=updateIndex&value=druid:bb110sm8219', :body => 'OK')
      FakeWeb.register_uri(:get, 'http://fedora.edu/gsearch/rest/?action=fromPid&operation=updateIndex&value=druid:bb110sm8210', :body => 'OK')
    end
    
    after :each do
      FakeWeb.clean_registry
      FakeWeb.allow_net_connect = true
    end
    
    it "should report an index version" do
      Dor::SearchService.index_version.should =~ /\d+\.\d+\.\d+/
    end
    
    it "should reindex PIDs" do
      result = Dor::SearchService.reindex('druid:bb110sm8219','druid:bb110sm8210') do |group|
        group.should == ['druid:bb110sm8219','druid:bb110sm8210']
      end
      result.should == ['druid:bb110sm8219','druid:bb110sm8210']
    end
  end

  context ".risearch" do
    before :each do
      FakeWeb.allow_net_connect = false
      @druids = [['druid:rk464yc0651','druid:xx122nh4588','druid:mj151qw9093','druid:mn144df7801','druid:rx565mb6270'],['druid:tx361mw6047','druid:cm977wg2520','druid:tk695fn1971','druid:jk486qb3656','druid:cd252xn6059'],[]]
      responses = @druids.collect { |group| { :body => %{"object"\n} + group.collect { |d| "info:fedora/#{d}" }.join("\n") } }
      FakeWeb.register_uri(:post, 'http://fedora.edu/fedora/risearch', responses)
    end
    
    after :each do
      FakeWeb.clean_registry
      FakeWeb.allow_net_connect = true
    end

    it "should execute a proper resource index search" do
      query = 'select $object from <#ri> where $object <info:fedora/fedora-system:def/model#label> $label'
      encoded = 'select%20%24object%20from%20%3C%23ri%3E%20where%20%24object%20%3Cinfo%3Afedora%2Ffedora-system%3Adef%2Fmodel%23label%3E%20%24label'
      resp = Dor::SearchService.risearch(query, :limit => 5)
      resp.should == @druids[0]
      params = FakeWeb.last_request.body.split(/&/)
      params.should include("query=#{encoded}")
      params.should include("limit=5")
      resp = Dor::SearchService.risearch(query, :limit => 5, :offset => 5)
      params = FakeWeb.last_request.body.split(/&/)
      params.should include("query=#{encoded}")
      params.should include("limit=5")
      params.should include("offset=5")
      resp.should == @druids[1]
    end
    
    it "should iterate over pids in groups" do
      receiver = mock('block')
      receiver.should_receive(:process).with(@druids[0])
      receiver.should_receive(:process).with(@druids[1])
      Dor::SearchService.iterate_over_pids(:in_groups_of => 5, :mode => :group) { |x| receiver.process(x) }
    end

    it "should iterate over pids one at a time" do
      receiver = mock('block')
      @druids.flatten.each { |druid| receiver.should_receive(:process).with(druid) }
      Dor::SearchService.iterate_over_pids(:in_groups_of => 5, :mode => :single) { |x| receiver.process(x) }
    end
  end
  
  context ".query" do
    before :each do
      ruby_responses = [
        %{{'responseHeader'=>{'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'0','q'=>'dor_id_t:"barcode:9191919191"','wt'=>'ruby','rows'=>'14'}},'response'=>{'numFound'=>14,'start'=>0,'docs'=>[{'id'=>'druid:ab123cd4567'},{'id'=>'druid:pq873fk5453'},{'id'=>'druid:qd999th4309'},{'id'=>'druid:zq003hm6082'},{'id'=>'druid:qr731mn8989'},{'id'=>'druid:vs117gg5172'},{'id'=>'druid:br354rp8638'},{'id'=>'druid:bw800dd6481'},{'id'=>'druid:mb617xf5467'},{'id'=>'druid:wq764nz3597'},{'id'=>'druid:hb776qq7561'},{'id'=>'druid:tj809bn3855'},{'id'=>'druid:yn121yc8869'},{'id'=>'druid:yw068nb3128'}]}}},
        %{{'responseHeader'=>{'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'14','q'=>'dor_id_t:"barcode:9191919191"','wt'=>'ruby','rows'=>'14'}},'response'=>{'numFound'=>11,'start'=>14,'docs'=>[{'id'=>'druid:pr800pd9407'},{'id'=>'druid:hd475xb8847'},{'id'=>'druid:rr637mh2957'},{'id'=>'druid:kz965vx0963'},{'id'=>'druid:th985vs8378'},{'id'=>'druid:sm255pn4484'},{'id'=>'druid:sy394vn4752'},{'id'=>'druid:qs376gx5152'},{'id'=>'druid:dv587vy1434'},{'id'=>'druid:db089gk0831'},{'id'=>'druid:ss837xm7768'}]}}},
        %{{'responseHeader'=>{'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'28','q'=>'dor_id_t:"barcode:9191919191"','wt'=>'ruby','rows'=>'14'}},'response'=>{'numFound'=>0,'docs'=>[]}}}
      ]
      FakeWeb.register_uri(:get, "http://solr.edu/solrizer/select?fl=id&q=dor_id_t%3A%22barcode%3A9191919191%22&rows=14&start=0&wt=ruby", :body => ruby_responses[0])
      FakeWeb.register_uri(:get, "http://solr.edu/solrizer/select?fl=id&q=dor_id_t%3A%22barcode%3A9191919191%22&rows=14&start=14&wt=ruby", :body => ruby_responses[1])
      FakeWeb.register_uri(:get, "http://solr.edu/solrizer/select?fl=id&q=dor_id_t%3A%22barcode%3A9191919191%22&rows=14&start=28&wt=ruby", :body => ruby_responses[2])
      FakeWeb.allow_net_connect = false
    end

    after :each do
      FakeWeb.clean_registry
      FakeWeb.allow_net_connect = true
    end
    
    it "should return a single batch of docs without a block" do
      resp = Dor::SearchService.query('dor_id_t:"barcode:9191919191"', :fl => 'id', :rows => 14)
      resp.docs.length.should == 14
    end
    
    it "should yield multiple batches of docs with a block" do
      batch = [14,11]
      Dor::SearchService.query('dor_id_t:"barcode:9191919191"', :fl => 'id', :rows => 14) do |resp|
        resp.docs.length.should == batch.shift
      end
    end
  end
  
  context ".query_by_id" do
    before :each do
      @pid = 'druid:ab123cd4567'
      FakeWeb.allow_net_connect = false
    end

    after :each do
      FakeWeb.clean_registry
      FakeWeb.allow_net_connect = true
    end
    
    it "should look up an object based on any of its IDs" do
      ruby_responses = [
        %{{'responseHeader'=>{'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'0','q'=>'dor_id_t:"barcode:9191919191"','wt'=>'ruby','rows'=>'1000'}},'response'=>{'numFound'=>25,'start'=>0,'docs'=>[{'id'=>'#{@pid}'},{'id'=>'druid:pq873fk5453'},{'id'=>'druid:qd999th4309'},{'id'=>'druid:zq003hm6082'},{'id'=>'druid:qr731mn8989'},{'id'=>'druid:vs117gg5172'},{'id'=>'druid:br354rp8638'},{'id'=>'druid:bw800dd6481'},{'id'=>'druid:mb617xf5467'},{'id'=>'druid:wq764nz3597'},{'id'=>'druid:hb776qq7561'},{'id'=>'druid:tj809bn3855'},{'id'=>'druid:yn121yc8869'},{'id'=>'druid:yw068nb3128'},{'id'=>'druid:pr800pd9407'},{'id'=>'druid:hd475xb8847'},{'id'=>'druid:rr637mh2957'},{'id'=>'druid:kz965vx0963'},{'id'=>'druid:th985vs8378'},{'id'=>'druid:sm255pn4484'},{'id'=>'druid:sy394vn4752'},{'id'=>'druid:qs376gx5152'},{'id'=>'druid:dv587vy1434'},{'id'=>'druid:db089gk0831'},{'id'=>'druid:ss837xm7768'}]}}},
        %{{'responseHeader'=>{'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'25','q'=>'dor_id_t:"barcode:9191919191"','wt'=>'ruby','rows'=>'1000'}},'response'=>{'numFound'=>25,'start'=>25,'docs'=>[]}}}
      ]
      id = 'barcode:9191919191'
      FakeWeb.register_uri(:get, "http://solr.edu/solrizer/select?fl=id&q=identifier_t%3A%22barcode%3A9191919191%22&rows=1000&start=0&wt=ruby", :body => ruby_responses[0])
      FakeWeb.register_uri(:get, "http://solr.edu/solrizer/select?fl=id&q=identifier_t%3A%22barcode%3A9191919191%22&rows=1000&start=1000&wt=ruby", :body => ruby_responses[1])
      result = Dor::SearchService.query_by_id(id)
      result.should have(25).things
      result.should include(@pid)
    end
    
    it "should perform a solr search" do
      json_response = '{"responseHeader":{"status":0,"QTime":2,"params":{"wt":"json","rows":"2","facet":"on","q":"object_type_field:item","facet.field":["project_tag_facet","isMemberOfCollection_id_facet"]}},"response":{"numFound":36297,"start":0,"docs":[{"google_book_tag_field":["GBS VIEW_FULL"],"fgs_state_field":["Active"],"dor_id_field":["google:STANFORD_36105041665204","catkey:2195171","shelfseq:VK 000023.9 .W98","barcode:36105041665204","callseq:1","uuid:c2990e40-f874-460c-a422-bb89f673e4af"],"dc_creator_text":["Wyman, Edwin Allen , 1834-"],"fedora_has_model_field":["info:fedora/dor:googleScannedBookWF"],"namespace_facet":["druid"],"dor_callseq_id_field":["1"],"object_type_field":["item"],"book_tag_field":["US pre-1923"],"dor_barcode_id_field":["36105041665204"],"google_book_tag_facet":["GBS VIEW_FULL"],"id":["druid:qf334vs2122"],"fgs_ownerId_field":["dor"],"PID":["druid:qf334vs2122"],"fgs_lastModifiedDate_date":["2010-11-17T00:46:31.478Z"],"dc_subject_field":["PZ3.W982 S"],"dc_title_text":["Ships by day: a novel"],"book_tag_facet":["US pre-1923"],"namespace_field":["druid"],"tag_field":["Google Book : GBS VIEW_FULL","Book : US pre-1923"],"wf_wsp_facet":["googleScannedBookWF"],"index_version_field":["1.1.2011092802"],"fgs_label_field":["Google Scanned Book, barcode 36105041665204"],"dor_uuid_id_field":["c2990e40-f874-460c-a422-bb89f673e4af"],"tag_facet":["Google Book : GBS VIEW_FULL","Book : US pre-1923"],"source_id_field":["STANFORD_36105041665204"],"dc_identifier_text":["lccn:09001474","catkey:2195171","shelfseq:VK 000023.9 .W98","barcode:36105041665204","callseq:1","uuid:c2990e40-f874-460c-a422-bb89f673e4af","google:STANFORD_36105041665204","druid:qf334vs2122"],"fgs_createdDate_date":["2010-11-10T17:59:43.055Z"],"link_text_display":["Ships by day: a novel"],"dc_format_field":["text"],"dc_title_field":["Ships by day: a novel"],"identifier_text":["google:STANFORD_36105041665204","STANFORD_36105041665204"],"dc_creator_field":["Wyman, Edwin Allen , 1834-"],"dc_language_field":["eng"],"dor_shelfseq_id_field":["VK 000023.9 .W98"],"wf_wps_facet":["googleScannedBookWF"],"dc_identifier_field":["lccn:09001474","catkey:2195171","shelfseq:VK 000023.9 .W98","barcode:36105041665204","callseq:1","uuid:c2990e40-f874-460c-a422-bb89f673e4af","google:STANFORD_36105041665204","druid:qf334vs2122"],"dor_catkey_id_field":["2195171"],"wf_facet":["googleScannedBookWF"]},{"dor_id_field":["google:STANFORD_36105041665600","catkey:2195217","shelfseq:VK 000140 .F69 A3 1882","barcode:36105041665600","callseq:1","uuid:2203bb83-dfa5-42e9-a56c-0d0e18a58af7"],"mods_extent_field":["x, 412 p. front., plates, ports. 20 cm."],"mods_titleInfo_field":["Personal reminiscences"],"fedora_has_model_field":["info:fedora/dor:googleScannedBookWF"],"dc_creator_text":["Forbes, R. B. (Robert Bennet) , 1804-1889"],"dor_callseq_id_field":["1"],"object_type_field":["item"],"hasModel_id_field":["dor:googleScannedBookWF"],"google_book_tag_facet":["GBS VIEW_FULL"],"dor_barcode_id_field":["36105041665600"],"id":["druid:vq381hc4720"],"mods_name_text":["Forbes, R. B. (Robert Bennet)"],"fgs_lastModifiedDate_date":["2010-11-12T19:26:55.404Z"],"PID":["druid:vq381hc4720"],"dc_title_text":["Personal reminiscences"],"book_tag_facet":["US pre-1923"],"namespace_field":["druid"],"mods_publisher_text":["Little, Brown, and Company"],"index_version_field":["1.3.2011110101"],"mods_sul_resource_id_identifier_text":["druid:vq381hc4720"],"mods_publisher_field":["Little, Brown, and Company"],"link_text_display":["Personal reminiscences"],"dc_format_field":["text"],"dc_title_field":["Personal reminiscences"],"mods_creator_field":["Forbes, R. B. (Robert Bennet)"],"dc_creator_field":["Forbes, R. B. (Robert Bennet) , 1804-1889"],"mods_sul_resource_id_identifier_field":["druid:vq381hc4720"],"fedora_datastream_version_field":["AUDIT.0","RELS-EXT.0","googleScannedBookWF.0","descMetadata.0","DC.1","identityMetadata.1"],"mods_title_text":["Personal reminiscences"],"dor_catkey_id_field":["2195217"],"mods_origininfo_place_field":["Boston"],"fgs_state_field":["Active"],"google_book_tag_field":["GBS VIEW_FULL"],"hasModel_id_facet":["dor:googleScannedBookWF"],"mods_dateissued_field":["1882","1882"],"mods_creator_text":["Forbes, R. B. (Robert Bennet)"],"namespace_facet":["druid"],"book_tag_field":["US pre-1923"],"mods_recordcreationdate_field":["750311","2010-11-12T11:26:54.941-08:00"],"fgs_ownerId_field":["dor"],"mods_identifier_field":["SUL Resource ID:druid:vq381hc4720"],"tag_field":["Google Book : GBS VIEW_FULL","Book : US pre-1923"],"mods_identifier_text":["SUL Resource ID:druid:vq381hc4720"],"mods_name_field":["Forbes, R. B. (Robert Bennet)"],"wf_wsp_facet":["googleScannedBookWF"],"fgs_label_field":["Google Scanned Book, barcode 36105041665600"],"dor_uuid_id_field":["2203bb83-dfa5-42e9-a56c-0d0e18a58af7"],"tag_facet":["Google Book : GBS VIEW_FULL","Book : US pre-1923"],"source_id_field":["STANFORD_36105041665600"],"fgs_createdDate_date":["2010-11-10T18:01:16.359Z"],"dc_identifier_text":["catkey:2195217","shelfseq:VK 000140 .F69  A3  1882","barcode:36105041665600","callseq:1","uuid:2203bb83-dfa5-42e9-a56c-0d0e18a58af7","google:STANFORD_36105041665600","druid:vq381hc4720"],"identifier_text":["google:STANFORD_36105041665600","STANFORD_36105041665600"],"dc_language_field":["eng"],"mods_origininfo_place_text":["Boston"],"dor_shelfseq_id_field":["VK 000140 .F69 A3 1882"],"wf_wps_facet":["googleScannedBookWF"],"dc_identifier_field":["catkey:2195217","shelfseq:VK 000140 .F69  A3  1882","barcode:36105041665600","callseq:1","uuid:2203bb83-dfa5-42e9-a56c-0d0e18a58af7","google:STANFORD_36105041665600","druid:vq381hc4720"],"mods_recordchangedate_field":["19920507074137.0"],"wf_facet":["googleScannedBookWF"]}]},"facet_counts":{"facet_queries":{},"facet_fields":{"project_tag_facet":["Parker Manuscripts",556,"McLaughlin Maps",424,"Stanford Oral History Project",302,"SOHP",100,"Kitai",18,"Carolee Schneemann",6,"BnF Manuscripts",3,"Special Collections Requests",1,"Stephen J. Gould Rare Books",1,"DOR",0],"isMemberOfCollection_id_facet":["druid:zb871zd0767",5,"druid:gj309bn0813",3]},"facet_dates":{}}}'
      FakeWeb.register_uri(:get, 'http://solr.edu/gsearch/select?facet=on&facet.field=isMemberOfCollection_id_facet&facet.field=project_tag_facet&q=object_type_field:item&rows=2&wt=json', :body => json_response)
      real_response = Dor::SearchService.gsearch :q => 'object_type_field:item', :rows => 2, :facet => 'on', :'facet.field' => ['isMemberOfCollection_id_facet','project_tag_facet']
      real_response.should == JSON.parse(json_response)
    end
    
  end
  
  context ".solr" do
    it "should use an RSolr connection" do
      solr = Dor::SearchService.solr
      solr.should be_a(RSolr::Client)
      solr.connection.should be_a(RSolr::ClientCert::Connection)
    end
  end

end
