require 'mqtt'

module EddieMQTT_Listener
  attr_accessor :topic, :listener, :mqtt

  def set_mqtt( mqtt )
    @mqtt = mqtt
  end

  def call( id, payload )
    puts "No Call!! (#{id} > #{payload})"
  end

  def listener( topic, payload, mqtt = nil )
    puts "EddieListener: #{topic} > #{payload}"

    if topic.end_with? 'info'
      if ( payload.downcase == 'methods' || payload.downcase == 'abilities' ) #&& self.respond_to?(:methods_str)
        @amqtt.respond topic, methods_str
        return
      end
    end

    call topic, payload
  end

end

class EddieMQTT_BaseListener 
  include EddieMQTT_Listener

  def initialize( top, mqtt = nil )
    @topic = top
    @mqtt = mqtt
  end

  def listener( topic, payload, mqtt = nil )
    unless @mqtt.nil?
      if topic.end_with? 'request'
        handle_info_request topic, payload
        return
      elsif topic.include? 'master/' + mqtt.id + '/'
        puts "Got info about myself (#{topic} > #{payload})"
        puts "I'm dead!!!" if payload.include? 'DEAD'
        return
      end
    end

    puts "BaseList: " + topic + " > " + payload
  end

  def handle_info_request( topic, payload )
    puts "Handle info : #{topic} > '#{payload}'"

    case payload.downcase
    when 'handlers', 'abilities'
      @mqtt.respond topic, Eddie.get_handlers
    when 'time'
      @mqtt.respond topic, DateTime.now.strftime('%s') #%Y%m%d %H:%M')
    else
      @mqtt.respond topic, "Unknown request: '" + payload + "'"
    end
  end

end

class EddieMQTT_Message
  attr_accessor :topic, :payload, :type, :is_response
end

class EddieMQTT

  def initialize( host, port, id, topic_prefix = 'eddie/', user = nil, passw = nil )
    @_toppref = topic_prefix
    @_id = id
    @_connected = false
    @_listeners = {}

    connect( host, port, id, topic_prefix, user, passw )
  end


=begin
  def info_listener( topic = '.', payload = '.' )
#    puts "InfoList: " + topic + " > " + payload
    p topic
    if topic.end_with? 'request'
      handle_info_request topic, payload
    elsif topic.include? 'master/' + @_id + '/'
      puts "Got info about myself (#{topic} > #{payload})"

      return
    end
  end
=end

  def connect( host, port, id, topic_prefix = 'eddie/', user = nil, passw = nil )

    @_mqtt = MQTT::Client.connect(
               :host      => host,
               :port      => port,
               :client_id => id,
               :username  => user,
               :password  => passw,
               :ssl       => false,
               :will_topic   => topic_prefix + 'info/master/' + id + '/status',
               :will_payload => 'DEAD: ' + id + ' SERVER DIED!',
               :will_retain => true
             )

    @_connected = true

    puts "EDDIE connected to MQTT at #{host}:#{port} as #{id}"

    publish 'info/master/' + id + '/status', 'ALIVE: ' + id + ' SERVER IS ALIVE!', true

    subscribe 'info/#', EddieMQTT_BaseListener.new( 'info/#' )

    Thread.new { listen }

    puts "MQTT Initiated"
  end

  def disconnect
    unless @_connected
      puts "Disconnect: MQTT not connected!"
      return false
    end

    publish 'info/master/' + @_id + '/status', 'DOWN: ' + @_id + ' SERVER DISCONNECTED!'

    puts "EDDIE disconnecting from MQTT"

    @_mqtt.disconnect

    @_connected = false

    return true
  end

  def delete!
    puts "Delete!"
    disconnect if @_connected
  end

  def publish( topic, payload, retain = false, add_prefix = true )
    topic = @_toppref + topic if add_prefix and ! topic.start_with? @_toppref
    puts "Publish: #{topic} > '#{payload}'"

    unless @_connected
      puts "Tried to publish to #{topic}, but is not connected!"
      return false
    end

    @_mqtt.publish topic, payload, retain
  end
  def transmit( topic, payload, add_prefix = true )
    self.publish topic, payload, add_prefix   
  end

  def tell( topic, payload )
    self.publish topic, payload
  end

  def respond( topic, payload, orig_payload = nil, is_error = false, add_prefix = true )
    topic = topic + "/response"

    unless orig_payload.nil?
      topic = 'responses/' + orig_payload['_respond_via'] + (is_error ? '/error' : '') unless orig_payload['_respond_via'].nil?
    end

    puts "Respond: #{topic} > '#{payload}'"
    self.publish topic, payload, false, add_prefix   
  end

  def subscribe( topic, listener, add_prefix = true )
    topic = @_toppref + topic if add_prefix

    listener.set_mqtt self

    if @_listeners[topic].nil?
      @_listeners[topic] = [ listener ]
    else
      @_listeners[topic].push listener
    end

#    p @_listeners

    if @_connected
      @_mqtt.subscribe topic

      puts "Subsribed to " + topic

      return :added_and_subscribed
    else
      puts "Added " + topic

      return :added_but_not_subscribed
    end
  end

  def listen
    @_mqtt.get do |topic,payload|
      puts "MQTT got: #{topic} > #{payload}"

      if topic.end_with? '/response'
        puts "Got Response: (#{topic}) > #{payload}"
        next     
      end

      @_listeners.each do |l_top,listeners|
        l_top = l_top.sub('+','(\w*)').sub('#','([\w/]*)\Z')

        if topic.match l_top
          puts "Topic match: " + topic + " = " + l_top

          listeners.each do |listener|
            begin
              listener.listener topic, payload, self
            rescue Exception => e
              puts "Listener Error: " + e.message
              p e.backtrace
=begin
.map{ |x|   
     x.match(/^(.+?):(\d+)(|:in `(.+)')$/); 
    [$1,$2,$4] 
}
=end
            end
          end
        else
#          puts "No Match: " + topic + " != " + l_top
        end
      end

    end
  end

  def id
    @_id
  end
end
