# frozen_string_literal: true

require 'benchmark'

module Dor
  class IndexingService
    extend Deprecation

    class ReindexError < RuntimeError; end

    ##
    # Returns a Logger instance for recording info about indexing attempts
    # @yield attempt to execute 'entry_id_block' and use the result as an extra identifier for the log
    #   entry.  a placeholder will be used otherwise. 'request.uuid' might be useful in a Rails app.
    def self.generate_index_logger(&entry_id_block)
      Deprecation.warn(self, 'generate_index_logger is deprecated and will be removed in dor-services version 7')
      index_logger = Logger.new(Config.indexing_svc.log, Config.indexing_svc.log_rotation_interval)
      index_logger.formatter = proc do |_severity, datetime, _progname, msg|
        date_format_str = Config.indexing_svc.log_date_format_str
        entry_id = begin begin
                           entry_id_block.call
                         rescue StandardError
                           '---'
                         end end
        "[#{entry_id}] [#{datetime.utc.strftime(date_format_str)}] #{msg}\n"
      end
      index_logger
    end

    # memoize the loggers we create in a hash, init with a nil default logger
    @@loggers = { default: nil }

    def self.default_index_logger
      Deprecation.warn(self, 'default_index_logger is deprecated and will be removed in dor-services version 7')
      @@loggers[:default] ||= generate_index_logger
    end

    # takes a Dor object and indexes it to solr.  doesn't commit automatically.
    def self.reindex_object(obj, options = {})
      Deprecation.warn(self, 'reindex_pid is deprecated and will be removed in dor-services 7.')
      solr_doc = obj.to_solr
      Dor::SearchService.solr.add(solr_doc, options)
      solr_doc
    end

    # Use the dor-indexing-app service to reindex a pid
    # @param [String] pid the druid
    # @raise [ReindexError] on failure
    def self.reindex_pid_remotely(pid)
      pid = "druid:#{pid}" unless pid =~ /^druid:/
      realtime = Benchmark.realtime do
        with_retries(max_tries: 3, rescue: [RestClient::Exception, Errno::ECONNREFUSED]) do
          RestClient.post("#{Config.dor_indexing_app.url}/reindex/#{pid}", '')
        end
      end
      default_index_logger.info "successfully updated index for #{pid} in #{'%.3f' % realtime}s"
    rescue RestClient::Exception, Errno::ECONNREFUSED => e
      msg = "failed to reindex #{pid}: #{e}"
      default_index_logger.error msg
      raise ReindexError.new(msg)
    rescue StandardError => e
      default_index_logger.error "failed to reindex #{pid}: #{e}"
      raise
    end

    # retrieves a single Dor object by pid, indexes the object to solr, does some logging
    # (will use a default logger if one is not provided).  doesn't commit automatically.
    #
    # WARNING/TODO:  the tests indicate that the "rescue Exception" block at the end will
    # get skipped, and the thrown exception (e.g. SystemStackError) will not be logged.  since
    # that's the only consequence, and the exception bubbles up as we would want anyway, it
    # doesn't seem worth blocking refactoring.  see https://github.com/sul-dlss/dor-services/issues/156
    # extra logging in this case would be nice, but centralized indexing that's otherwise
    # fully functional is nicer.
    #
    # @overload reindex_pid(pid, index_logger, options = {})
    # @overload reindex_pid(pid, index_logger, should_raise_errors, options = {})
    # @overload reindex_pid(pid, options = {})
    def self.reindex_pid(pid, *args)
      Deprecation.warn(self, 'reindex_pid is deprecated and will be removed in dor-services 7.')
      options = {}
      options = args.pop if args.last.is_a? Hash

      if args.length > 0
        warn 'Dor::IndexingService.reindex_pid with primitive arguments is deprecated; pass e.g. { logger: logger, raise_errors: bool } instead'
        index_logger, should_raise_errors = args
        index_logger ||= default_index_logger
        should_raise_errors = true if should_raise_errors.nil?
      else
        index_logger = options.fetch(:logger, default_index_logger)
        should_raise_errors = options.fetch(:raise_errors, true)
      end

      obj = nil
      solr_doc = nil

      # benchmark how long it takes to load the object
      load_stats = Benchmark.measure('find') do
        obj = Dor.find pid
      end.format('%n realtime %rs total CPU %ts').gsub(/[\(\)]/, '')

      # benchmark how long it takes to convert the object to a Solr document
      to_solr_stats = Benchmark.measure('to_solr') do
        solr_doc = reindex_object obj, options
      end.format('%n realtime %rs total CPU %ts').gsub(/[\(\)]/, '')

      index_logger.info "successfully updated index for #{pid} (metrics: #{load_stats}; #{to_solr_stats})"

      solr_doc
    rescue StandardError => se
      if se.is_a? ActiveFedora::ObjectNotFoundError
        index_logger.warn "failed to update index for #{pid}, object not found in Fedora"
      else
        index_logger.warn "failed to update index for #{pid}, unexpected StandardError, see main app log: #{se.backtrace}"
      end
      raise se if should_raise_errors
    rescue Exception => ex
      index_logger.error "failed to update index for #{pid}, unexpected Exception, see main app log: #{ex.backtrace}"
      raise ex # don't swallow anything worse than StandardError
    end

    # given a list of pids, retrieve those objects from fedora, index each to solr, optionally commit
    def self.reindex_pid_list(pid_list, should_commit = false)
      Deprecation.warn(self, 'reindex_pid_list is deprecated and will be removed in dor-services 7')
      pid_list.each { |pid| reindex_pid pid, raise_errors: false } # use the default logger, don't let individual errors nuke the rest of the batch
      ActiveFedora.solr.conn.commit if should_commit
    end
  end
end
