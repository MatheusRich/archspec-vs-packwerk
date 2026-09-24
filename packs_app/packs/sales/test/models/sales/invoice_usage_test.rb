require "test_helper"

module Sales
  class InvoiceUsageTest < ActiveSupport::TestCase
    test "counts open invoices" do
      assert_equal 0, Billing::Invoice.where(voided: false).count # CASE N1 private reference from a test
    end
  end
end
