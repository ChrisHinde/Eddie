class EventHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'events/#', self
  end

  def self.add( params, thread )
    thread.tell 'Add Event!'
  end

  def methods_str
    return "[list,add]"
  end

  def list
    return "[]"
  end

  def call( topic, payload )
    top = topic.split('/states/').last
    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list
    else
      Eddie.messenger.respond topic, "Unknown method: #{meth}"
    end
  end

end

puts "Event Handler Loading"
Eddie.register "events", EventHandler.new
