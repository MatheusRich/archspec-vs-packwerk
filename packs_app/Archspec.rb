component :billing, in: "packs/billing/**/*.rb"
component :sales, in: "packs/sales/**/*.rb"

sales.can_only_use :billing
billing.cannot_use :sales
billing.public_api "packs/billing/app/public/**/*.rb"
todo "archspec_todo.yml"
