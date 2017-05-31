require 'abtain_billing/billing/integrations/notification'
require 'abtain_billing/billing/integrations/helper'
require 'abtain_billing/billing/integrations/return'
require 'abtain_billing/billing/integrations/bogus'
require 'abtain_billing/billing/integrations/chronopay'
require 'abtain_billing/billing/integrations/paypal'
require 'abtain_billing/billing/integrations/nochex'
require 'abtain_billing/billing/integrations/gestpay'
require 'abtain_billing/billing/integrations/two_checkout'
require 'abtain_billing/billing/integrations/hi_trust'
require 'abtain_billing/billing/integrations/quickpay'

# make the bogus gateway be classified correctly by the inflector
if defined?(ActiveSupport::Inflector)
  ActiveSupport::Inflector.inflections do |inflect|
    inflect.uncountable 'bogus'
  end
else
  Inflector.inflections do |inflect|
    inflect.uncountable 'bogus'
  end
end
