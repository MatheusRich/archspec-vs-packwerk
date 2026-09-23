module Sales
  class Order < ApplicationRecord
    def charge = Billing::Api.charge(self) # CASE C00 public API (must NOT be flagged)
  end
end
