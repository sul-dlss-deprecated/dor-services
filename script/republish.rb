#!/usr/bin/env ruby
#
# republish.rb - Executes republish via dor-services-app REST API.
#
require 'uri'
require 'yaml'
require 'rest-client'
require 'logger'

if ARGV.first == '--help' || ARGV.size < 1
  puts 'Usage: republish.rb druid1 [... druid2 ...]'
  exit(-1)
end

CONF_FN = 'config/republish.yml'

log = Logger.new(File.open('log/republish.log', 'a'))
log.level = Logger::INFO

fail "Must have configuration file #{CONF_FN}" unless File.size?(CONF_FN)
config = YAML.load(File.read(CONF_FN))
fail 'Invalid YAML configuration' if config['url'].nil?

base_uri = URI(config['url'])
fail 'Must be an https URL' unless base_uri.scheme == 'https'
fail 'Must use user/password authentication' if base_uri.user.nil? || base_uri.password.nil?

endpoint = RestClient::Resource.new(base_uri.to_s)

ARGV.each do |druid|
  begin
    druid = "druid:#{druid}" unless druid =~ /^druid:/

    # POST to dor-services-app's REST API
    endpoint["v1/objects/#{druid}/publish"].post('') do |response|
      log.info "#{druid}: #{response.code} code from republish"
      log.error "#{druid}: ERROR: unexpected status code" unless response.code == 200
    end
  rescue => e
    log.error "#{druid}: ERROR: cannot republish: #{e.message}"
  end
end

exit(0)
  