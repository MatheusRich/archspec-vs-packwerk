module Sales
  class OrdersController < ApplicationController
    def show
      @invoices = Billing::Invoice.where(order_id: params[:id]) # CASE C12 controller in another folder
    end
  end
end
