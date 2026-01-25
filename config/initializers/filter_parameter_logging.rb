# Be sure to restart your server when you modify this file.

# Configure parameters to be partially matched (e.g. passw matches password) and filtered from the log file.
# Use this to limit dissemination of sensitive information.
# See the ActiveSupport::ParameterFilter documentation for supported notations and behaviors.
Rails.application.config.filter_parameters += [
  :passw,
  :email,
  :secret,
  :token,
  :_key,
  :crypt,
  :salt,
  :certificate,
  :otp,
  :ssn,
  :cvv,
  :cvc,
  # LastSignal specific
  :passphrase,
  :ciphertext,
  :nonce,
  :encrypted_msg_key,
  :public_key,
  :private_key,
  :kdf_salt,
  :magic_link,
  :invite_token,
  :delivery_token,
  :checkin_confirm_token,
  :recovery_code,
  :recovery_code_confirmation
]
