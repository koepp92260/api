require 'abtain_billing/billing/integrations/chronopay/helper.rb'
require 'abtain_billing/billing/integrations/chronopay/notification.rb'
require 'abtain_billing/billing/integrations/chronopay/return.rb'

module AbtainBilling #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Chronopay
        mattr_accessor :service_url
        self.service_url = 'https://secure.chronopay.com/index_shop.cgi'

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
