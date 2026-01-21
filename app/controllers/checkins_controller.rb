# frozen_string_literal: true

class CheckinsController < ApplicationController
  include ActionView::Helpers::DateHelper

  layout "public"

  # GET /checkin/confirm/:token
  def confirm
    token = params[:token]
    token_digest = Digest::SHA256.hexdigest(token.to_s)

    user = User.find_by(checkin_token_digest: token_digest)

    if user.nil?
      flash[:alert] = "Invalid or expired check-in link."
      redirect_to login_path
      return
    end

    # Confirm the check-in
    user.confirm_checkin!

    # Clear the token
    user.update_column(:checkin_token_digest, nil)

    AuditLog.log(
      action: "checkin_confirmed",
      user: user,
      actor_type: "user",
      metadata: { next_checkin_at: user.next_checkin_at&.iso8601 },
      request: request
    )

    flash[:notice] = "Check-in confirmed! Your next check-in is due #{distance_of_time_in_words(Time.current, user.next_checkin_at)} from now."
    redirect_to logged_in? ? dashboard_path : login_path
  end
end
