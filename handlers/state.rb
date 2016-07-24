require 'json'

class StateHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'states/#', self
    Eddie.messenger.subscribe 'states', self
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

#    data['zone'] = '' if data['zone'].nil?
    data['zone_id'] = nil if data['zone_id'].nil? # Just so data['zone_id'] actually exists

    unless data['zone'].nil? || data['zone'] == ''
      zone = Zone.find_by title: data['zone']

      if zone.nil?
        Eddie.messenger.respond topic, 'ERROR: No such zone > ' + data['zone'], data_raw, true
        return
      end

      data['zone_id'] = zone.id
    else
      unless data['zone_id'].nil?
        zone = Zone.find data['zone_id']
        data['zone'] = zone.nil? ? nil : zone.title
      end
    end

    if State.exists?( title: data['title'], zone_id: data['zone_id'] )
      Eddie.messenger.respond topic, 'ERROR: A state called ' + data['title']  + (data['zone'].nil? ? '' : ' in zone ' + data['zone'] ) + ' already exists', data_raw, true
      return
    end

    state = State.new

    state.title       = data['title']
    state.zone_id     = data['zone_id']
    state.description = data['desc']
    state.label       = data['label']
    state.value_map   = data['value_map']
    state.value       = data['value']
    state.value_type  = State::Types['string']
    state.state_type  = State::StateTypes['default']
    state.do_log      = data['do_log'].nil? ? false : data['do_log']
    state.locked      = false

    unless data['group'].nil? || data['group'] == ''
      group = Group.find_by title: data['group']

      if group.nil?
        Eddie.messenger.respond topic, 'ERROR: No such group > ' + data['group'], data_raw, true
        return
      end

      state.group_id = group.id
    else
      state.group_id = data['group_id'] unless data['group_id'].nil?
    end

    title = (data['zone'].nil? ? '' : data['zone'] + '/') + data['title']

    begin
      state.state_type  = State.state_type_to_int data['type'] unless data['type'].nil?
      state.value_type  = State.value_type_to_int data['value_type'] unless['value_type'].nil?
    rescue Exception => e
      Eddie.messenger.respond topic, 'ERROR: Adding ' + title + ' > ' + e.message, data_raw, true
      return
    end

    if state.save
      Eddie.messenger.respond topic, 'SUCCESS: Added ' + title, data_raw
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + title + " > Couldn't save!", data_raw, true
    end
#    p state

  end

  def delete_state topic, payload, rest
    st_n = rest.nil? ? payload : rest

    puts "State:Delete > #{st_n}"

    st = State.get_state rest, nil, payload, topic, nil, true #State.find_by title: st_n

    unless st.nil?
      if st.delete
        Eddie.messenger.respond topic, "SUCCESS: Deleted state > #{st_n}", payload
      else
        Eddie.messenger.respond topic, "ERROR: Couldn't delete state > #{st_n}", payload, true
      end
#    else
#      Eddie.messenger.respond topic, "ERROR: No such state > #{st_n}", payload, true
    end
  end

  def list topic, payload, rest = nil, zone = nil, filter = nil
    opt = { incl_vals: false, incl_lbls: false, map_vals: true }

    begin
      data = JSON.parse payload
      opt[:incl_vals] = data['include_values'] unless data['include_values'].nil?
      opt[:incl_lbls] = data['include_labels'] unless data['include_labels'].nil?
      opt[:map_vals]  = data['map_values'] unless data['map_values'].nil?
    rescue
      puts "States List: Not JSON options!"
    end

    stts = nil

    unless filter.nil?
      print "Filter: "
      p filter
    end

    if zone.nil?
      stts = State.all
    else
      puts "Zone not NIL!"
p zone
      zn = Zone.find_by title: zone

      if zn.nil?
        Eddie.messenger.respond topic, "ERROR: No such zone > #{zone}", payload, true
        raise NotFoundException, "No such Zone > #{zone}!!"
      end

      stts = zn.states
#      stts = State.all.includes(:zone).where('zones.title' => zone)
puts "Sates:"
p stts
#p sts
    end

    stts = stts.includes(:group).where('groups.title' => filter) unless filter.nil?
#p stts

    states = []

    stts.each do |state|
      zn_title = state.zone.nil? ? '' : state.zone.title + '/'
      title = (zone.nil? ? zn_title : '') + state.title

      if opt[:incl_vals]
        states.push({ title => state.get_value( opt[:incl_lbls], opt[:map_vals] ) })
      else
        states.push title
      end
    end

    return states.to_json
  end

  def send_info topic, payload, rest = nil, filter = nil
#    stt_n = rest.nil? ? payload : rest

    puts "States:Send_Info"

    stt = State.get_state rest, nil, payload, topic, filter

