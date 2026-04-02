# frozen_string_literal: true

class EmergencyController < ApplicationController
  # Public endpoint - no authentication required
  # This controller uses the public layout by default

  layout "public"
  after_action :prevent_emergency_caching

  # GET /emergency
  # Shows the emergency stop form
  def show
  end

  # POST /emergency
  # Validates email + recovery code and stops delivery
  def confirm
    email = params[:email]&.downcase&.strip
    recovery_code = params[:recovery_code]

    if email.blank? || recovery_code.blank?
      flash.now[:alert] = "Please enter both your email address and recovery code."
      return render :show, status: :unprocessable_entity
    end

    user = User.find_by(email: email)

    # Constant-time failure to prevent user enumeration
    unless user
      normalized = recovery_code.to_s.gsub("-", "").upcase
      digest = Digest::SHA256.hexdigest(normalized)
      ActiveSupport::SecurityUtils.secure_compare(digest, "0" * 64)
      flash.now[:alert] = "Invalid email or recovery code."
      return render :show, status: :unprocessable_entity
    end

    new_recovery_code = user.use_recovery_code!(recovery_code)

    if new_recovery_code
      # Log the emergency stop
      AuditLog.log(
        action: "emergency_stop",
        user: user,
        actor_type: "user",
        request: request,
        metadata: { state_before: user.state_before_last_save }
      )

      render :success
    else
      flash.now[:alert] = "Invalid email or recovery code."
      render :show, status: :unprocessable_entity
    end
  end

  private

  def prevent_emergency_caching
    set_no_store_cache_headers
  end
end
