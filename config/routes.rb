Rails.application.routes.draw do
  # Health check for load balancers and uptime monitors
  get "up" => "rails/health#show", as: :rails_health_check

  # ============================================================================
  # Authentication
  # ============================================================================
  scope :auth do
    # Request magic link
    get  "login", to: "auth#new", as: :login
    post "magic_link", to: "auth#create", as: :magic_link

    # Verify magic link
    get "verify/:token", to: "auth#verify", as: :verify_magic_link

    # Logout
    delete "logout", to: "auth#destroy", as: :logout
  end

  # ============================================================================
  # Dashboard (authenticated)
  # ============================================================================
  resource :dashboard, only: [ :show ], controller: "dashboard" do
    post :acknowledge_recovery_code
    post :pause
    post :unpause
  end

  # ============================================================================
  # Account Management (authenticated)
  # ============================================================================
  resource :account, only: [ :show, :edit, :update, :destroy ] do
    # Recovery code regeneration
    post :regenerate_recovery_code
  end

  get "audit", to: "audits#index", as: :audit

  # ============================================================================
  # Recipients (authenticated)
  # ============================================================================
  resources :recipients, only: [ :index, :new, :create, :show, :edit, :update, :destroy ] do
    member do
      post :resend_invite
    end
  end

  # ============================================================================
  # Messages (authenticated)
  # ============================================================================
  resources :messages, only: [ :index, :new, :create, :show, :edit, :update, :destroy ]

  # ============================================================================
  # Check-in (public, token-based)
  # ============================================================================
  scope :checkin do
    get "confirm/:token", to: "checkins#confirm", as: :confirm_checkin
    post "confirm/:token", to: "checkins#complete", as: :complete_checkin
    get "success", to: "checkins#success", as: :checkin_success
  end

  # ============================================================================
  # Recipient Invite (public, token-based)
  # ============================================================================
  scope :invites do
    get  ":token", to: "invites#show", as: :accept_invite
    post ":token", to: "invites#accept"
  end

  # ============================================================================
  # Delivery (public, token-based)
  # ============================================================================
  scope :delivery do
    get ":token", to: "delivery#show", as: :delivery
    # API endpoint to fetch encrypted payload
    get ":token/payload", to: "delivery#payload", as: :delivery_payload
  end

  # ============================================================================
  # Trusted Contact (public, token-based)
  # ============================================================================
  scope :trusted_contact do
    get ":token", to: "trusted_contacts#show", as: :trusted_contact
    post ":token/confirm", to: "trusted_contacts#confirm", as: :trusted_contact_confirm
  end

  # ============================================================================
  # Webhooks
  # ============================================================================
  # ============================================================================
  # Emergency Stop (public, recovery code based)
  # ============================================================================
  get  "emergency", to: "emergency#show", as: :emergency
  post "emergency", to: "emergency#confirm"

  # ============================================================================
  # Root
  # ============================================================================
  root "auth#new"
end
