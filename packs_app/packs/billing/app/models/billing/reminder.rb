module Billing
  class Reminder
    def order_for(invoice)
      Sales::Order.find(invoice.order_id) # CASE C19 reverse dependency billing -> sales
    end
  end
end
