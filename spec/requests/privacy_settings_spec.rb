require 'rails_helper'

RSpec.describe "PrivacySettings", type: :request do
  describe "GET /show" do
    it "returns http success" do
      get "/privacy_settings/show"
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /update" do
    it "returns http success" do
      get "/privacy_settings/update"
      expect(response).to have_http_status(:success)
    end
  end
end
