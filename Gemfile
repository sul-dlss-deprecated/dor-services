source 'https://rubygems.org'

group :development do
  gem 'pry-byebug', :platform => [:ruby_20, :ruby_21, :ruby_22]
  gem 'pry-debugger', '0.2.2', :platform => :ruby_19
end

group :test do
  gem 'vcr'
  gem 'webmock'
end

gem 'dor-rights-auth', :git => 'git@github.com:sul-dlss/dor-rights-auth.git', :branch => 'master'

# Dependencies are defined in dor-services.gemspec
gemspec
