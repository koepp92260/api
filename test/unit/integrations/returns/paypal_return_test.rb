require 'test_helper'

class PaypalReturnTest < Test::Unit::TestCase
  include AbtainBilling::Billing::Integrations

  def test_return
    r = Paypal::Return.new('')
    assert r.success?
  end
end