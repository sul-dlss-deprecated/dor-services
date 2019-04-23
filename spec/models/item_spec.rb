# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Item do
  before do
    @item   = instantiate_fixture('druid:ab123cd4567', described_class)
    @obj    = instantiate_fixture('druid:ab123cd4567', described_class)
    @obj.datastreams['descMetadata'].content = read_fixture('ex1_mods.xml')
  end

  describe '#allows_modification?' do
    let(:dr) { 'ab12cd3456' }
    let(:obj) { described_class.new(pid: dr) }
    let(:vmd_ds) { obj.datastreams['versionMetadata'] }
    let(:ev_ds) { obj.datastreams['events'] }

    before do
      allow(obj.inner_object).to receive(:repository).and_return(double('frepo').as_null_object)
    end

    it "allows modification if the object hasn't been submitted" do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(false)
      expect(obj).to be_allows_modification
    end

    it 'allows modification if there is an open version' do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(true)
      allow(Dor::Config.workflow.client).to receive(:active_lifecycle).and_return(true)
      expect(obj).to be_allows_modification
    end

    it 'allows modification if the item has sdr-ingest-transfer set to hold' do
      allow(Dor::Config.workflow.client).to receive(:lifecycle).and_return(true)
      allow(Dor::Config.workflow.client).to receive(:active_lifecycle).and_return(false)
      allow(Dor::Config.workflow.client).to receive(:workflow_status).and_return('hold')
      expect(obj).to be_allows_modification
    end
  end

  describe '#to_solr' do
    subject(:doc) { item.to_solr }

    let(:item) { described_class.new(pid: 'foo:123') }

    let(:wf_indexer) { instance_double(Dor::WorkflowsIndexer, to_solr: {}) }
    let(:process_indexer) { instance_double(Dor::ProcessableIndexer, to_solr: {}) }

    before do
      allow(Dor::WorkflowsIndexer).to receive(:new).and_return(wf_indexer)
      allow(Dor::ProcessableIndexer).to receive(:new).and_return(process_indexer)
    end

    it { is_expected.to include 'active_fedora_model_ssi' => 'Dor::Item' }
  end

  describe '#descMetadata' do
    let(:item) { described_class.new(pid: 'foo:123') }

    it 'has a descMetadata datastream' do
      expect(item.descMetadata).to be_a(Dor::DescMetadataDS)
    end
  end

  describe '#stanford_mods' do
    let(:item) { described_class.new(pid: 'foo:123') }

    before do
      item.descMetadata.content = read_fixture('ex1_mods.xml')
    end

    it 'fetches Stanford::Mods object' do
      expect(item.methods).to include(:stanford_mods)
      sm = nil
      expect { sm = item.stanford_mods }.not_to raise_error
      expect(sm).to be_kind_of(Stanford::Mods::Record)
      expect(sm.format_main).to eq(['Book'])
      expect(sm.pub_year_sort_str).to eq('1911')
    end

    it 'allows override argument(s)' do
      sm = nil
      nk = Nokogiri::XML('<mods><genre>ape</genre></mods>')
      expect { sm = item.stanford_mods(nk, false) }.not_to raise_error
      expect(sm).to be_kind_of(Stanford::Mods::Record)
      expect(sm.genre.text).to eq('ape')
      expect(sm.pub_year_sort_str).to be_nil
    end
  end

  describe 'contentMetadata' do
    let(:item) { described_class.new(pid: 'foo:123') }

    it 'has a contentMetadata datastream' do
      expect(item.contentMetadata).to be_a(Dor::ContentMetadataDS)
    end
  end

  describe 'the dsLocation for workflow' do
    let(:obj) { described_class.new }
    before do
      allow(Dor::Config.workflow.client).to receive(:all_workflows_xml).and_return('<workflows />')
      allow(Dor::SuriService).to receive(:mint_id).and_return('changeme:1231231')
      allow(Dor::Config.suri).to receive(:mint_ids).and_return(true)
      allow(obj).to receive(:update_index)
      obj.save!
    end

    let(:reloaded) { described_class.find(obj.pid) }
    let(:workflows) { reloaded.workflows }

    it 'is set automatically' do
      expect(workflows.dsLocation).to eq 'https://workflow.example.edu/dor/objects/changeme:1231231/workflows'
      expect(workflows.mimeType).to eq 'application/xml'
    end
  end

  describe '#workflows' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    before do
      stub_config
      item.contentMetadata.content = '<contentMetadata/>'
    end

    it 'has a workflows datastream and workflows shortcut method' do
      expect(item.datastreams['workflows']).to be_a(Dor::WorkflowDs)
      expect(item.workflows).to eq(item.datastreams['workflows'])
    end

    it 'loads its content directly from the workflow service' do
      expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows/>')
      expect(item.workflows.content).to eq('<workflows/>')
    end

    it 'is able to invalidate the cache of its content' do
      expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows/>')
      expect(item.workflows.content).to eq('<workflows/>')
      expect(item.workflows.content).to eq('<workflows/>') # should be cached copy
      expect(Dor::Config.workflow.client).to receive(:all_workflows_xml).with('druid:ab123cd4567').and_return('<workflows>with some data</workflows>')
      # pass refresh flag and should be refreshed copy
      expect(item.workflows.content(true)).to eq('<workflows>with some data</workflows>')
      expect(item.workflows.content).to eq('<workflows>with some data</workflows>')
    end
  end

  describe '#identityMetadata' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    it 'has an identityMetadata datastream' do
      expect(item.datastreams['identityMetadata']).to be_a(Dor::IdentityMetadataDS)
    end
  end

  describe '#source_id' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    it 'source_id fetches from IdentityMetadata' do
      expect(item.source_id).to eq('google:STANFORD_342837261527')
      expect(item.source_id).to eq(item.identityMetadata.sourceId)
    end
  end

  describe '#source_id= (AKA set_source_id)' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    it 'raises on unsalvageable values' do
      expect { item.source_id = 'NotEnoughColons' }.to raise_error ArgumentError
      expect { item.source_id = ':EmptyFirstPart' }.to raise_error ArgumentError
      expect { item.source_id = 'WhitespaceSecondPart:   ' }.to raise_error ArgumentError
    end
    it 'sets the source_id' do
      item.source_id = 'fake:sourceid'
      expect(item.identityMetadata.sourceId).to eq('fake:sourceid')
    end
    it 'replaces the source_id if one exists' do
      item.source_id = 'fake:sourceid'
      expect(item.identityMetadata.sourceId).to eq('fake:sourceid')
      item.source_id = 'new:sourceid2'
      expect(item.identityMetadata.sourceId).to eq('new:sourceid2')
    end
    it 'does normalization via identityMetadata.sourceID=' do
      item.source_id = ' SourceX :  Value Y  '
      expect(item.source_id).to eq('SourceX:Value Y')
    end
    it 'allows colons in the value' do
      item.source_id = 'one:two:three'
      expect(item.source_id).to eq('one:two:three')
      item.source_id = 'one::two::three'
      expect(item.source_id).to eq('one::two::three')
    end
    it 'deletes the sourceId node on nil or empty-string' do
      item.source_id = nil
      expect(item.source_id).to be_nil
      item.source_id = 'fake:sourceid'
      expect(item.source_id).to eq('fake:sourceid')
      item.source_id = ''
      expect(item.source_id).to be_nil
    end
  end

  describe '#catkey' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    let(:current_catkey) { '129483625' }
    let(:new_catkey) { '999' }

    it 'gets the current catkey with the convenience method' do
      expect(item.catkey).to eq(current_catkey)
    end
    it 'gets the previous catkeys with the convenience method' do
      expect(item.previous_catkeys).to eq([])
    end
    it 'updates the catkey when one exists, and store the previous value (when there is no current history yet)' do
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(current_catkey)
      expect(item.previous_catkeys).to be_empty
      item.catkey = new_catkey
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(new_catkey)
      expect(item.previous_catkeys.length).to eq(1)
      expect(item.previous_catkeys).to eq([current_catkey])
    end
    it 'adds the catkey when it does not exist and never did' do
      item.identityMetadata.remove_other_Id('catkey')
      expect(item.identityMetadata.otherId('catkey').length).to eq(0)
      expect(item.catkey).to be_nil
      expect(item.previous_catkeys).to be_empty
      item.catkey = new_catkey
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(new_catkey)
      expect(item.previous_catkeys).to be_empty
    end
    it 'adds the catkey when it does not currently exist and there is a previous history (not touching that)' do
      item.identityMetadata.remove_other_Id('catkey')
      expect(item.identityMetadata.otherId('catkey').length).to eq(0)
      expect(item.catkey).to be_nil
      item.identityMetadata.add_otherId('previous_catkey:123') # add a couple previous catkeys
      item.identityMetadata.add_otherId('previous_catkey:456')
      expect(item.previous_catkeys.length).to eq(2)
      item.catkey = new_catkey
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(new_catkey)
      expect(item.previous_catkeys.length).to eq(2) # still two entries, nothing changed in the history
      expect(item.previous_catkeys).to eq(%w[123 456])
    end
    it 'removes the catkey from the XML when it is set to blank, but store the previously set value in the history' do
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(current_catkey)
      expect(item.previous_catkeys).to be_empty
      item.catkey = ''
      expect(item.identityMetadata.otherId('catkey').length).to eq(0)
      expect(item.catkey).to be_nil
      expect(item.previous_catkeys.length).to eq(1)
      expect(item.previous_catkeys).to eq([current_catkey])
    end

    it 'updates the catkey when one exists, and add the previous catkey id to the list' do
      previous_catkey = '111'
      item.identityMetadata.add_other_Id('previous_catkey', previous_catkey)
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(current_catkey)
      expect(item.previous_catkeys.length).to eq(1)
      expect(item.previous_catkeys.first).to eq(previous_catkey)
      item.catkey = new_catkey
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(new_catkey)
      expect(item.previous_catkeys.length).to eq(2)
      expect(item.previous_catkeys).to eq([previous_catkey, current_catkey])
    end

    it 'does not do anything if there is a previous catkey and you set the catkey to the same value' do
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(current_catkey)
      expect(item.previous_catkeys).to be_empty # no previous catkeys
      item.catkey = current_catkey
      expect(item.identityMetadata.otherId('catkey').length).to eq(1)
      expect(item.catkey).to eq(current_catkey)
      expect(item.previous_catkeys).to be_empty # still empty, we haven't updated the previous catkey since it was the same
    end
  end

  describe '#remove_druid_prefix' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    it 'removes the druid prefix if it is present' do
      expect(item.remove_druid_prefix).to eq('ab123cd4567')
    end

    it 'removes the druid prefix for an arbitrary druid passed in' do
      expect(item.remove_druid_prefix('druid:oo000oo0001')).to eq('oo000oo0001')
    end

    it 'leaves the string unchanged if the druid prefix is already stripped' do
      expect(item.remove_druid_prefix('oo000oo0001')).to eq('oo000oo0001')
    end

    it 'justs return the input string if there are no matches' do
      expect(item.remove_druid_prefix('bogus')).to eq('bogus')
    end
  end

  describe '#pid_regex' do
    let(:item) { instantiate_fixture('druid:ab123cd4567', described_class) }

    it 'identifies pids by regex' do
      expect('ab123cd4567'.match(item.pid_regex).size).to eq(1)
    end
    it 'pulls out a pid by regex' do
      expect('druid:ab123cd4567/other crappola'.match(item.pid_regex)[0]).to eq('ab123cd4567')
    end
    it 'does not identify non-pids' do
      expect('bogus'.match(item.pid_regex)).to be_nil
    end
    it 'does not identify pid by druid regex' do
      expect('ab123cd4567'.match(item.druid_regex)).to be_nil
    end
    it 'identifies full druid by regex' do
      expect('druid:ab123cd4567'.match(item.druid_regex).size).to eq(1)
    end
    it 'pulls out a full druid by regex' do
      expect('druid:ab123cd4567/other crappola'.match(item.druid_regex)[0]).to eq('druid:ab123cd4567')
    end
    it 'does not identify non-druids' do
      expect('bogus'.match(item.druid_regex)).to be_nil
    end
  end

  describe '#adapt_to_cmodel' do
    context 'for a Hydrus collection' do
      let(:item) { instantiate_fixture('druid:kq696sh3014', Dor::Abstract) }

      it 'adapts to the object type asserted in the identityMetadata' do
        expect(item.adapt_to_cmodel.class).to eq Dor::Collection
      end
    end

    context 'for a Hydrus item' do
      let(:item) { instantiate_fixture('druid:bb004bn8654', Dor::Abstract) }

      it 'adapts to the object type asserted in the identityMetadata' do
        expect(item.adapt_to_cmodel.class).to eq described_class
      end
    end

    context 'for a Dor item' do
      let(:item) { instantiate_fixture('druid:dc235vd9662', Dor::Abstract) }

      it 'adapts to the object type asserted in the identityMetadata' do
        expect(item.adapt_to_cmodel.class).to eq described_class
      end
    end

    context 'for an agreement' do
      let(:item) { instantiate_fixture('druid:dd327qr3670', Dor::Abstract) }

      it 'adapts to the object type asserted in the identityMetadata' do
        expect(item.adapt_to_cmodel.class).to eq Dor::Agreement
      end
    end

    context 'for an object without identityMetadata or a RELS-EXT model' do
      let(:item) { item_from_foxml(read_fixture('foxml_empty.xml'), Dor::Abstract) }

      it 'defaults to Dor::Item' do
        expect(item.adapt_to_cmodel.class).to eq described_class
      end
    end
  end
end
