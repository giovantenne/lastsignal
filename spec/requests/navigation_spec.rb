# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Navigation", type: :request do
  describe "authenticated navigation" do
    it "provides accessible attributes for the mobile menu toggle" do
      user = create(:user)
      sign_in_as(user)

      get dashboard_path

      expect(response).to have_http_status(:ok)

      document = Nokogiri::HTML.parse(response.body)

      button = document.at_css("#mobile-menu-button")
      menu_icon = document.at_css("#menu-icon")
      close_icon = document.at_css("#close-icon")

      expect(button).to be_present
      expect(button["aria-label"]).to eq("Open navigation menu")
      expect(button["aria-controls"]).to eq("mobile-menu")
      expect(button["aria-expanded"]).to eq("false")

      expect(menu_icon).to be_present
      expect(menu_icon["aria-hidden"]).to eq("true")

      expect(close_icon).to be_present
      expect(close_icon["aria-hidden"]).to eq("true")
    end
  end
end
