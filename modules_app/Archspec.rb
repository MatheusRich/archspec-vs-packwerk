facts "archspec_facts"

component :billing, namespace: "Billing", in: "app/views/billing/**/*.erb"
component :sales, namespace: "Sales", in: "app/views/sales/**/*.erb"

sales.can_only_use :billing
billing.cannot_use :sales
billing.public_api namespace: "Billing::Api"
