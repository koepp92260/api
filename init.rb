require 'abtain_billing'
require 'abtain_billing/billing/integrations/action_view_helper'
ActionView::Base.send(:include, AbtainBilling::Billing::Integrations::ActionViewHelper)
