class NotFoundException < StandardError
end

class BaseHandler

  def self.incoming( params_str, thread )
    method, params = params_str.split( ' ', 2 )

    puts "Method: #{method};"

    case method.upcase
    when 'ADD'
      self.add params, thread
    else
      self.custom_incoming method.upcase, params, thread
    end
  end

  def self.custom_incoming( method, params, thread )
    thread.tell "UNRECOGNIZED METHOD: #{self.class.name}.#{method}( #{params} )!"
    return false
  end

  def self.add( params, thread )
    thread.tell "ADD NOT IMPLEMENTED: #{self.class.name}.#{method}( #{params} )!"
    return false
  end

end
