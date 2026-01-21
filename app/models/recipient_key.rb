# frozen_string_literal: true

class RecipientKey < ApplicationRecord
  belongs_to :recipient

  validates :public_key_b64u, presence: true
  validates :kdf_salt_b64u, presence: true
  validates :kdf_params, presence: true
  validates :key_version, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :recipient_id, uniqueness: true

  # Validate KDF params structure
  validate :validate_kdf_params

  private

  def validate_kdf_params
    return if kdf_params.blank?

    required_keys = %w[opslimit memlimit algo]
    missing_keys = required_keys - kdf_params.keys.map(&:to_s)

    if missing_keys.any?
      errors.add(:kdf_params, "missing required keys: #{missing_keys.join(', ')}")
    end
  end
end
