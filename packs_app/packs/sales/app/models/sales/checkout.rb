module Sales
  class Checkout
    def run(order)
      order.charge
    rescue Billing::PaymentError # CASE C10 rescue clause
      false
    end
  end
end
