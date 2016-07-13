class BaseHandler

  def self.incoming( params_str, thread )
    method, params = params_str.split( ' ', 2 )

    if method.nil?
      puts "BaseHandler: No Method!"
      thread.tell "NO METHOD: #{self.name} #{params_str}!"
      return false
    end

    puts "Method: #{method};"

    case method.upcase
    when 'ADD'
      self.add params, thread
    else
      self.custom_incoming method.upcase, params, thread
    end
  end

  def self.custom_incoming( method, params, thread )
    thread.tell "UNRECOGNIZED METHOD: #{self.name}.#{method}( #{params} )!"
    return false
  end

  def self.add( params, thread )
    thread.tell "ADD NOT IMPLEMENTED: #{self.name}.ADD( #{params} )!"
    return false
  end

  def listener( topic, payload, mqtt = nil )
    if topic.end_with? 'info'
      if payload.downcase == 'methods' || payload.downcase == 'abilities'
        mqtt.respond topic, methods_str
        return
      end
    end

    call topic, payload
  end

  def self.methods_str
    return "[]"
  end

end
