module Dor
  module Upgradable

    # The Upgradable mixin is responsible for making sure all DOR objects,
    # concerns, and datastreams know how to upgrade themselves to the latest
    # Chimera/DOR content standards.
    #
    # To add a new upgrade:
    # 1) include Dor::Upgradable within whatever model, datastream, or mixin
    #    you want to make upgradable.
    # 2) Add a block to the model, datastream, or mixin as follows:
    #
    #    on_upgrade(v) do |obj|
    #      # Do whatever needs to be done to obj
    #    end
    #
    #    where v is the first released version of dor-services that will
    #    include the upgrade.
    #
    # The block can either be defined on the model itself, or in a file
    # in the dor/migrations/[model] directory. See Dor::Identifiable and
    # dor/migrations/identifiable/* for an example.

    Callback = Struct.new :module, :version, :description, :block

    mattr_accessor :__upgrade_callbacks
    @@__upgrade_callbacks = []
    def self.add_upgrade_callback c, v, d, &b
      @@__upgrade_callbacks << Callback.new(c, Gem::Version.new(v), d, b)
    end

    def self.run_upgrade_callbacks(obj, event_handler)
      relevant = @@__upgrade_callbacks.select { |c| obj.is_a?(c.module) }.sort_by(&:version)
      results = relevant.collect do |c|
        result = c.block.call(obj)
        if result && event_handler.respond_to?(:add_event)
          event_handler.add_event 'remediation', "#{c.module.name} #{c.version}", c.description
        end
        if result
          Dor.logger.info "Applied remediation '#{c.description}' to '#{obj.pid}'"
        end
        result
      end
      results.any?
    end

    def self.included(base)
      base.instance_eval do
        def self.on_upgrade version, desc, &block
          Dor::Upgradable.add_upgrade_callback self, version, desc, &block
        end

        Dir[File.join(Dor.root,'dor','migrations',base.name.split(/::/).last.underscore,'*.rb')].each do |migration|
          require migration
        end
      end
    end

    def upgrade!
      results = [Dor::Upgradable.run_upgrade_callbacks(self, self)]
      if self.respond_to?(:datastreams)
        self.datastreams.each_pair do |dsid, ds|
          results << Dor::Upgradable.run_upgrade_callbacks(ds, self) unless ds.new?
        end
      end

      if results.any?
        self.save
      else
        false
      end
    end
  end
end
