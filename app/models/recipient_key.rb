# frozen_string_literal: true

class RecipientKey < ApplicationRecord
  # X25519 public key and Argon2id salt sizes (libsodium).
  PUBLIC_KEY_BYTES = 32
  KDF_SALT_BYTES = 16
  BASE64URL_UNPADDED = /\A[A-Za-z0-9_-]+\z/

  belongs_to :recipient

  validates :public_key_b64u, presence: true
  validates :kdf_salt_b64u, presence: true
  validates :kdf_params, presence: true
  validates :key_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :recipient_id, uniqueness: true

  # Validate KDF params structure
  validate :validate_kdf_params

  # The key material comes from the recipient's browser. It is checked only
  # when the key is registered, so rows stored before a change of the server
  # KDF settings stay valid.
  validate :kdf_params_match_server_config, on: :create
  validate :validate_key_material_encoding, on: :create

  private

  def validate_kdf_params
    return if kdf_params.blank?

    unless kdf_params.is_a?(Hash)
      errors.add(:kdf_params, "must be an object")
      return
    end

    required_keys = %w[opslimit memlimit algo]
    missing_keys = required_keys - kdf_params.keys.map(&:to_s)

    if missing_keys.any?
      errors.add(:kdf_params, "missing required keys: #{missing_keys.join(', ')}")
    end
  end

  # The browser derives the key with the parameters the server handed out on
  # the invite page and sends them back. Anything else is rejected: weaker
  # values would make an offline attack on the passphrase cheaper, heavier ones
  # would make decryption unusable. They are compared rather than overwritten
  # because the key was derived with whatever the client actually used.
  def kdf_params_match_server_config
    return unless kdf_params.is_a?(Hash) && errors[:kdf_params].empty?

    expected = AppConfig.kdf_params.stringify_keys
    actual = kdf_params.stringify_keys

    matches = actual.keys.sort == expected.keys.sort &&
      expected.all? { |key, value| actual[key].eql?(value) }

    errors.add(:kdf_params, "do not match the server configuration") unless matches
  end

  def validate_key_material_encoding
    validate_base64url_bytes(:public_key_b64u, PUBLIC_KEY_BYTES)
    validate_base64url_bytes(:kdf_salt_b64u, KDF_SALT_BYTES)
  end

  def validate_base64url_bytes(attribute, expected_bytes)
    value = self[attribute]
    return if value.blank?

    valid = value.match?(BASE64URL_UNPADDED) && decoded_bytesize(value) == expected_bytes
    errors.add(attribute, "must be #{expected_bytes} bytes, base64url encoded without padding") unless valid
  end

  def decoded_bytesize(value)
    Base64.urlsafe_decode64(value).bytesize
  rescue ArgumentError
    nil
  end
end
