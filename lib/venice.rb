require 'venice/version'
require 'venice/client'
require 'venice/receipt'

module Venice
  class << self
    def production?
      @@production ||= (defined?(Rails) && Rails.env.production?) || true
      @@production
    end

    def production=(production)
      @@production = production
    end

    def shared_secret
      @@shared_secret ||= nil
    end

    def shared_secret=(secret)
      @@shared_secret = secret
    end
  end
end

