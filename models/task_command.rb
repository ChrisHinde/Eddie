class TaskCommand < ActiveRecord::Base
  belongs_to :command
  belongs_to :task
end
