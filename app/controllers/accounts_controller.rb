# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_delivered_actions, only: [:edit, :update, :destroy, :regenerate_recovery_code]

  # GET /account
  def show
    @user = current_user
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

  # GET /account/confirm_email/:token
  # Email changes are not supported - users should create a new account
  # This endpoint exists for potential future implementation
  def confirm_email
    flash[:alert] = "Email changes are not currently supported."
    redirect_to account_path
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
    params.require(:user).permit(
      :checkin_interval_hours,
      :grace_period_hours,
      :cooldown_period_hours,
      trusted_contact_attributes: [
        :id,
        :name,
        :email,
        :ping_interval_hours,
        :pause_duration_hours,
        :_destroy
      ]
    )
  end
end
