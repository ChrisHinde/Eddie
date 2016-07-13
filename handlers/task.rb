class TaskHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'tasks/#', self
  end

  def self.add( params, thread )
    thread.tell 'Add Task!'
  end

  def methods_str
    return "[list,add]"
  end

  def list
    return "[]"
  end

  def call( topic, payload )
    meth = topic.split('/').last

    case meth
    when 'list'
      Eddie.messenger.respond topic, list
    else
      Eddie.messenger.respond topic, "Unknown method: #{meth}"
    end
  end

end

puts "Task Handler Loading"
Eddie.register "tasks", TaskHandler.new
