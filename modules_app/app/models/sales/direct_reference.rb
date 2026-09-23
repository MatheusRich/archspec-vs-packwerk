module Sales
  class DirectReference
    def open_invoices = Billing::Invoice.where(voided: false) # CASE C01 direct private reference
  end
end
