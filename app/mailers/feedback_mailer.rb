class FeedbackMailer < ApplicationMailer
  def submit_feedback(feedback_text:, user_name: nil, user_email: nil, images: [])
    @feedback_text = feedback_text
    @user_name = user_name
    @user_email = user_email
    @submitted_at = Time.current

    # Attach images if provided
    images.each_with_index do |image, index|
      attachments["feedback_image_#{index + 1}#{File.extname(image.original_filename)}"] = {
        mime_type: image.content_type,
        content: image.read
      }
    end

    mail(
      to: "zsottomayor@gmail.com",
      subject: "New Feedback from AI Talk Coach",
      reply_to: user_email || "noreply@aitalkcoach.com"
    )
  end
end
