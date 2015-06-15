# Represents a submission from an external source
class Submission < Sequel::Model
  many_to_one :application

  def validate
    super
    validates_presence [:data, :country, :person_id, :application_id]
  end
end