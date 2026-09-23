module Sales
  class Subscription < ApplicationRecord
    belongs_to :latest_invoice, class_name: "Billing::Invoice" # CASE C05b belongs_to class_name
    has_one :first_invoice, -> { order(:id) }, class_name: "::Billing::Invoice", inverse_of: false # CASE C05c scope + absolute
    has_many :line_items, class_name: "Sales::Order" # CASE C05d same module (must NOT be flagged)
  end
end
