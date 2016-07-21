class LogHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'logs/#', self
  end

  def self.add( params, thread )
    thread.tell 'Add Log!'
  end

  def methods_str
    return "[list,info]"
  end

  def send_info topic, payload, rest = nil
    log_n = rest.nil? ? payload : rest

    lg = Log.find_by title: log_n

    unless log.nil?
      log = {
        id:    lg.id,
        state: lg.state,
        value: lg.value,
        time:  lg.created_at,
      }

      Eddie.messenger.respond topic, log.to_json
    else
      Eddie.messenger.respond topic, "ERROR: No such log > #{payload}"
    end
  end

=begin
  def delete_log topic, payload, rest = nil
    log = rest.nil? ? payload : rest

    puts "Delete Log: #{log}"

    log = Log.find_by title: log

    if log.nil?
      Eddie.messenger.respond topic, "ERROR: No such log > #{log}"
    else
      log.destroy

      Eddie.messenger.respond topic, "SUCCESS: Deleted log #{log}"
    end

  end
=end


  def list
    logs = Log.all

    logs = []

    logs.each do |log|
      logs.push log.title
    end

    return logs.to_json
  end

  def call( topic, payload )
    top = topic.split('/logs/').last
    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list
    when 'info'
      send_info topic, payload, rest
    else
      Eddie.messenger.respond topic, "Unknown method: #{meth}"
    end
  end

end

puts "Log Handler Loading"
Eddie.register "logs", LogHandler.new

