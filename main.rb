#!/usr/bin/ruby

E_PORT = 4242

require 'socket'
require 'active_record'
require 'yaml'
require 'pi_piper'

PROJECT_ROOT = File.dirname(File.absolute_path(__FILE__))

require PROJECT_ROOT + '/lib/server.rb'
require PROJECT_ROOT + '/lib/base_handler.rb'

Dir.glob(PROJECT_ROOT + '/models/*.rb') { |file| require file }
Dir.glob(PROJECT_ROOT + '/handlers/*.rb') { |file| require file }

# include PiPiper

class Eddie

  def self.main(port)
    init

    server = TCPServer.open(port)

    puts "Eddie listening on #{E_PORT}!"

    loop do
#      Thread.start server.accept do |client|
        client = server.accept
        puts "Got client"

        client.puts "HELLO FRIEND! Eddie here v0.1b"
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
    client.puts "FRIEND, PRESENT YOURSELF!"

    username = client.gets.strip

    client.puts "FRIEND, I REQUIRE A PASSWORD!"

    password = client.gets.strip

    client.puts "FRIEND, I WELCOME YOU!"

    friend = { name: username, accepted: true }

    return friend
  end

=begin
  def self.talk_to(client, friend)
    loop do
      str = client.gets.strip

      case str.upcase
      when /^EVENT/
        EventHandler.incoming str[6..-1], client, friend
      when /^TASK/
        TaskHandler.incomig str[5..-1], client, friend
      when /^MACRO/
        MacroHandler.incoming str[5..-1], client, friend
      when /^COMMAND/
        CommandHandler.inoming str[8..-1], client, friend
      when /^SAY/
	client.puts "> " + str[4..-1]
      when /^READ/
        pin = str[5..-1].to_i
        read_pin pin, client
      when /^SET/
        pin_info = str[4..-1].split
	set_pin pin_info, client
      when "EYB"
	return false
      else
        puts "WHAT: " + str
        client.puts "WAHT? <" + str + ">"
      end
    end
  end
=end

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

  private

    def self.init
      ActiveRecord::Base.logger = Logger.new(File.open('log/database.log', 'w'))

      dbconfig = YAML::load(File.open('config/database.yml'))
      ActiveRecord::Base.establish_connection(dbconfig)

      require PROJECT_ROOT + '/config/schema.rb'

    end

end




Eddie.main E_PORT
