module Billing
  module Api
    def self.charge(order) = Invoice.create!(order_id: order.id, total: order.total)
    def self.invoices_for(order) = Invoice.where(order_id: order.id)
  end
end
