# frozen_string_literal: true

class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Make authentication helpers available in views
  helper_method :current_user, :logged_in?

  private

  # Returns the currently logged-in user, or nil if not logged in
  def current_user
    return @current_user if defined?(@current_user)

    @current_user = if session[:user_id]
      User.find_by(id: session[:user_id])
    end
  end

  # Returns true if a user is logged in
  def logged_in?
    current_user.present?
  end

  # Before action: require authentication
  def require_authentication
    unless logged_in?
      flash[:alert] = "Please sign in to continue."
      redirect_to login_path
    end
  end

  # Before action: redirect if already logged in
  def redirect_if_authenticated
    if logged_in?
      redirect_to dashboard_path
    end
  end

  def prevent_delivered_actions
    return unless current_user&.delivered?

    message = "Your account is in delivered state and is read-only."

    if request.format.json?
      render json: { error: message }, status: :forbidden
    else
      flash[:alert] = message
      redirect_to dashboard_path
    end
  end
end
