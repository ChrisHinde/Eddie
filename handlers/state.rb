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
      Eddie.messenger.respond topic, 'ERROR: Payload is not valid JSON', data_raw, true
      return
    end

    if data['title'].empty?
      Eddie.messenger.respond topic, 'ERROR: No title given', data_raw, true
      return
    end

    if State.exists?( title: data['title'] )
      Eddie.messenger.respond topic, 'ERROR: A state called ' + data['title'] +' already exists', data_raw, true
      return
    end

    state = State.new

    state.title       = data['title']
    state.description = data['desc']
    state.zone        = data['zone'] unless data['zone'].nil?
    state.label       = data['label']
    state.value_map   = data['value_map'].to_json
    state.value       = data['value']
    state.value_type  = State::Types['string']
    state.state_type  = State::StateTypes['default']

    begin
      state.state_type  = State.state_type_to_int data['type'] unless data['type'].nil?
      state.value_type  = State.value_type_to_int data['value_type'] unless['value_type'].nil?
    rescue Exception => e
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + ' > ' + e.message, data_raw, true
      return
    end

    if state.save
      Eddie.messenger.respond topic, 'SUCCESS: Added ' + data['title'], data_raw
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + " > Couldn't save!", data_raw, true
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

  def send_info topic, payload, rest = nil
    stt_n = rest.nil? ? payload : rest

    puts "States:Send_Info > #{stt_n}"

    stt = State.find_by title: stt_n

    unless stt.nil?
      state = {
        id:    stt.id,
        title: stt.title,
        zone:  stt.zone,
        desc:  stt.description,
        type:  stt.state_type,
        label: stt.label,
        value:      stt.value,
        value_type: stt.value_type,
        value_map:  stt.value_map
      }

      Eddie.messenger.respond topic, state.to_json, payload
    else
      Eddie.messenger.respond topic, "ERROR: No such state > #{stt_n}", payload, true
    end
  end

  def just_state topic, payload, meth = nil, rest = nil
    stt_n = payload # meth.nil? ? payload : (rest.nil? ? meth : rest )
    zone = ''

    if payload.include? '{'
      payload = JSON.parse payload
      stt_n   = payload['state'].nil? ? '' : palyoad['state']
    end

    # Ughhh.. This became rather ugly, might try to find a better way for specifying zones
    unless meth.nil?
      if rest.nil?
        stt_n = meth
        rest  = ''
      else
        if rest.include? '/'
          stt_n, rest = rest.split '/', 2
        else
          stt_n = rest
        end

        if stt_n == 'set'
          stt_n = meth
        else
          zone  = meth
        end
      end
    end

    args = {}
    is_json = false
    with_label = true
    map_value = true

    puts "States:Just_State > #{stt_n}"

    stt = State.find_by title: stt_n

    unless payload.nil?
      begin
        args = JSON.parse payload

        with_label = args['with_label'] unless args['with_label'].nil?
        map_value  = args['map_value'] unless args['map_value'].nil?

        is_json = true
      rescue
        puts "Not JSON!"
      end
    end

    unless stt.nil?
      case rest
      when "set"
        r = false
        if is_json
          r = stt.set_value args['value']
        else
          r = stt.set_value payload
        end

        if r
          Eddie.messenger.respond topic, "SUCCESS: Value set to " + stt.get_value(with_label, map_value), payload
        else
          Eddie.messenger.respond topic, "ERROR: Couldn't set value!", payload, true
        end
      else
        Eddie.messenger.respond topic, stt.get_value(with_label, map_value), payload
      end
    else
      Eddie.messenger.respond topic, "ERROR: No such state > #{stt_n}", payload, true
    end
  end

  def call( topic, payload )
    top = topic.split('/states/').last
    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list(payload, rest), payload
    when 'add'
      add_state topic, payload, rest
    when 'info'
      send_info topic, payload, rest
#    when 'types'
#      Eddie.messenger.respond topic, @@types.keys.to_json
    else
      just_state topic, payload, meth, rest
      #Eddie.messenger.respond topic, "Unknown method: #{meth}"
    end
  end


end


puts "StateHandler Loading"
Eddie.register "states", StateHandler.new

=begin
{ "map_value": true, "with_label": false }

eddie/states/add
{
        "title": "temp_room",
        "desc": "The temperature in the room",
        "label": "C",
        "value": 0,
        "value_map": 0,
        "value_type": "float"
}

{
	"title": "door_bell",
	"desc": "The bell at the door",
	"label": "",
	"type": "momentary",
	"value": false,
	"value_map": {
		"false": "silent",
		"true": "ringing"
	},
	"value_type": "bool"
}


=end
