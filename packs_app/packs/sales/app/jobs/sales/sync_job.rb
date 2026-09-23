module Sales
  class SyncJob < ApplicationJob
    def perform(order) = Billing::Api.invoices_for(order) # CASE C14 public API from a job (must NOT be flagged)
  end
end
