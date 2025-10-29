module MixpanelHelper
  # Identify user for Mixpanel tracking
  def mixpanel_identify_user
    return unless logged_in?

    javascript_tag(<<~JS.html_safe)
      if (typeof mixpanel !== 'undefined') {
        mixpanel.identify('#{current_user.id}');
        mixpanel.people.set({
          '$email': '#{j current_user.email}',
          '$name': '#{j current_user.name}',
          '$created': '#{current_user.created_at.iso8601}',
          'User Type': 'authenticated'
        });
      }
    JS
  end

  # Track page view in Mixpanel
  def mixpanel_track_page_view(page_name = nil)
    page_name ||= "#{controller_name}##{action_name}"

    javascript_tag(<<~JS.html_safe)
      if (typeof mixpanel !== 'undefined') {
        mixpanel.track('Page Viewed', {
          'Page Name': '#{j page_name}',
          'Page Title': document.title,
          'URL': window.location.href,
          'User Type': '#{user_type_for_mixpanel}'
        });
      }
    JS
  end

  # Set super properties for all events
  def mixpanel_set_super_properties
    javascript_tag(<<~JS.html_safe)
      if (typeof mixpanel !== 'undefined') {
        mixpanel.register({
          'Environment': '#{Rails.env}',
          'User Type': '#{user_type_for_mixpanel}',
          'Platform': 'Web'
        });
      }
    JS
  end

  private

  def user_type_for_mixpanel
    if logged_in?
      "authenticated"
    elsif trial_mode?
      "trial"
    else
      "anonymous"
    end
  end
end
