# frozen_string_literal: true

require 'spec_helper'

describe Dor::SearchService do
  before(:each) { stub_config }
  after(:each)  { unstub_config }

  before do
    RSolr::Client.default_wt = :ruby
  end

  context '.risearch' do
    before :each do
      @druids = [
        ['druid:rk464yc0651', 'druid:xx122nh4588', 'druid:mj151qw9093', 'druid:mn144df7801', 'druid:rx565mb6270'],
        ['druid:tx361mw6047', 'druid:cm977wg2520', 'druid:tk695fn1971', 'druid:jk486qb3656', 'druid:cd252xn6059'], []
      ]
      @responses = @druids.collect { |group| { body: %("object"\n) + group.collect { |d| "info:fedora/#{d}" }.join("\n") } }
      stub_request(:post, 'http://localhost:8983/fedora/risearch')
        .to_return(body: @responses[0][:body]).then
        .to_return(body: @responses[1][:body]).then
        .to_return(body: @responses[2][:body])
    end

    it 'should execute a proper resource index search' do
      query = 'select $object from <#ri> where $object <info:fedora/fedora-system:def/model#label> $label'
      # encoded = 'select%20%24object%20from%20%3C%23ri%3E%20where%20%24object%20%3Cinfo%3Afedora%2Ffedora-system%3Adef%2Fmodel%23label%3E%20%24label'
      resp = Dor::SearchService.risearch(query, limit: 5)
      expect(resp).to eq(@druids[0])
      resp = Dor::SearchService.risearch(query, limit: 5, offset: 5)
      expect(resp).to eq(@druids[1])
    end

    it 'should iterate over pids in groups' do
      receiver = double('block')
      expect(receiver).to receive(:process).with(@druids[0])
      expect(receiver).to receive(:process).with(@druids[1])
      Dor::SearchService.iterate_over_pids(in_groups_of: 5, mode: :group) { |x| receiver.process(x) }
    end

    it 'should iterate over pids one at a time' do
      receiver = double('block')
      @druids.flatten.each { |druid| expect(receiver).to receive(:process).with(druid) }
      Dor::SearchService.iterate_over_pids(in_groups_of: 5, mode: :single) { |x| receiver.process(x) }
    end
  end

  context '.query' do
    let(:solr_field) { Solrizer.solr_name('dor_id', :stored_searchable) }
    before :each do
      solr_url = "http://solr.edu/solrizer/select?fl=id&q=#{solr_field}%3A%22barcode%3A9191919191%22&rows=14&wt=ruby"
      solr_resp = +<<-EOF
        {'responseHeader'=>
          {'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'0','q'=>'#{solr_field}:"barcode:9191919191"','wt'=>'ruby','rows'=>'14'}},
          'response'=>{'numFound'=>5,'start'=>0,
            'docs'=>[{'id'=>'druid:ab123cd4567'},{'id'=>'druid:pq873fk5453'},{'id'=>'druid:qd999th4309'},{'id'=>'druid:zq003hm6082'},{'id'=>'druid:qr731mn8989'},{'id'=>'druid:vs117gg5172'},{'id'=>'druid:br354rp8638'},{'id'=>'druid:bw800dd6481'},{'id'=>'druid:mb617xf5467'},{'id'=>'druid:wq764nz3597'},{'id'=>'druid:hb776qq7561'},{'id'=>'druid:tj809bn3855'},{'id'=>'druid:yn121yc8869'},{'id'=>'druid:yw068nb3128'}]}}
      EOF
      stub_request(:get, "#{solr_url}&start=0").to_return(body: solr_resp)
      solr_resp = +<<-EOF
        {'responseHeader'=>
          {'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'14','q'=>'#{solr_field}:"barcode:9191919191"','wt'=>'ruby','rows'=>'14'}},
            'response'=>{'numFound'=>3,'start'=>14,
              'docs'=>[{'id'=>'druid:pr800pd9407'},{'id'=>'druid:hd475xb8847'},{'id'=>'druid:rr637mh2957'},{'id'=>'druid:kz965vx0963'},{'id'=>'druid:th985vs8378'},{'id'=>'druid:sm255pn4484'},{'id'=>'druid:sy394vn4752'},{'id'=>'druid:qs376gx5152'},{'id'=>'druid:dv587vy1434'},{'id'=>'druid:db089gk0831'},{'id'=>'druid:ss837xm7768'}]}}
      EOF
      stub_request(:get, "#{solr_url}&start=14").to_return(body: solr_resp)
      solr_resp = +<<-EOF
        {'responseHeader'=>
          {'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'28','q'=>'#{solr_field}:"barcode:9191919191"','wt'=>'ruby','rows'=>'14'}},
            'response'=>{'numFound'=>0,'docs'=>[]}}
      EOF
      stub_request(:get, "#{solr_url}&start=28").to_return(body: solr_resp)
    end

    it 'should return a single batch of docs without a block' do
      resp = Dor::SearchService.query(solr_field + ':"barcode:9191919191"', fl: 'id', rows: 14)
      expect(resp['response']['docs'].length).to eq(14)
    end

    it 'should yield multiple batches of docs with a block' do
      batch = [14, 11]
      Dor::SearchService.query(solr_field + ':"barcode:9191919191"', fl: 'id', rows: 14) do |resp|
        expect(resp['response']['docs'].length).to eq(batch.shift)
      end
    end
  end

  context '.query_by_id' do
    before :each do
      @pid = 'druid:ab123cd4567'
    end

    it 'should look up an object based on any of its IDs' do
      id = 'barcode:9191919191'
      solr_field = Solrizer.solr_name('identifier', :symbol)
      solr_url = "http://solr.edu/solrizer/select?fl=id&q=%7B%21term+f%3D#{solr_field}%7Dbarcode%3A9191919191&defType=lucene&rows=1000&wt=ruby"
      solr_resp = +<<-EOF
      {'responseHeader'=>
        {'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'0','q'=>'dor_id_t:"barcode:9191919191"','wt'=>'ruby','rows'=>'1000'}},
          'response'=> {'numFound'=>5,'start'=>0,
            'docs'=>[
                  {'id'=>'druid:pq873fk5453'},
                  {'id'=>'druid:qd999th4309'},
                  {'id'=>'#{@pid}'},
                  {'id'=>'druid:zq003hm6082'},
                  {'id'=>'druid:qr731mn8989'},
                  ]}}
      EOF
      stub_request(:get, "#{solr_url}&start=0").to_return(body: solr_resp)
      solr_resp = +<<-EOF
      {'responseHeader'=>
        {'status'=>0,'QTime'=>1,'params'=>{'fl'=>'id','start'=>'25','q'=>'dor_id_t:"barcode:9191919191"','wt'=>'ruby','rows'=>'1000'}},
          'response'=>{'numFound'=>5,'start'=>5,'docs'=>[]}}
      EOF
      stub_request(:get, "#{solr_url}&start=1000").to_return(body: solr_resp)
      result = Dor::SearchService.query_by_id(id)
      expect(result.size).to eq(5)
      expect(result).to include(@pid)
    end
  end

  context '.solr' do
    it 'should use an RSolr connection' do
      solr = Dor::SearchService.solr
      expect(solr).to be_a(RSolr::Client)
    end
  end
end
