# frozen_string_literal: true

module Dor
  # Query the processing status of an item.
  # This has a dependency on the workflow service (app) to get milestones.
  class StatusService
    # verbiage we want to use to describe an item when it has completed a particular step
    STATUS_CODE_DISP_TXT = {
      0 => 'Unknown Status', # if there are no milestones for the current version, someone likely messed up the versioning process.
      1 => 'Registered',
      2 => 'In accessioning',
      3 => 'In accessioning (described)',
      4 => 'In accessioning (described, published)',
      5 => 'In accessioning (described, published, deposited)',
      6 => 'Accessioned',
      7 => 'Accessioned (indexed)',
      8 => 'Accessioned (indexed, ingested)',
      9 => 'Opened'
    }.freeze

    # milestones from accessioning and the order they happen in
    STEPS = {
      'registered' => 1,
      'submitted' => 2,
      'described' => 3,
      'published' => 4,
      'deposited' => 5,
      'accessioned' => 6,
      'indexed' => 7,
      'shelved' => 8,
      'opened' => 9
    }.freeze

    # @return [Hash{Symbol => Object}] including :current_version, :status_code and :status_time
    def self.status_info(work)
      new(work).status_info
    end

    def self.status(work, include_time = false)
      new(work).status(include_time)
    end

    def initialize(work)
      @work = work
    end

    # @return [Hash{Symbol => Object}] including :current_version, :status_code and :status_time
    def status_info
      status_code = 0
      status_time = nil
      # for each milestone in the current version, see if it comes after the current 'last' step, if so, make it the last and record the date/time
      current_milestones.each do |m|
        m_name = m[:milestone]
        m_time = m[:at].utc.xmlschema
        next unless STEPS.key?(m_name) && (!status_time || m_time > status_time)

        status_code = STEPS[m_name]
        status_time = m_time
      end

      { current_version: current_version, status_code: status_code, status_time: status_time }
    end

    # @param [Boolean] include_time
    # @return [String] single composed status from status_info
    def status(include_time = false)
      status_info_hash = status_info
      current_version = status_info_hash[:current_version]
      status_code = status_info_hash[:status_code]
      status_time = status_info_hash[:status_time]

      # use the translation table to get the appropriate verbage for the latest step
      result = "v#{current_version} #{STATUS_CODE_DISP_TXT[status_code]}"
      result += " #{format_date(status_time)}" if include_time
      result
    end

    def milestones
      @milestones ||= Dor::Config.workflow.client.get_milestones('dor', work.pid)
    end

    private

    attr_reader :work

    def current_version
      @current_version ||= begin
                             work.versionMetadata.current_version_id
                           rescue StandardError
                             '1'
                           end
    end

    def current_milestones
      current = []
      # only get steps that are part of accessioning and part of the current version. That can mean they were archived with the current version
      # number, or they might be active (no version number).
      milestones.each do |m|
        if STEPS.key?(m[:milestone]) && (m[:version].nil? || m[:version] == current_version)
          current << m unless m[:milestone] == 'registered' && current_version.to_i > 1
        end
      end
      current
    end

    # handles formating utc date/time to human readable
    # XXX: bad form to hardcode TZ here.
    def format_date(datetime)
      d =
        if datetime.is_a?(Time)
          datetime
        else
          DateTime.parse(datetime).in_time_zone(ActiveSupport::TimeZone.new('Pacific Time (US & Canada)'))
        end
      I18n.l(d).strftime('%Y-%m-%d %I:%M%p')
    rescue StandardError
      d = datetime.is_a?(Time) ? datetime : Time.parse(datetime.to_s)
      d.strftime('%Y-%m-%d %I:%M%p')
    end
  end
end
