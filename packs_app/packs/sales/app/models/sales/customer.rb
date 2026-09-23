module Sales
  class Customer < ApplicationRecord
    has_many :invoices, class_name: "Billing::Invoice" # CASE C05 association class_name string

    def void_last_invoice = invoices.last.void! # CASE C18 call through association, no constant
  end
end
