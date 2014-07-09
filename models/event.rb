class Event < ActiveRecord::Base
  has_many :macros, through: :task_macros
  has_many :commands, through: :task_commands
end
