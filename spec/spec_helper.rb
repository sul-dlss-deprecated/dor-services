# frozen_string_literal: true

$LOAD_PATH.unshift(File.dirname(__FILE__))
$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))

require 'simplecov'
require 'coveralls'
SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
                                                                 SimpleCov::Formatter::HTMLFormatter,
                                                                 Coveralls::SimpleCov::Formatter
                                                               ])
SimpleCov.start 'test_frameworks'

require 'rspec'
require 'dor-services'
require 'support/foxml_helper'
require 'equivalent-xml/rspec_matchers'
require 'webmock/rspec'

require 'pry'
require 'tmpdir'
require 'nokogiri'

require 'support/dor_config'

WebMock.disable_net_connect!(allow_localhost: true)
Dor.logger.level = :error

module Dor::SpecHelpers
  def stub_config
    this = self
    Dor::Config.push! do
      suri.mint_ids false
      solr.url 'http://solr.edu/solrizer'
      stacks.document_cache_host       'purl-test.stanford.edu'
      stacks.local_workspace_root      File.join(this.fixture_dir, 'workspace')
      stacks.local_stacks_root         File.join(this.fixture_dir, 'stacks')
      stacks.local_document_cache_root File.join(this.fixture_dir, 'purl')
    end
    allow(ActiveFedora).to receive(:fedora).and_return(double('frepo').as_null_object) # must be used in per-request context: :each not :all
  end

  def unstub_config
    Dor::Config.pop!
  end

  def instantiate_fixture(druid, klass = ActiveFedora::Base)
    mask = File.join(fixture_dir, "*_#{druid.sub(/:/, '_')}.xml")
    fname = Dir[mask].first
    return nil if fname.nil?

    item_from_foxml(File.read(fname), klass)
  end

  def read_fixture(fname)
    File.read(File.join(fixture_dir, fname))
  end

  def fixture_dir
    @fixture_dir ||= File.join(File.dirname(__FILE__), 'fixtures')
  end
end

RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    # mocks.verify_partial_doubles = true
  end

  # The settings below are suggested to provide a good initial experience
  # with RSpec, but feel free to customize to your heart's content.

  # These two settings work together to allow you to limit a spec run
  # to individual examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with `:focus`, all examples
  # get run.
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options. We recommend
  # you configure your source control system to ignore this file.
  config.example_status_persistence_file_path = 'spec/examples.txt'

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax/
  #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   - http://rspec.info/blog/2014/05/notable-changes-in-rspec-3/#zero-monkey-patching-mode
  #  config.disable_monkey_patching!

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed

  config.include Dor::SpecHelpers
end

Retries.sleep_enabled = false # fail fast in tests
