# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::DeleteService do
  let(:service) { described_class.new(druid) }

  describe '#remove_active_workflows' do
    let(:druid) { 'druid:aa123bb4567' }
    let(:client) { instance_double(Dor::Workflow::Client, delete_all_workflows: nil) }

    before do
      allow(Dor::Config.workflow).to receive(:client).and_return(client)
    end

    it 'calls the workflow client' do
      service.send(:remove_active_workflows)
      expect(client).to have_received(:delete_all_workflows).with(pid: druid)
    end
  end

  context '#cleanup_stacks' do
    let(:fixture_dir) { '/tmp/cleanup-spec' }
    let(:stacks_dir) { File.join(fixture_dir, 'stacks') }
    let(:druid) { 'druid:cd456ef7890' }
    let(:stacks_druid) { DruidTools::StacksDruid.new(druid, Dor::Config.stacks.local_stacks_root) }

    before do
      allow(Dor::Config.stacks).to receive(:local_stacks_root).and_return(stacks_dir)
      FileUtils.mkdir fixture_dir
      FileUtils.mkdir stacks_dir

      stacks_druid.mkdir

      File.open(File.join(stacks_druid.path, 'tempfile'), 'w') do |tf1|
        tf1.write 'junk'
      end
    end

    after do
      FileUtils.rm_rf fixture_dir
    end

    it 'prunes the item from the local stacks root' do
      expect { service.send(:cleanup_stacks) }.to change { File.exist?(stacks_druid.path) }
        .from(true).to(false)
    end
  end
end
