require 'json'

class MacroHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'macros/#', self
  end

#  def self.add( params, thread )
#    thread.tell 'Add Macro!'
#  end

  def add topic, data_raw, rest = nil
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

    if Macro.exists?( title: data['title'] )
      Eddie.messenger.respond topic, 'ERROR: A macro called ' + data['title'] +' already exists'
      return
    end

    macro = Macro.new

    macro.title = data['title']
    macro.description = data['desc']

    if macro.save
      data['commands'].each do |cmd_t,args|
        cmd = Command.find_by title: cmd_t

        m_c = MacroCommand.new
        m_c.arguments = args
        m_c.command = cmd
        m_c.macro = macro

        macro.macro_commands << m_c if m_c.save
      end

      Eddie.messenger.respond topic, 'SUCCESS: Added ' + data['title']
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + " > Couldn't save!"
    end
  end

  def update topic, data_raw, rest = nil
    begin
      data = JSON.parse data_raw
    rescue
      Eddie.messenger.respond topic, 'ERROR: Payload is not valid JSON'
      return
    end

    mcr_n = rest.nil? ? data['title'] : rest

    macro = Macro.find_by title: mcr_n

    unless macro.nil?
      macro.description = data['desc'] unless data['desc'].nil?


      unless data['commands'].nil?
        unless data['commands']['add'].nil?
          data['commands']['add'].each do |cmd_t, args|
            cmd = Command.find_by title: cmd_t

            mc = MacroCommand.new
            mc.arguments = args
            mc.command = cmd

            puts "Adding #{cmd_t}!"

            macro.macro_commands << mc if mc.save
          end
        end

        unless data['commands']['remove'].nil?
          data['commands']['remove'].each do |cmd_t|
            cmd = Command.find_by title: cmd_t

            puts "Removing #{cmd_t}!"

            macro.commands.delete cmd unless cmd.nil?
          end
        end
      end


      if macro.save
        Eddie.messenger.respond topic, 'SUCCESS: Updated ' + mcr_n
      else
        Eddie.messenger.respond topic, 'ERROR: Updating ' + mcr_n + " > Couldn't save (some changes might have been made)!"
      end
    else
      Eddie.messenger.respond topic, "ERROR: No such macro > #{mcr_n}"
    end
  end

  def send_info topic, payload, rest = nil
    mcr_n = rest.nil? ? payload : rest

    mcr = Macro.find_by title: mcr_n

    unless mcr.nil?
      macro = {
        id:    mcr.id,
        title: mcr.title,
        desc:  mcr.description,
        commands: []
      }

      mcr.commands.each do |cmd|
        macro[:commands].push cmd.title
      end

      Eddie.messenger.respond topic, macro.to_json
    else
      Eddie.messenger.respond topic, "ERROR: No such macro > #{mcr_n}"
    end
  end

  def run_macro topic, payload, rest = nil
    mcr = rest.nil? ? payload : rest

    puts "Running macro: #{mcr}"

    macro = Macro.find_by title: mcr

    if macro.nil?
      Eddie.messenger.respond topic, "ERROR: No such macro > #{mcr}"
    else
      arguments = { '_topic' => topic, '_payload' => payload }

      begin
        args = JSON.parse payload

        args.each do |k,v|
          arguments[k] = v unless k.first == '_'
        end
      rescue
        arguments['_argument'] = payload
      end unless rest.nil?

      macro.run arguments
    end
  end

  def list
    macros = Macro.all

    mcrs = []

    macros.each do |mcr|
      mcrs.push mcr.title
    end

    return mcrs.to_json
  end

  def delete_macro topic, payload, rest = nil
    mcr = rest.nil? ? payload : rest

    puts "Delete Macro: #{mcr}"

    macro = Macro.find_by title: mcr

    if macro.nil?
      Eddie.messenger.respond topic, "ERROR: No such macro > #{mcr}"
    else
      macro.destroy

      Eddie.messenger.respond topic, "SUCCESS: Deleted macro #{mcr}"
    end

  end

  def methods_str
    return "[list,add,info,update,delete,run]"
  end

  def call( topic, payload )
    top = topic.split('/macros/').last
    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list
    when 'add'
      add topic, payload, rest
    when 'update'
      update topic, payload, rest
    when 'info'
      send_info topic, payload, rest
    when 'run'
      run_macro topic, payload, rest
    when 'delete'
      delete_macro topic, payload, rest
    else
      Eddie.messenger.respond topic, "Unknown method: #{meth}"
    end
  end

end

puts "Macro Handler Loading"
Eddie.register "macros", MacroHandler.new


=begin
{
"title":"m_test",
"desc":"Macro test!",
"commands":{
   "pub": { "id": "macro"},
   "s_test": { "testing": "TESTing" }
 }
}
{
"title":"play_sound",
"desc":"Play a sound!",
"commands": {
   "play_sound": { }
 }
}

eddie/macros/update/say
{
 "commands": {
   "remove": [ "pub" ], 
   "add": { "say": {} }
  }
}
=end
