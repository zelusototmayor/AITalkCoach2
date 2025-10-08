class FeedbackController < ApplicationController
  def create
    feedback_text = params[:feedback_text]
    images = params[:images] || []

    # Validate feedback text
    if feedback_text.blank?
      return render json: { error: "Feedback text cannot be empty" }, status: :unprocessable_entity
    end

    # Limit text length
    if feedback_text.length > 5000
      return render json: { error: "Feedback text is too long (max 5000 characters)" }, status: :unprocessable_entity
    end

    # Validate images
    if images.is_a?(Array) && images.length > 5
      return render json: { error: "Maximum 5 images allowed" }, status: :unprocessable_entity
    end

    # Ensure images is an array
    images = [images] unless images.is_a?(Array)
    images = images.compact.reject(&:blank?)

    # Get user info if logged in
    user_name = logged_in? ? current_user.name : nil
    user_email = logged_in? ? current_user.email : nil

    begin
      # Send email
      FeedbackMailer.submit_feedback(
        feedback_text: feedback_text,
        user_name: user_name,
        user_email: user_email,
        images: images
      ).deliver_now

      render json: { success: true, message: "Feedback submitted successfully" }, status: :ok
    rescue StandardError => e
      Rails.logger.error("Failed to send feedback email: #{e.message}")
      Rails.logger.error(e.backtrace.join("\n"))
      render json: { error: "Failed to send feedback. Please try again later." }, status: :internal_server_error
    end
  end
end
