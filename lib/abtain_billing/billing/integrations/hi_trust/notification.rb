require 'net/http'

module AbtainBilling #:nodoc:
  module Billing #:nodoc:
    module Integrations #:nodoc:
      module HiTrust
        class Notification < AbtainBilling::Billing::Integrations::Notification
          SUCCESS = '00'
          
          self.production_ips = [ '203.75.242.8' ]
          
          def complete?
            status == 'Completed'
          end 

          def transaction_id
            params['authRRN']
          end
          
          def item_id
            params['ordernumber']
          end
          
          def received_at
            Time.parse(params['orderdate']) rescue nil
          end
          
          def currency
            params['currency']
          end

          def gross
            sprintf("%.2f", gross_cents.to_f / 100)
          end
          
          def gross_cents
            params['approveamount'].to_i
          end
          
          def account
            params['storeid']
          end

          def status
            params['retcode'] == SUCCESS ? 'Completed' : 'Failed'
          end
          
          def test?
            AbtainBilling::Billing::Base.integration_mode == :test
          end
    
          def acknowledge      
            true
          end
        end
      end
    end
  end
end
