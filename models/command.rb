class Command < ActiveRecord::Base
  has_many :macros, through: :macro_commands
  has_many :tasks, through: :task_commands

  Types = { 'internal' => 1, 'script' => 3 }

  def self.type_to_int t
    if Types.key? t
      return Types[t]
    else
      raise 'Unrecognized type: ' + t
    end
  end
  def self.type_to_str t
    type = Types.key(t)

    raise 'Unrecognized type: ' + t if type.nil?

    return type
  end


  def run
    puts "Running #{self.title}"
  end
end
