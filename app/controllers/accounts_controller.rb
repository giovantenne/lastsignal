# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_delivered_actions, only: [ :edit, :update, :destroy, :regenerate_recovery_code ]

  # GET /account
  def show
    @user = current_user
    @has_active_messages = current_user.has_active_messages?
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

    # Mark all messages as cancelled/deleted before destroying user
    # This prevents orphaned data
    @user.messages.destroy_all if @user.respond_to?(:messages)
    @user.recipients.destroy_all if @user.respond_to?(:recipients)
    @user.magic_link_tokens.destroy_all

    @user.destroy!

    session.delete(:user_id)
    session.delete(:created_at)

    flash[:notice] = "Your account has been deleted."
    redirect_to login_path
  end

  # POST /account/regenerate_recovery_code
  def regenerate_recovery_code
    new_code = current_user.generate_recovery_code!
    current_user.update!(recovery_code_viewed_at: nil) # Reset so they must acknowledge again
    session[:show_recovery_code] = new_code
    redirect_to dashboard_path
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
end
