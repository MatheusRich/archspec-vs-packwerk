module Sales
  class ApiResult
    def build = Billing::Api::Result.new(invoice_id: 1) # CASE N3 control: a constant nested in the public API
  end
end
