require "jwt"

class Api::V1::BaseController < ActionController::API
  # Skip CSRF for API requests
  skip_before_action :verify_authenticity_token, raise: false

  # Error handling
  rescue_from ActiveRecord::RecordNotFound, with: :not_found
  rescue_from ActiveRecord::RecordInvalid, with: :unprocessable_entity
  rescue_from JWT::DecodeError, with: :unauthorized
  rescue_from JWT::ExpiredSignature, with: :token_expired

  before_action :authenticate_request

  private

  def authenticate_request
    @current_user = decode_token
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  def decode_token
    header = request.headers["Authorization"]
    return nil unless header

    token = header.split(" ").last
    decoded = JsonWebToken.decode(token)
    return nil unless decoded

    User.find(decoded[:user_id])
  end

  def current_user
    @current_user
  end

  # Skip authentication for certain actions
  def skip_authentication
    @skip_auth = true
  end

  def authenticate_request
    return if @skip_auth
    @current_user = decode_token
    render json: { error: "Unauthorized" }, status: :unauthorized unless @current_user
  end

  # Error responses
  def not_found
    render json: { error: "Resource not found" }, status: :not_found
  end

  def unprocessable_entity(exception)
    render json: {
      error: "Validation failed",
      errors: exception.record.errors.full_messages
    }, status: :unprocessable_entity
  end

  def unauthorized
    render json: { error: "Invalid token" }, status: :unauthorized
  end

  def token_expired
    render json: { error: "Token has expired" }, status: :unauthorized
  end
end
