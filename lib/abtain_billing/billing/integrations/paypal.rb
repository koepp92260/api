require 'abtain_billing/billing/integrations/paypal/helper.rb'
require 'abtain_billing/billing/integrations/paypal/notification.rb'
require 'abtain_billing/billing/integrations/paypal/return.rb'

module AbtainBilling #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module Paypal
        
        # Overwrite this if you want to change the Paypal test url
        mattr_accessor :test_url
        self.test_url = 'https://www.sandbox.paypal.com/cgi-bin/webscr'
        
        # Overwrite this if you want to change the Paypal production url
        mattr_accessor :production_url 
        self.production_url = 'https://www.paypal.com/cgi-bin/webscr' 
        
        def self.service_url
          mode = AbtainBilling::Billing::Base.integration_mode
          case mode
          when :production
            self.production_url    
          when :test
            self.test_url
          else
            raise StandardError, "Integration mode set to an invalid value: #{mode}"
          end
        end
            
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