#    stt = State.find_by title: stt_n

    unless stt.nil?
      state = {
        id:    stt.id,
        title: stt.title,
        zone:  stt.zone.nil? ? '' : stt.zone.title,
        group: stt.group.nil? ? '' : stt.group.title,
        desc:  stt.description,
        type:  State.state_type_to_str(stt.state_type),
        label: stt.label,
        value:      stt.value,
        value_type: State.value_type_to_str(stt.value_type),
        value_map:  stt.value_map == "null" ? nil : stt.value_map,
        do_log:     stt.get( :do_log ),
        locked:     stt.get( :locked )
      }
p state

      Eddie.messenger.respond topic, state.to_json, payload
    else
      Eddie.messenger.respond topic, "ERROR: No such state > #{stt_n}", payload, true
    end
  end

  def just_state topic, payload, meth = nil, rest = nil, filter = nil
    stt_n = payload # meth.nil? ? payload : (rest.nil? ? meth : rest )
    zone = ''

#print "payl: "
#p payload
#print "meth: "
#p meth
#print "rest: "
#p rest

    args = {}
    is_json = false
    with_label = true
    map_value = true

    state,do_set = State.get_state meth, rest, payload, topic, nil, false, true 

    puts "States:Just_State " #> #{state.title}"

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

    if do_set
      if state.is_a? Array
        Eddie.messenger.respond topic, "ERROR: Ambigious state id, please specify with zone for setting! (States called '" + state[0].title + "' exists in multiple zones!)", payload, true
        return
      end

      r = false
      if is_json
        r = state.set_value args['value']
      else
        r = state.set_value payload
      end

      if r
        Eddie.messenger.respond topic, "SUCCESS: Value set to " + state.get_value(with_label, map_value), payload
      else
        Eddie.messenger.respond topic, "ERROR: Couldn't set value!", payload, true
      end
    else
      payload_out = ''
      if state.is_a? Array
        states = {}
        state.each do |st|
          states[st.get_full_id] = st.get_value(with_label, map_value)
        end

        payload_out = states.to_json
      else
        payload_out = state.get_value(with_label, map_value)
      end
      Eddie.messenger.respond topic, payload_out, payload
    end
  end

  def add_zone topic, data_raw, meth = nil, rest = nil
    puts "AddZone"

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

    if Zone.exists?( title: data['title'] )
      Eddie.messenger.respond topic, 'ERROR: A zone called ' + data['title'] +' already exists', data_raw, true
      return
    end

    zone = Zone.new

    zone.title       = data['title']
    zone.description = data['desc']
    zone.icon        = data['icon'].nil? ? 'default' : data['icon']

    if zone.save
      Eddie.messenger.respond topic, 'SUCCESS: Added ' + data['title'] + ' zone', data_raw
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + " > Couldn't save!", data_raw, true
    end
  end

  def delete_zone topic, payload, rest
    zn_n = rest.nil? ? payload : rest

    puts "Zone:Delete > #{zn_n}"

    zn = Zone.find_by title: zn_n

    unless zn.nil?
      if zn.delete
        Eddie.messenger.respond topic, "SUCCESS: Deleted zone > #{zn_n}", payload
      else
        Eddie.messenger.respond topic, "ERROR: Couldn't delete zone > #{zn_n}", payload, true
      end
    else
      Eddie.messenger.respond topic, "ERROR: No such zone > #{zn_n}", payload, true
    end
  end

  def info_zone topic, payload, rest = nil
    zn_n = rest.nil? ? payload : rest

    puts "Zone:Send_Info > #{zn_n}"

    zn = Zone.find_by title: zn_n

    unless zn.nil?
      zone = {
        id:    zn.id,
        title: zn.title,
        icon:  zn.icon,
        desc:  zn.description,
      }

      Eddie.messenger.respond topic, zone.to_json, payload
    else
      Eddie.messenger.respond topic, "ERROR: No such zone > #{zn_n}", payload, true
    end
  end

  def zones topic, payload, meth, rest, filter = nil
    puts "StateHndl::Zones"

    unless rest.nil?
      m,r = rest.split('/',2)
    else
      m = ''
    end
