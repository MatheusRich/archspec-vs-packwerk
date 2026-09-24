namespace :sales do
  task open_invoices: :environment do
    puts Billing::Invoice.where(voided: false).count # CASE N2 private reference from a rake task
  end
end
