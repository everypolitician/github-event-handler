# Represents a registered 3rd party application
class Application < Sequel::Model
  many_to_one :user
  one_to_many :submissions
  def validate
    super
    validates_presence [:name]
  end

  def before_create
    generate_app_id
    generate_app_secret
    super
  end

  def generate_app_id
    loop do
      self.app_id = SecureRandom.hex(10)
      break unless Application.where(app_id: app_id).any?
    end
  end

  def generate_app_secret
    self.secret = SecureRandom.hex(20)
  end
end