#print "M:"
#p m
#print "R:"
#p r

    case m
    when 'add'
      add_zone topic, payload, meth, rest
    when 'delete'
      delete_zone topic, payload, r
    when 'info'
      info_zone topic, payload, r
    else
      zns = Zone.all
      zones = []

      zns.each do |zone|
        zones.push zone.title
      end

      Eddie.messenger.respond topic, zones, payload
    end
  end


  def add_group topic, data_raw, meth = nil, rest = nil
    puts "AddGroup"

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

    if Group.exists?( title: data['title'] )
      Eddie.messenger.respond topic, 'ERROR: A group called ' + data['title'] +' already exists', data_raw, true
      return
    end

    group = Group.new

    group.title       = data['title']
    group.description = data['desc']
    group.icon        = data['icon'].nil? ? 'default' : data['icon']

    if group.save
      Eddie.messenger.respond topic, 'SUCCESS: Added ' + data['title'] + ' group', data_raw
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + " > Couldn't save!", data_raw, true
    end
  end

  def info_group topic, payload, rest = nil, filter = nil
    grp_n = rest.nil? ? payload : rest

    puts "Group:Info_Group > #{grp_n}"

    grp = Group.find_by title: grp_n

    unless grp.nil?
      group = {
        id:    grp.id,
        title: grp.title,
        icon:  grp.icon,
        desc:  grp.description,
      }

      Eddie.messenger.respond topic, group.to_json, payload
    else
      Eddie.messenger.respond topic, "ERROR: No such group > #{grp_n}", payload, true
    end
  end

  def groups topic, payload, meth = nil, rest = nil, filter = nil
    puts "StateHndl::Groups"
    unless rest.nil?
      m,r = rest.split('/',2)
    else
      r = ''
    end

    case m
    when 'add'
      add_group topic, payload, meth, rest
    when 'info'
      info_group topic, payload, r
    else
      grps = Group.all
      groups = []

      grps.each do |group|
        groups.push group.title
      end

      Eddie.messenger.respond topic, groups, payload
    end    
  end

  def methods_str
    return "[list,info,add,delete,types,groups,zones]"
  end


  def call( topic, payload )
puts "\n\n"
puts "State::Call"
    top    = topic.split('/states/').last
    filter = nil

    if top.last == ']'
      top, filter = top.split '['
      filter.chomp! ']'
      p top
      p filter
    end

    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list(topic, payload, rest, nil, filter), payload
    when '_methods'
      Eddie.messenger.respond topic, methods_str, payload
    when 'add'
      add_state topic, payload, rest
    when 'delete'
      delete_state topic, payload, rest
    when 'info'
      send_info topic, payload, rest, filter
    when 'types'
      Eddie.messenger.respond topic, State::StateTypes.keys.to_json
    when 'groups'
      groups topic, payload, meth, rest, filter
    when 'zones'
      zones topic, payload, meth, rest, filter
    else
#print "R:"
#p rest
#print "M:"
#p meth
      if rest == "list"
        begin
          Eddie.messenger.respond topic, list(topic, payload, rest, meth, filter), payload
        rescue NotFoundException => e
          p e
        end
      elsif rest == 'states' || meth == 'eddie' # Could this done better??
        Eddie.messenger.respond topic, "NOTICE! Available methods are: " + methods_str, payload
      else
        just_state topic, payload, meth, rest, filter
      end
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
        "title": "temperature",
        "zone": "outside",
        "desc": "The temperature outside",
        "group": "temperature",
        "value": 0,
        "label": "C",
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

-
{
	"title":"door",
	"zone":"",
	"group":"entrance",
	"desc":"What is the door",
	"type":"default",
	"label":"",
	"value":true,
	"value_type":"bool",
	"value_map":{
		"true":"open",
		"false":"closed"
	},
	"do_log":false
}
{
	"title":"door_bell",
	"zone":"",
	"group":"",
	"desc":"The bell at the door",
	"type":"momentary",
	"label":"",
	"value":false,
	"value_type":"bool",
	"value_map": {
		"false":"silent",
		"true":"ringing"
	},
	"do_log":false
}
{
	"title":"bed_lamp",
	"zone":"room",
	"group":"light",
	"desc":"The lamp by the bed",
	"type":"default",
	"label":null,
	"value":false,
	"value_type":"bool",
	"value_map": {
		"false":"off",
		"true":"on"
	},
	"do_log":false
}
{
	"title":"temperature",
	"zone":"room",
	"group":"temperature",
	"desc":"The temperature in the room",
	"type":"default",
	"label":"C",
	"value":0,
	"value_type":"float",
	"value_map":null,
	"do_log":true
}
{
	"title":"temperature",
	"zone":"outside",
	"group":"temperature",
	"desc":"The temperature outside",
	"type":"default",
	"label":"C",
	"value":0,
	"value_type":"float",
	"value_map":null,
	"do_log":true
}



eddie/states/groups/add
{
        "title": "entrance",
        "desc": "Group for all entrances: doors/windows",
        "icon": "door"
}
{
	"title": "light",
	"desc": "Group for all lights/lamps",
	"icon": "lamp"
}
{
	"title": "temperature",
	"desc": "Group for all temperature sensors",
	"icon": "temp"
}

eddie/states/zones/add
{
	"title": "room",
	"desc": "Bedroom",
	"icon": "bed"
}

=end
