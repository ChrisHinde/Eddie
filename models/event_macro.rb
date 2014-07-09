class EventMacro < ActiveRecord::Base
  belongs_to :event
  belongs_to :task
end
