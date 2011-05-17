require 'mod_cons'

module Dor
  Config = ModCons::Configuration.new(:'Dor::Config')

  Config.declare do
    fedora do
      url nil
      cert_file nil
      key_file nil
      key_pass ''

      config_changed do |fedora|
        temp_v = $-v
        $-v = nil
        begin
         ::Fedora::Repository.register(fedora.url)
         ::Fedora::Connection.const_set(:SSL_CLIENT_CERT_FILE,fedora.cert_file)
         ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_FILE,fedora.key_file)
         ::Fedora::Connection.const_set(:SSL_CLIENT_KEY_PASS,fedora.key_pass)
        ensure
         $-v = temp_v
        end
      end
    end
  end
end

