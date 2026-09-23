module Sales
  class AbsoluteReference
    def open_invoices = ::Billing::Invoice.where(voided: false) # CASE C02 absolute ::reference
  end
end
