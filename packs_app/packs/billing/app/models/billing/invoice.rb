module Billing
  class Invoice < ApplicationRecord
    include Taxable

    def void! = update!(voided: true)
  end
end
