class LegalController < ApplicationController
  # Legal pages are publicly accessible - no authentication required

  def privacy
    # Privacy Policy page
    @page_title = "Privacy Policy"
  end

  def terms
    # Terms of Use page
    @page_title = "Terms of Use"
  end

  def contact
    # Contact page
    @page_title = "Contact Us"
  end
end
