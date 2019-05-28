# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::DeleteService do
  let(:fixture_dir) { '/tmp/cleanup-spec' }
  let(:stacks_dir) { File.join(fixture_dir, 'stacks') }

  let(:druid_1) { 'druid:cd456ef7890' }
  let(:service) { described_class.new(druid_1) }

  before do
    allow(Dor::Config.stacks).to receive(:local_stacks_root).and_return(stacks_dir)
    FileUtils.mkdir fixture_dir
    FileUtils.mkdir stacks_dir
  end

  after do
    FileUtils.rm_rf fixture_dir
  end

  def create_tempfile(path)
    File.open(File.join(path, 'tempfile'), 'w') do |tf1|
      tf1.write 'junk'
    end
  end

  context '.cleanup_stacks' do
    let(:stacks_druid) { DruidTools::StacksDruid.new(druid_1, Dor::Config.stacks.local_stacks_root) }

    before do
      stacks_druid.mkdir

      create_tempfile stacks_druid.path
    end

    it 'prunes the item from the local stacks root' do
      expect { service.send(:cleanup_stacks) }.to change { File.exist?(stacks_druid.path) }
        .from(true).to(false)
    end
  end
end
