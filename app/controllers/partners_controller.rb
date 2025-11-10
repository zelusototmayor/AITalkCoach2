class PartnersController < ApplicationController
  def index
    @partner_application = PartnerApplication.new
  end

  def create
    @partner_application = PartnerApplication.new(partner_application_params)

    if @partner_application.save
      render json: { success: true, message: "Thank you! We've received your application and will be in touch soon." }
    else
      render json: { success: false, errors: @partner_application.errors.full_messages }, status: :unprocessable_entity
    end
  end

  private

  def partner_application_params
    params.require(:partner_application).permit(:name, :email, :partner_type, :message)
  end
end
