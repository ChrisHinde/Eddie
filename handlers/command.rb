require 'json'

class CommandHandler < BaseHandler
  include EddieMQTT_Listener

  SCRIPT_DIR = 'commands/'

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
    cmd.arguments = data['arguments'] #.to_json

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
        id:    cmd.id,
        title: cmd.title,
        desc:  cmd.description,
        arguments: cmd.arguments,
        command: cmd.command,
        type: Command.type_to_str(cmd.command_type)
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
#      p payload
#      p rest

      arguments = { '_topic' => topic, '_payload' => payload }

      begin
        args = JSON.parse payload
        p args
        args.each do |k,v|
          arguments[k] = v unless k.first == '_'
        end
      rescue
        arguments['argument'] = payload
      end unless rest.nil?

      com.run arguments, self
    end
  end

  def run_internal cmd_name, arguments = nil, cmd = nil
    case cmd_name
    when 'publish'
      raise "No arguments given for 'publish'" if arguments.nil?
      Eddie.messenger.publish arguments['topic'], arguments['payload']
      Eddie.messenger.respond arguments['_topic'], "SUCCESS: Published to '" + arguments['topic'] + "'"
    else
      raise "Unknown internal command: '#{cmd_name}'"
    end
  end

  def run_script cmd_name, arguments = nil, cmd = nil
    cmd_name.gsub! '/', ''

    filename = PROJECT_ROOT + '/' + SCRIPT_DIR + cmd_name + '.rb'

    p filename

    if File.exists? filename
      require filename

      script_main arguments, cmd_name
    else
      raise "Unknown script command: '#{cmd_name}'"
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
=begin
{"title":"pub","desc":"Publish!",
"arguments":{"in": { "topic": "pub_test", "id": null }, "out": { "topic": "info/%topic%", "payload": "Test: %id%" } },
"command":"publish","type":"internal"}

{"title":"s_test","desc":"Script_test!",
"arguments":{ },
"command":"test","type":"script"}

=end
