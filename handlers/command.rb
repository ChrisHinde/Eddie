require 'json'

class CommandHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'commands/#', self

    @@types = { 'internal' => 1, 'script' => 3 }

  end

  def self.add( params, thread )
    thread.tell 'Add Command!'
  end

  def self.do_add
  end

  def add_cmd topic, data_raw, rest = nil
    begin
      data = JSON.parse data_raw
    rescue
      Eddie.messenger.respond topic, 'ERROR: Payload is not valid JSON'
      return
    end


    if data['title'].empty?
      Eddie.messenger.respond topic, 'ERROR: No title given' 
      return
    end

    if Command.exists?( title: data['title'] )
      Eddie.messenger.respond topic, 'ERROR: A command called ' + data['title'] +' already exists'
      return
    end

    cmd = Command.new

    cmd.title = data['title']
    cmd.description = data['desc']
    cmd.arguments = data['arguments'].to_json

    cmd.command = data['command']

    begin
      cmd.command_type = Command.type_to_int( data['type'] )
    rescue Exception => e
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + ' > ' + e.message
      return
    end

    if cmd.save
      Eddie.messenger.respond topic, 'SUCCESS: Added ' + data['title']
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + " > Couldn't save!"
    end
#    p cmd
  end

  def send_info topic, payload
    cmd = Command.find_by title: payload

    unless cmd.nil?
      command = {
        title: cmd.title,
        desc:  cmd.description,
        arguments: JSON.parse(cmd.arguments),
        command: cmd.command,
        type: Command.type_to_int(cmd.command_type)
      }

      Eddie.messenger.respond topic, command.to_json
    else
      Eddie.messenger.respond topic, "ERROR: No such command > #{payload}"
    end
  end

  def run_cmd topic, payload, rest = nil
    cmd = rest.nil? ? payload : rest

    puts "Running command: #{cmd}"

    com = Command.find_by title: cmd

    if com.nil?
      Eddie.messenger.respond topic, "ERROR: No such command > #{cmd}"
    else
      p payload
      p rest
      com.run
    end
  end

  def methods_str
    return "[list,add,info,types,run]"
  end

  def list #topic, payload
    commands = Command.all

    cmds = []

    commands.each do |cmd|
      cmds.push cmd.title
    end

    return cmds.to_json
  end

  def call( topic, payload )
#    meth = topic.split('/').last
    top = topic.split('/commands/').last
    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list
    when 'add'
      add_cmd topic, payload, rest
    when 'info'
      send_info topic, payload
    when 'types'
      Eddie.messenger.respond topic, @@types.keys.to_json
    when 'run'
      run_cmd topic, payload, rest
    else
      Eddie.messenger.respond topic, "Unknown method: #{meth}"
    end
  end

end

puts "Command Handler Loading"
Eddie.register "commands", CommandHandler.new
