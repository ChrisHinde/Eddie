class EventHandler < BaseHandler

  def self.add( params, thread )
    thread.tell 'Add Event!'
  end

end
