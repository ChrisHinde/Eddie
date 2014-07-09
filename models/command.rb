class Command < ActiveRecord::Base
  has_many :macros, through: :macro_commands
  has_many :tasks, through: :task_commands
end
