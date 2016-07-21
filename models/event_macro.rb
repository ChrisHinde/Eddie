class EventMacro < ActiveRecord::Base
  belongs_to :event
  belongs_to :macro

  serialize :arguments, JSON

end
