module Sales
  class DynamicLookup
    def by_string = "Billing::Invoice".constantize # CASE C07 constantize
    def by_const_get = Billing.const_get(:Invoice) # CASE C08 const_get
  end
end
