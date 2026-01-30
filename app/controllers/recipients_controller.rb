# frozen_string_literal: true

class RecipientsController < ApplicationController
  before_action :require_authentication
  before_action :prevent_delivered_actions, only: [ :new, :create, :destroy, :resend_invite ]
  before_action :set_recipient, only: [ :show, :edit, :update, :destroy, :resend_invite ]

  # GET /recipients
  def index
    @recipients = current_user.recipients.includes(:recipient_key).order(created_at: :desc)
  end

  # GET /recipients/new
  def new
    @recipient = current_user.recipients.build
  end

  # POST /recipients
  def create
    @recipient = current_user.recipients.build(recipient_params)

    if @recipient.save
      # Generate invite token and send email
      raw_token = @recipient.generate_invite_token!
      RecipientMailer.invite(@recipient, raw_token).deliver_later

      AuditLog.log(
        action: "recipient_invited",
        user: current_user,
        metadata: { recipient_id: @recipient.id },
        request: request
      )

      AuditLog.log(
        action: "recipient_invite_sent",
        user: current_user,
        actor_type: "system",
        metadata: { recipient_id: @recipient.id },
        request: request
      )

      flash[:notice] = "Invite sent to #{@recipient.email}."
      redirect_to recipients_path
    else
      flash.now[:alert] = "Please correct the errors below."
      render :new, status: :unprocessable_entity
    end
  end

  # GET /recipients/:id
  def show
  end

  # GET /recipients/:id/edit
  def edit
  end

  # PATCH/PUT /recipients/:id
  def update
    if @recipient.update(recipient_params)
      flash[:notice] = "Recipient updated."
      redirect_to recipients_path
    else
      flash.now[:alert] = "Please correct the errors below."
      render :edit, status: :unprocessable_entity
    end
  end

  # DELETE /recipients/:id
  def destroy
    email = @recipient.email
    @recipient.destroy!

    flash[:notice] = "Recipient #{email} has been removed."
    redirect_to recipients_path
  end

  # POST /recipients/:id/resend_invite
  def resend_invite
    unless @recipient.invited?
      flash[:alert] = "This recipient has already accepted their invite."
      redirect_to recipients_path
      return
    end

    raw_token = @recipient.generate_invite_token!
    RecipientMailer.invite(@recipient, raw_token).deliver_later

    AuditLog.log(
      action: "recipient_invite_sent",
      user: current_user,
      actor_type: "system",
      metadata: { recipient_id: @recipient.id },
      request: request
    )

    flash[:notice] = "Invite resent to #{@recipient.email}."
    redirect_to recipients_path
  end

  private

  def set_recipient
    @recipient = current_user.recipients.find(params[:id])
  end

  def recipient_params
    params.require(:recipient).permit(:email, :name)
  end
end
