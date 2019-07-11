# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::StatusService do
  let(:item) { instantiate_fixture('druid:ab123cd4567', Dor::Item) }

  describe '#status' do
    subject(:status) { described_class.status(item) }

    let(:versionMD) { double(Dor::VersionMetadataDS) }

    before do
      expect(item).to receive(:versionMetadata).and_return(versionMD)
      # TODO: this stub is too knowledgable about the inner workings of the workflow client
      # instead it should just stub :milestones which returns an array of hashes
      expect(Dor::Config.workflow.client.lifecycle_routes).to receive(:query_lifecycle).and_return(xml)
    end

    context 'for gv054hp4128' do
      context 'when current version is published, but does not have a version attribute' do
        let(:xml) do
          Nokogiri::XML('<?xml version="1.0" encoding="UTF-8"?>
          <lifecycle objectId="druid:gv054hp4128">
          <milestone date="2012-11-06T16:19:15-0800" version="2">described</milestone>
          <milestone date="2012-11-06T16:21:02-0800">opened</milestone>
          <milestone date="2012-11-06T16:30:03-0800">submitted</milestone>
          <milestone date="2012-11-06T16:35:00-0800">described</milestone>
          <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
          <milestone date="2012-11-06T16:59:39-0800">published</milestone>
          </lifecycle>')
        end

        it 'generates a status string' do
          expect(versionMD).to receive(:current_version_id).and_return('4')
          expect(status).to eq('v4 In accessioning (described, published)')
        end
      end

      context 'when current version matches the attribute in the milestone' do
        let(:xml) do
          Nokogiri::XML('<?xml version="1.0" encoding="UTF-8"?>
          <lifecycle objectId="druid:gv054hp4128">
          <milestone date="2012-11-06T16:19:15-0800" version="2">described</milestone>
          <milestone date="2012-11-06T16:59:39-0800" version="3">published</milestone>
          </lifecycle>')
        end

        it 'generates a status string' do
          expect(versionMD).to receive(:current_version_id).and_return('3')
          expect(status).to eq('v3 In accessioning (described, published)')
        end
      end
    end

    context 'for bd504dj1946' do
      let(:xml) do
        Nokogiri::XML('<?xml version="1.0"?>
        <lifecycle objectId="druid:bd504dj1946">
        <milestone date="2013-04-03T15:01:57-0700">registered</milestone>
        <milestone date="2013-04-03T16:20:19-0700">digitized</milestone>
        <milestone date="2013-04-16T14:18:20-0700" version="1">submitted</milestone>
        <milestone date="2013-04-16T14:32:54-0700" version="1">described</milestone>
        <milestone date="2013-04-16T14:55:10-0700" version="1">published</milestone>
        <milestone date="2013-07-21T05:27:23-0700" version="1">deposited</milestone>
        <milestone date="2013-07-21T05:28:09-0700" version="1">accessioned</milestone>
        <milestone date="2013-08-15T11:59:16-0700" version="2">opened</milestone>
        <milestone date="2013-10-01T12:01:07-0700" version="2">submitted</milestone>
        <milestone date="2013-10-01T12:01:24-0700" version="2">described</milestone>
        <milestone date="2013-10-01T12:05:38-0700" version="2">published</milestone>
        <milestone date="2013-10-01T12:10:56-0700" version="2">deposited</milestone>
        <milestone date="2013-10-01T12:11:10-0700" version="2">accessioned</milestone>
        </lifecycle>')
      end

      it 'handles a v2 accessioned object' do
        expect(versionMD).to receive(:current_version_id).and_return('2')
        expect(status).to eq('v2 Accessioned')
      end

      it 'gives a status of unknown if there are no lifecycles for the current version, indicating malfunction in workflow' do
        expect(versionMD).to receive(:current_version_id).and_return('3')
        expect(status).to eq('v3 Unknown Status')
      end

      it 'includes a formatted date/time if one is requested' do
        expect(versionMD).to receive(:current_version_id).and_return('2')
        expect(described_class.status(item, true)).to eq('v2 Accessioned 2013-10-01 07:11PM')
      end
    end

    context 'for an accessioned step with the exact same timestamp as the deposited step' do
      let(:xml) do
        Nokogiri::XML('<?xml version="1.0"?>
        <lifecycle objectId="druid:bd504dj1946">
        <milestone date="2013-04-03T15:01:57-0700">registered</milestone>
        <milestone date="2013-04-03T16:20:19-0700">digitized</milestone>
        <milestone date="2013-04-16T14:18:20-0700" version="1">submitted</milestone>
        <milestone date="2013-04-16T14:32:54-0700" version="1">described</milestone>
        <milestone date="2013-04-16T14:55:10-0700" version="1">published</milestone>
        <milestone date="2013-07-21T05:27:23-0700" version="1">deposited</milestone>
        <milestone date="2013-07-21T05:28:09-0700" version="1">accessioned</milestone>
        <milestone date="2013-08-15T11:59:16-0700" version="2">opened</milestone>
        <milestone date="2013-10-01T12:01:07-0700" version="2">submitted</milestone>
        <milestone date="2013-10-01T12:01:24-0700" version="2">described</milestone>
        <milestone date="2013-10-01T12:05:38-0700" version="2">published</milestone>
        <milestone date="2013-10-01T12:10:56-0700" version="2">deposited</milestone>
        <milestone date="2013-10-01T12:10:56-0700" version="2">accessioned</milestone>
        </lifecycle>')
      end

      it 'has the correct status of accessioned (v2) object' do
        expect(versionMD).to receive(:current_version_id).and_return('2')
        expect(described_class.status(item, true)).to eq('v2 Accessioned 2013-10-01 07:10PM')
      end
    end

    context 'for an accessioned step with an ealier timestamp than the deposited step' do
      let(:xml) do
        Nokogiri::XML('<?xml version="1.0"?>
        <lifecycle objectId="druid:bd504dj1946">
        <milestone date="2013-04-03T15:01:57-0700">registered</milestone>
        <milestone date="2013-04-03T16:20:19-0700">digitized</milestone>
        <milestone date="2013-04-16T14:18:20-0700" version="1">submitted</milestone>
        <milestone date="2013-04-16T14:32:54-0700" version="1">described</milestone>
        <milestone date="2013-04-16T14:55:10-0700" version="1">published</milestone>
        <milestone date="2013-07-21T05:27:23-0700" version="1">deposited</milestone>
        <milestone date="2013-07-21T05:28:09-0700" version="1">accessioned</milestone>
        <milestone date="2013-08-15T11:59:16-0700" version="2">opened</milestone>
        <milestone date="2013-10-01T12:01:07-0700" version="2">submitted</milestone>
        <milestone date="2013-10-01T12:01:24-0700" version="2">described</milestone>
        <milestone date="2013-10-01T12:05:38-0700" version="2">published</milestone>
        <milestone date="2013-10-01T12:10:56-0700" version="2">deposited</milestone>
        <milestone date="2013-09-01T12:10:56-0700" version="2">accessioned</milestone>
        </lifecycle>')
      end

      it 'has the correct status of accessioned (v2) object' do
        expect(versionMD).to receive(:current_version_id).and_return('2')
        expect(described_class.status(item, true)).to eq('v2 Accessioned 2013-09-01 07:10PM')
      end
    end

    context 'for a deposited step for a non-accessioned object' do
      let(:xml) do
        Nokogiri::XML('<?xml version="1.0"?>
        <lifecycle objectId="druid:bd504dj1946">
        <milestone date="2013-04-03T15:01:57-0700">registered</milestone>
        <milestone date="2013-04-03T16:20:19-0700">digitized</milestone>
        <milestone date="2013-04-16T14:18:20-0700" version="1">submitted</milestone>
        <milestone date="2013-04-16T14:32:54-0700" version="1">described</milestone>
        <milestone date="2013-04-16T14:55:10-0700" version="1">published</milestone>
        <milestone date="2013-07-21T05:27:23-0700" version="1">deposited</milestone>
        <milestone date="2013-07-21T05:28:09-0700" version="1">accessioned</milestone>
        <milestone date="2013-08-15T11:59:16-0700" version="2">opened</milestone>
        <milestone date="2013-10-01T12:01:07-0700" version="2">submitted</milestone>
        <milestone date="2013-10-01T12:01:24-0700" version="2">described</milestone>
        <milestone date="2013-10-01T12:05:38-0700" version="2">published</milestone>
        <milestone date="2013-10-01T12:10:56-0700" version="2">deposited</milestone>
        </lifecycle>')
      end

      it 'has the correct status of deposited (v2) object' do
        expect(versionMD).to receive(:current_version_id).and_return('2')
        expect(described_class.status(item, true)).to eq('v2 In accessioning (described, published, deposited) 2013-10-01 07:10PM')
      end
    end
  end
end
