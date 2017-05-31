require 'abtain_billing/billing/integrations/bogus/helper.rb'
require 'abtain_billing/billing/integrations/bogus/notification.rb'
require 'abtain_billing/billing/integrations/bogus/return.rb'

module AbtainBilling #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Bogus
        mattr_accessor :service_url
        self.service_url = 'http://www.bogus.com'

        def self.notification(post)
          Notification.new(post)
        end
        
        def self.return(query_string)
          Return.new(query_string)
        end
      end
    end
  end
end
