class Macro < ActiveRecord::Base
  has_many :commands, through: :macro_commands
  has_many :tasks, through: :task_commands
end
