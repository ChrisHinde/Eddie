require 'json'

class StateHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'states/#', self

   # @@types = { 'internal' => 1, 'script' => 3 }

  end

  def self.add( params, thread )
    thread.tell 'Add State!'
  end
  def add_state topic, data_raw, rest = nil
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

    if State.exists?( title: data['title'] )
      Eddie.messenger.respond topic, 'ERROR: A state called ' + data['title'] +' already exists'
      return
    end

    state = State.new

    state.title       = data['title']
    state.description = data['desc']
    state.label       = data['label']
    state.value_map   = data['value_map'].to_json
    state.value       = data['value']

    begin
      state.value_type  = State.type_to_int data['type']
    rescue Exception => e
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + ' > ' + e.message
      return
    end

    if state.save
      Eddie.messenger.respond topic, 'SUCCESS: Added ' + data['title']
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + " > Couldn't save!"
    end
    p state

  end

  def list payload, rest = nil
    opt = { incl_vals: false, incl_lbls: false, map_vals: true }

    begin
      data = JSON.parse payload
      opt[:incl_vals] = data['include_values'] unless data['include_values'].nil?
      opt[:incl_lbls] = data['include_labels'] unless data['include_labels'].nil?
      opt[:map_vals]  = data['map_values'] unless data['map_values'].nil?
    rescue
      puts "States List: Not JSON options!"
    end

    stts = State.all

    states = []

    stts.each do |state|
      if opt[:incl_vals]
        states.push({ state.title => state.get_value( opt[:incl_lbls], opt[:map_vals] ) })
      else
        states.push state.title
      end
    end

    return states.to_json
  end

  def call( topic, payload )
    top = topic.split('/states/').last
    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list(payload, rest)
    when 'add'
      add_state topic, payload, rest
    when 'info'
      send_info topic, payload
#    when 'types'
#      Eddie.messenger.respond topic, @@types.keys.to_json
    else
      Eddie.messenger.respond topic, "Unknown method: #{meth}"
    end
  end


end


puts "StateHandler Loading"
Eddie.register "states", StateHandler.new

