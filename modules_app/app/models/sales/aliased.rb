module Sales
  class Aliased
    INVOICE = Billing::Invoice # CASE C21 constant alias

    def all = INVOICE.all
  end
end
