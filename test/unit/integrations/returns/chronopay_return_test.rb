require 'test_helper'

class ChronopayReturnTest < Test::Unit::TestCase
  include AbtainBilling::Billing::Integrations
  
  def test_return
    r = Chronopay::Return.new('')
    assert r.success?
  end  
end

