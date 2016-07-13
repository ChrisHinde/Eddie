#!/usr/bin/ruby

E_PORT = 4042

require 'socket'
require 'active_record'
require 'yaml'
require 'pi_piper'

PROJECT_ROOT = File.dirname(File.absolute_path(__FILE__))

require PROJECT_ROOT + '/lib/server.rb'
require PROJECT_ROOT + '/lib/base_handler.rb'
require PROJECT_ROOT + '/lib/mqtt.rb'

Dir.glob(PROJECT_ROOT + '/models/*.rb') { |file| require file }
#Dir.glob(PROJECT_ROOT + '/handlers/*.rb') { |file| require file }

# include PiPiper

class Eddie
  @@mqtt = nil

  def self.main(port)
    init

    @@mqtt = EddieMQTT.new @config['mqtt_server'], @config['mqtt_port'], @config['mqtt_id']

    load_handlers

    port = @config['port']
    server = TCPServer.open(port)

    puts "\n======================================="

    puts "Eddie listening on #{port}!"

    loop do
#      Thread.start server.accept do |client|
        client = server.accept
        puts "Got client"

        client.puts "HELLO FRIEND! Eddie here v0.1b\n"
        client.puts "LT " + Time.now.ctime

	friend = login_user client
        if friend[:accepted]
          thread = EddieThread.new client, friend
          thread.talk
        end

        client.puts "BYE FRIEND! Closing connection"

        client.close

        puts "Lost client"
#      end
    end

  end

  def self.login_user(client)
    client.puts "FRIEND, PRESENT YOURSELF!\n"

    username = client.gets.strip

    client.puts "FRIEND, I REQUIRE A PASSWORD!\n"

    password = client.gets.strip

    client.puts "FRIEND, I WELCOME YOU!\n"

    friend = { name: username, accepted: true }

    return friend
  end

  def self.read_pin pn, client
   pin = PiPiper::Pin.new pin: pn, direction: :in

   client.puts "PIN #{pn} IS " + pin.read.to_s
  end

  def self.set_pin pin_info, client
    pin_n = pin_info[0].to_i
    val   = pin_info[1]

    pin = PiPiper::Pin.new( pin: pin_n, direction: :out )

    case val.upcase
      when 'HIGH', 'ON', '1'
        pin.on
      when 'LOW', 'OFF', '0'
        pin.off
      else
        puts "UNR Pin state: " + val
        client.puts "UNR PIN STATE: " + val
    end

    client.puts "PIN #{pin_n} IS NOW " + val
  end

  def self.register( id, handler )
    unless @@handlers[id].nil?
      raise "There's already an handler with ID '" + id + "'"
    end

    puts "Registering Handler '" + id + "'"

    @@handlers[id] = handler
  end

  def self.get_handlers
    @@handlers.keys
  end

  def self.messenger
    @@mqtt
  end

  private
#    config = nil

    def self.init
      ActiveRecord::Base.logger = Logger.new(File.open('log/database.log', 'w'))

      dbconfig = YAML::load(File.open('config/database.yml'))
      ActiveRecord::Base.establish_connection(dbconfig)

      require PROJECT_ROOT + '/config/schema.rb'

      @config = YAML::load_file('config/config.yml')
    end

    def self.load_handlers
      puts "Loading Handlers"

      Dir.glob(PROJECT_ROOT + '/handlers/*.rb') do |file|
        require file
      end
    end

    def bye
      @_mqtt.disconnect
    end

    @@handlers = {}

end




Eddie.main E_PORT
