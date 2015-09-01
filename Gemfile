source 'https://rubygems.org'
#gem "rsolr", :git => "git://github.com/sul-dlss/rsolr.git", :branch => "nokogiri"
group :development do
  gem 'awesome_print'
  gem "ruby-debug", :platform => :ruby_18
  gem "rcov", :platform => :ruby_18
  gem "debugger", '1.6.3', :platform => :ruby_19
  gem "pry"
  gem "pry-debugger", '0.2.2', :platform => :ruby_19
end

group :development, :test do
  gem "simplecov",  :platform => [:ruby_19, :ruby_20, :ruby_21]
end

group :test do
  gem "vcr"
  gem 'webmock'
end

# Dependencies are defined in dor-services.gemspec
gemspec

gem 'addressable', '2.3.5'
