# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_delivered_actions, only: [
    :edit,
    :update,
    :destroy,
    :regenerate_recovery_code,
    :generate_external_checkin_token,
    :revoke_external_checkin_token
  ]

  # GET /account
  def show
    @user = current_user
    @has_active_messages = current_user.has_active_messages?
    @external_checkin_token = nil
  end

  # GET /account/edit
  def edit
    @user = current_user
    @user.build_trusted_contact if @user.trusted_contact.nil?
  end

  # PATCH/PUT /account
  def update
    @user = current_user

    if @user.update(account_params)
      @user.apply_checkin_setting_changes!
      flash[:notice] = "Your settings have been updated."
      redirect_to account_path
    else
      flash.now[:alert] = "Please correct the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /account
  def destroy
    @user = current_user

    # Wrap in transaction so partial deletion cannot occur.
    # User model has dependent: :destroy on all associations,
    # so @user.destroy! cascades to messages, recipients, tokens, etc.
    ActiveRecord::Base.transaction do
      @user.destroy!
    end

    reset_session

    flash[:notice] = "Your account has been deleted."
    redirect_to login_path
  end

  # POST /account/regenerate_recovery_code
  def regenerate_recovery_code
    new_code = current_user.generate_recovery_code!
    render_recovery_code_dashboard(new_code)
  end

  # POST /account/generate_external_checkin_token
  def generate_external_checkin_token
    new_token = current_user.generate_external_checkin_token!

    AuditLog.log(
      action: "external_checkin_token_generated",
      user: current_user,
      actor_type: "user",
      request: request
    )

    @user = current_user
    @has_active_messages = current_user.has_active_messages?
    @external_checkin_token = new_token

    flash.now[:notice] = "External check-in token generated. Copy it now: it won't be shown again."
    render :show, status: :ok
  end

  # DELETE /account/revoke_external_checkin_token
  def revoke_external_checkin_token
    current_user.revoke_external_checkin_token!

    AuditLog.log(
      action: "external_checkin_token_revoked",
      user: current_user,
      actor_type: "user",
      request: request
    )

    flash[:notice] = "External check-in token revoked."
    redirect_to account_path
  end

  private

  def account_params
    user_params = params.require(:user).permit(
      :checkin_interval_days,
      :checkin_attempts,
      :checkin_attempt_interval_days,
      trusted_contact_attributes: [
        :id,
        :name,
        :email,
        :pause_duration_days,
        :_destroy
      ]
    )

    convert_days_to_hours(user_params)
  end

  def convert_days_to_hours(user_params)
    days_to_hours(user_params, {
      checkin_interval_days: :checkin_interval_hours,
      checkin_attempt_interval_days: :checkin_attempt_interval_hours,
      pause_duration_days: :pause_duration_hours
    })

    trusted_contact = user_params[:trusted_contact_attributes]
    if trusted_contact
      days_to_hours(trusted_contact, {
        pause_duration_days: :pause_duration_hours
      })
    end

    user_params
  end

  def days_to_hours(params_hash, mapping)
    mapping.each do |day_key, hour_key|
      next unless params_hash.key?(day_key)

      day_value = params_hash.delete(day_key)

      if day_value.blank?
        params_hash[hour_key] = nil
        next
      end

      params_hash[hour_key] = day_value.to_f.round * 24
    end
  end

  def render_recovery_code_dashboard(recovery_code)
    @user = current_user
    @recipients_count = current_user.recipients.accepted.count
    @messages_count = current_user.messages.count
    @has_active_messages = current_user.has_active_messages?
    @show_recovery_code = recovery_code

    flash.now[:notice] = "Recovery code generated. Save it in a safe place."
    render "dashboard/show", status: :ok
  end
end
