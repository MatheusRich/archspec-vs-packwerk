module Sales
  AnonymousSubclass = Class.new(Billing::Invoice) # CASE C25 Class.new(superclass)
end
