# frozen_string_literal: true

require 'spec_helper'

RSpec.describe Dor::Ability do
  subject(:ability) { described_class }

  describe 'can_manage_item?' do
    it 'should match a group that has rights' do
      expect(ability.can_manage_item?(['dor-administrator'])).to be_truthy
    end
    it 'should match a group that has rights' do
      expect(ability.can_manage_item?(['sdr-administrator'])).to be_truthy
    end
    it 'shouldnt match a group that doesnt have rights' do
      expect(ability.can_manage_item?(['dor-apo-metadata'])).to be_falsey
    end
  end

  describe 'can_manage_desc_metadata?' do
    it 'should match a group that has rights' do
      expect(ability.can_manage_desc_metadata?(['dor-apo-metadata'])).to be_truthy
    end
    it 'shouldnt match a group that doesnt have rights' do
      expect(ability.can_manage_desc_metadata?(['dor-viewer'])).to be_falsey
    end
    it 'shouldnt match a group that doesnt have rights' do
      expect(ability.can_manage_desc_metadata?(['sdr-viewer'])).to be_falsey
    end
  end

  describe 'can_manage_content?' do
    it 'should match a group that has rights' do
      expect(ability.can_manage_content?(['dor-administrator'])).to be_truthy
    end
    it 'should match a group that has rights' do
      expect(ability.can_manage_content?(['sdr-administrator'])).to be_truthy
    end
    it 'shouldnt match a group that doesnt have rights' do
      expect(ability.can_manage_content?(['dor-apo-metadata'])).to be_falsey
    end
  end

  describe 'can_manage_rights?' do
    it 'should match a group that has rights' do
      expect(ability.can_manage_rights?(['dor-administrator'])).to be_truthy
    end
    it 'should match a group that has rights' do
      expect(ability.can_manage_rights?(['sdr-administrator'])).to be_truthy
    end
    it 'shouldnt match a group that doesnt have rights' do
      expect(ability.can_manage_rights?(['dor-apo-metadata'])).to be_falsey
    end
  end

  describe 'can_manage_embargo?' do
    it 'should match a group that has rights' do
      expect(ability.can_manage_embargo?(['dor-administrator'])).to be_truthy
    end
    it 'should match a group that has rights' do
      expect(ability.can_manage_embargo?(['sdr-administrator'])).to be_truthy
    end
    it 'shouldnt match a group that doesnt have rights' do
      expect(ability.can_manage_embargo?(['dor-apo-metadata'])).to be_falsey
    end
  end

  describe 'can_view_content?' do
    it 'should match a group that has rights' do
      expect(ability.can_view_content?(['dor-viewer'])).to be_truthy
    end
    it 'should match a group that has rights' do
      expect(ability.can_view_content?(['sdr-viewer'])).to be_truthy
    end
    it 'shouldnt match a group that doesnt have rights' do
      expect(ability.can_view_content?(['dor-people'])).to be_falsey
    end
  end

  describe 'can_view_metadata?' do
    it 'should match a group that has rights' do
      expect(ability.can_view_metadata?(['dor-viewer'])).to be_truthy
    end
    it 'should match a group that has rights' do
      expect(ability.can_view_metadata?(['sdr-viewer'])).to be_truthy
    end
    it 'shouldnt match a group that doesnt have rights' do
      expect(ability.can_view_metadata?(['dor-people'])).to be_falsey
    end
  end
end
