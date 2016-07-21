class EventTask < ActiveRecord::Base
  belongs_to :event
  belongs_to :task

  serialize :arguments, JSON

end
