module Sales
  class Quote < ApplicationRecord
    include Billing::Taxable # CASE C04 mixin
  end
end
