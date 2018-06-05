[![Build Status](https://travis-ci.org/sul-dlss/dor-services.svg?branch=master)](https://travis-ci.org/sul-dlss/dor-services)
[![Coverage Status](https://coveralls.io/repos/sul-dlss/dor-services/badge.svg?branch=master&service=github)](https://coveralls.io/github/sul-dlss/dor-services?branch=master)
[![Gem Version](https://badge.fury.io/rb/dor-services.svg)](https://badge.fury.io/rb/dor-services)

# dor-services

Require the following:

```ruby
require 'dor-services'
```

Configuration is handled through the `Dor::Config` object:

```ruby
Dor::Config.configure do
  # Basic DOR configuration
  fedora.url  = 'https://dor-dev.stanford.edu/fedora'
  solr.url = 'http://dor-dev.stanford.edu/solr'

  # If using SSL certificates
  ssl do
    cert_file = File.dirname(__FILE__) + '/../certs/dummy.crt'
    key_file  = File.dirname(__FILE__) + '/../certs/dummy.key'
    key_pass  = 'dummy'
  end

  # If using SURI service
  suri do
    mint_ids = true
    url      = 'http://some.suri.host:8080'
    id_namespace = 'druid'
    user     = 'suriuser'
    password = 'suripword'
  end
end
```

Values can also be configured individually:

    Dor::Config.suri.mint_ids(true)

## Console

You can start a pry session with the dor-services gem loaded by executing the script at:

    ./script/console

It will need the following in order to execute:

    ./config/dev_console_env.rb
    ./config/certs/robots-dor-dev.crt
    ./config/certs/robots-dor-dev.key

To copy them from a known source:
```bash
scp sul-lyberservices-dev.stanford.edu:common-accessioning.old/common-accessioning/shared/config/certs/robots-dor-dev.* config/certs/
scp sul-lyberservices-dev.stanford.edu:common-accessioning.old/common-accessioning/shared/config/environments/development.rb config/dev_console_env.rb
```

Console is located in the `./script` subdirectory so that it does not get installed by clients of the gem.

## Copyright

Copyright (c) 2014 Stanford University Library. See LICENSE for details.
