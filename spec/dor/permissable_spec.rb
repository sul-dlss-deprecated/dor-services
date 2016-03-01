require 'spec_helper'

describe Dor::Permissable do

  let(:sdr_administrator) { 'sdr-administrator' }
  let(:sdr_manager) { 'sdr-manager' }
  let(:sdr_viewer) { 'sdr-viewer' }

  let(:apo_manager) { 'dor-apo-manager' }
  let(:apo_depositor) { 'dor-apo-depositor' }
  let(:apo_metadata) { 'dor-apo-metadata' }
  let(:apo_viewer) { 'dor-apo-viewer' }

  let(:druid) { 'fg890hi1234' }
  let(:apo) { instantiate_fixture(druid, Dor::AdminPolicyObject) }

  before :each do
    stub_config
  end

  after :each do
    unstub_config
  end

  describe 'KNOWN_ROLES' do
    it 'includes all known roles' do
      expect(Dor::Permissable::KNOWN_ROLES).to include(sdr_administrator)
      expect(Dor::Permissable::KNOWN_ROLES).to include(sdr_manager)
      expect(Dor::Permissable::KNOWN_ROLES).to include(sdr_viewer)
      expect(Dor::Permissable::KNOWN_ROLES).to include(apo_manager)
      expect(Dor::Permissable::KNOWN_ROLES).to include(apo_depositor)
      expect(Dor::Permissable::KNOWN_ROLES).to include(apo_metadata)
      expect(Dor::Permissable::KNOWN_ROLES).to include(apo_viewer)
    end
  end

  # ----
  # Shared examples to allow/forbid all known roles

  shared_examples 'allows sdr-administrator' do
    it 'allows sdr-administrator' do
      expect(apo.send(method, [sdr_administrator])).to be true
    end
  end
  shared_examples 'forbids sdr-administrator' do
    it 'forbids sdr-administrator' do
      expect(apo.send(method, [sdr_administrator])).to be false
    end
  end

  shared_examples 'allows sdr-manager' do
    it 'allows sdr-manager' do
      expect(apo.send(method, [sdr_manager])).to be true
    end
  end
  shared_examples 'forbids sdr-manager' do
    it 'forbids sdr-manager' do
      expect(apo.send(method, [sdr_manager])).to be false
    end
  end

  shared_examples 'allows sdr-viewer' do
    it 'allows sdr-viewer' do
      expect(apo.send(method, [sdr_viewer])).to be true
    end
  end
  shared_examples 'forbids sdr-viewer' do
    it 'forbids sdr-viewer' do
      expect(apo.send(method, [sdr_viewer])).to be false
    end
  end

  shared_examples 'allows dor-apo-manager' do
    it 'allows dor-apo-manager' do
      expect(apo.send(method, [apo_manager])).to be true
    end
  end
  shared_examples 'forbids dor-apo-manager' do
    it 'forbids dor-apo-manager' do
      expect(apo.send(method, [apo_manager])).to be false
    end
  end

  shared_examples 'allows dor-apo-depositor' do
    it 'allows dor-apo-depositor' do
      expect(apo.send(method, [apo_depositor])).to be true
    end
  end
  shared_examples 'forbids dor-apo-depositor' do
    it 'forbids dor-apo-depositor' do
      expect(apo.send(method, [apo_depositor])).to be false
    end
  end

  shared_examples 'allows dor-apo-metadata' do
    it 'allows dor-apo-metadata' do
      expect(apo.send(method, [apo_metadata])).to be true
    end
  end
  shared_examples 'forbids dor-apo-metadata' do
    it 'forbids dor-apo-metadata' do
      expect(apo.send(method, [apo_metadata])).to be false
    end
  end

  shared_examples 'allows dor-apo-viewer' do
    it 'allows dor-apo-viewer' do
      expect(apo.send(method, [apo_viewer])).to be true
    end
  end
  shared_examples 'forbids dor-apo-viewer' do
    it 'forbids dor-apo-viewer' do
      expect(apo.send(method, [apo_viewer])).to be false
    end
  end

  shared_examples 'forbids deprecated roles' do
    it 'forbids dor-administrator' do
      expect(apo.send(method, ['dor-administrator'])).to be false
    end
    it 'forbids dor-viewer' do
      expect(apo.send(method, ['dor-viewer'])).to be false
    end
  end

  shared_examples 'it only allows APO managers' do
    # allows
    it_behaves_like 'allows sdr-administrator'
    it_behaves_like 'allows sdr-manager'
    it_behaves_like 'allows dor-apo-manager'
    # forbids
    it_behaves_like 'forbids sdr-viewer'
    it_behaves_like 'forbids dor-apo-depositor'
    it_behaves_like 'forbids dor-apo-metadata'
    it_behaves_like 'forbids dor-apo-viewer'
    it_behaves_like 'forbids deprecated roles'
  end

  shared_examples 'only allows ITEM managers' do
    # allows
    it_behaves_like 'allows sdr-administrator'
    it_behaves_like 'allows dor-apo-manager'
    it_behaves_like 'allows dor-apo-depositor'
    # forbids
    it_behaves_like 'forbids sdr-manager'
    it_behaves_like 'forbids sdr-viewer'
    it_behaves_like 'forbids dor-apo-metadata'
    it_behaves_like 'forbids dor-apo-viewer'
    it_behaves_like 'forbids deprecated roles'
  end

  context 'with a Dor::AdminPolicyObject' do
    # ---
    # APO roles

    describe 'can_create_apo?' do
      let(:method) { :can_create_apo? }
      it_behaves_like 'allows sdr-administrator'
      it_behaves_like 'allows sdr-manager'
      # forbids
      it_behaves_like 'forbids sdr-viewer'
      it_behaves_like 'forbids dor-apo-manager'
      it_behaves_like 'forbids dor-apo-depositor'
      it_behaves_like 'forbids dor-apo-metadata'
      it_behaves_like 'forbids dor-apo-viewer'
      it_behaves_like 'forbids deprecated roles'
    end

    describe 'can_manage_apo?' do
      let(:method) { :can_manage_apo? }
      it_behaves_like 'it only allows APO managers'
    end

    describe 'can_manage_roles?' do
      let(:method) { :can_manage_roles? }
      it_behaves_like 'it only allows APO managers'
    end

    describe 'can_manage_collections?' do
      let(:method) { :can_manage_collections? }
      it_behaves_like 'it only allows APO managers'
    end

    describe 'can_manage_sets?' do
      let(:method) { :can_manage_sets? }
      it_behaves_like 'it only allows APO managers'
    end

    describe 'can_release_objects?' do
      let(:method) { :can_release_objects? }
      it_behaves_like 'allows sdr-administrator'
      it_behaves_like 'allows sdr-manager'
      it_behaves_like 'allows dor-apo-manager'
      it_behaves_like 'allows dor-apo-depositor'
      # forbids
      it_behaves_like 'forbids sdr-viewer'
      it_behaves_like 'forbids dor-apo-metadata'
      it_behaves_like 'forbids dor-apo-viewer'
      it_behaves_like 'forbids deprecated roles'
    end

    # ---
    # Item roles

    describe 'can_manage_item?' do
      let(:method) { :can_manage_item? }
      it_behaves_like 'only allows ITEM managers'
    end
    describe 'can_register_item?' do
      let(:method) { :can_register_item? }
      it_behaves_like 'only allows ITEM managers'
    end
    describe 'can_manage_contents?' do
      let(:method) { :can_manage_contents? }
      it_behaves_like 'only allows ITEM managers'
    end
    describe 'can_manage_rights?' do
      let(:method) { :can_manage_rights? }
      it_behaves_like 'only allows ITEM managers'
    end
    describe 'can_manage_workflows?' do
      let(:method) { :can_manage_workflows? }
      it_behaves_like 'only allows ITEM managers'
    end
    describe 'can_manage_embargo?' do
      let(:method) { :can_manage_embargo? }
      it_behaves_like 'only allows ITEM managers'
    end
    describe 'can_manage_system_metadata?' do
      let(:method) { :can_manage_system_metadata? }
      it_behaves_like 'only allows ITEM managers'
    end
    describe 'can_manage_desc_metadata?' do
      # differs from others by allowing dor-apo-metadata
      let(:method) { :can_manage_desc_metadata? }
      it_behaves_like 'allows sdr-administrator'
      it_behaves_like 'allows dor-apo-manager'
      it_behaves_like 'allows dor-apo-depositor'
      it_behaves_like 'allows dor-apo-metadata' # diff from others
      # forbids
      it_behaves_like 'forbids sdr-manager'
      it_behaves_like 'forbids sdr-viewer'
      it_behaves_like 'forbids dor-apo-viewer'
      it_behaves_like 'forbids deprecated roles'
    end

    describe 'can_view_content?' do
      let(:method) { :can_view_content? }
      # allows
      it_behaves_like 'allows sdr-administrator'
      it_behaves_like 'allows sdr-viewer'
      it_behaves_like 'allows dor-apo-depositor'
      it_behaves_like 'allows dor-apo-manager'
      it_behaves_like 'allows dor-apo-metadata'
      it_behaves_like 'allows dor-apo-viewer'
      # forbids
      it_behaves_like 'forbids sdr-manager'
      it_behaves_like 'forbids deprecated roles'
    end
    describe 'can_view_metadata?' do
      let(:method) { :can_view_metadata? }
      # allows every role
      it_behaves_like 'allows sdr-administrator'
      it_behaves_like 'allows sdr-manager'
      it_behaves_like 'allows sdr-viewer'
      it_behaves_like 'allows dor-apo-depositor'
      it_behaves_like 'allows dor-apo-manager'
      it_behaves_like 'allows dor-apo-metadata'
      it_behaves_like 'allows dor-apo-viewer'
      # forbids
      it_behaves_like 'forbids deprecated roles'
    end
  end

  # ----
  # alias_methods

  describe 'aliases' do
    it 'return :roles_which_manage_apo' do
      aliases = [
        :roles_which_manage_roles,
        :roles_which_manage_collections,
        :roles_which_manage_sets
      ]
      aliases.each do |a|
        # Use Object.send to access private methods
        expect(apo.send(a)).to eq apo.send(:roles_which_manage_apo)
      end
    end
    it 'return :roles_which_manage_item' do
      aliases = [
        :roles_which_register_item,
        :roles_which_manage_sys_md,
        :roles_which_manage_contents,
        :roles_which_manage_rights,
        :roles_which_manage_workflows,
        :roles_which_manage_embargo
      ]
      aliases.each do |a|
        # Use Object.send to access private methods
        expect(apo.send(a)).to eq apo.send(:roles_which_manage_item)
      end
    end
  end
end


