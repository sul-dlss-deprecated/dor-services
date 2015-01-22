source 'https://rubygems.org'

group :development do
  gem "pry-debugger", '0.2.2', :platform => :ruby_19
end

group :development, :test do
  gem "ruby-debug", :platform => :ruby_18
  gem "rcov",       :platform => :ruby_18
  gem "simplecov",  :platform => [:ruby_19, :ruby_20, :ruby_21]
  gem "debugger", '1.6.3', :platform => :ruby_19
end

group :test do
  gem "vcr"
  gem 'webmock'
end

# Dependencies are defined in dor-services.gemspec
gemspec

