class TaskMacro < ActiveRecord::Base
  belongs_to :macro
  belongs_to :task
end
