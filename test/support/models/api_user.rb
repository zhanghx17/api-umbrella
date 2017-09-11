class ApiUser < ApplicationRecord
  has_one :settings, :class_name => "ApiUserSettings"
  has_and_belongs_to_many :roles, :class_name => "ApiRole", :join_table => "api_users_roles"

  def roles
    self.role_ids
  end

  def roles=(ids)
    ApiRole.insert_missing(ids)
    self.role_ids = ids
  end

  def api_key=(value)
    # Ensure the record ID is set (it may not be on initial create), since we
    # need the ID for the auth data.
    self.id ||= SecureRandom.uuid

    self.api_key_hash = OpenSSL::HMAC.hexdigest("sha256", $config["secret_key"], value)
    self.api_key_encrypted_iv = SecureRandom.hex(6)
    self.api_key_encrypted = Base64.strict_encode64(Encryptor.encrypt({
      :value => value,
      :iv => self.api_key_encrypted_iv,
      :key => Digest::SHA256.digest($config.fetch("secret_key")),
      :auth_data => self.id,
    }))
    self.api_key_prefix = value[0, 14]
  end

  def api_key
    Encryptor.decrypt({
      :value => Base64.strict_decode64(self.api_key_encrypted),
      :iv => self.api_key_encrypted_iv,
      :key => Digest::SHA256.digest($config.fetch("secret_key")),
      :auth_data => self.id,
    })
  end

  def api_key_preview
    "#{self.api_key_prefix[0, 6]}..."
  end

  def serializable_hash(options = nil)
    options ||= {}
    options.merge!({
      :methods => [
        :roles,
      ],
      :include => {
        :settings => {
          :include => {
            :rate_limits => {},
          },
        },
      },
    })
    super(options)
  end
end