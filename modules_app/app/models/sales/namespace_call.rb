module Sales
  class NamespaceCall
    def run(order) = Billing.charge(order) # CASE C22 call on the namespace module itself
  end
end
