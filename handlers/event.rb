class EventHandler < BaseHandler
  include EddieMQTT_Listener

  def initialize
    Eddie.messenger.subscribe 'events/#', self
  end

  def self.add( params, thread )
    thread.tell 'Add Event!'
  end

  def methods_str
    return "[list,info,add,update]"
  end

  def send_info topic, payload, rest = nil
    evt_n = rest.nil? ? payload : rest

    evt = Event.find_by title: evt_n

    unless evt.nil?
      event = {
        id:    evt.id,
        title: evt.title,
        desc:  evt.description,
        type:  Event.type_to_str(evt.event_type),
        conditions: evt.conditions,
        macros: [],
        tasks: []
      }

      evt.event_macros.each do |mcr|
        event[:macros].push mcr
      end

      evt.event_tasks.each do |task|
        event[:tasks].push task
      end

      Eddie.messenger.respond topic, event.to_json, payload
    else
      Eddie.messenger.respond topic, "ERROR: No such event > #{evt_n}", payload, true
    end
  end

  def add topic, data_raw, rest = nil
    begin
      data = JSON.parse data_raw
    rescue
      Eddie.messenger.respond topic, 'ERROR: Payload is not valid JSON', payload, true
      return
    end

    if data['title'].empty?
      Eddie.messenger.respond topic, 'ERROR: No title given', payload, true
      return
    end

    if Event.exists?( title: data['title'] )
      Eddie.messenger.respond topic, 'ERROR: An event called ' + data['title'] +' already exists', payload, true
      return
    end

    event = Event.new

    event.title = data['title']
    event.description = data['desc']
    event.event_type = Event.type_to_int data['type']
    event.conditions = data['conditions']

    if event.save
      data['macros'].each do |mcr_t,args|
        mcr = Macro.find_by title: mcr_t

        em = EventMacro.new
        em.arguments = args
        em.macro = mcr

        event.event_macros << em if em.save
      end unless data['macros'].nil?

      data['tasks'].each do |tsk_t,args|
        tsk = Task.find_by title: tsk_t

        et = EventTask.new
        et.arguments = args
        et.task = tsk

        event.event_task << et if et.save
      end unless data['tasks'].nil?

      Eddie.messenger.respond topic, 'SUCCESS: Added ' + data['title'], payload
    else
      Eddie.messenger.respond topic, 'ERROR: Adding ' + data['title'] + " > Couldn't save!", payload, true
    end
  end

  def delete_event topic, payload, rest = nil
    evt = rest.nil? ? payload : rest

    puts "Delete Event: #{evt}"

    event = Event.find_by title: evt

    if event.nil?
      Eddie.messenger.respond topic, "ERROR: No such event > #{evt}", payload, true
    else
      event.destroy

      Eddie.messenger.respond topic, "SUCCESS: Deleted event #{evt}", payload
    end

  end

  def update topic, data_raw, rest = nil
    begin
      data = JSON.parse data_raw
    rescue
      Eddie.messenger.respond topic, 'ERROR: Payload is not valid JSON', data_raw, true
      return
    end

    evt_n = rest.nil? ? data['title'] : rest

    event = Event.find_by title: evt_n

    unless event.nil?
      event.description = data['desc'] unless data['desc'].nil?
      event.event_type  = Event.type_to_int(data['type']) unless data['type'].nil?

      unless data['macros'].nil?
        unless data['macros']['add'].nil?
          data['macros']['add'].each do |mcr_t, args|
            mcr = Macro.find_by title: mcr_t

            em = EventMacro.new
            em.arguments = args
            em.macro = mcr

            event.event_macros << em if em.save
          end
        end

        unless data['macros']['remove'].nil?
          data['macros']['remove'].each do |mcr_t|
            mcr = Macro.find_by title: mcr_t

            event.macros.delete mcr unless mcr.nil?
          end
        end
      end
      unless data['tasks'].nil?
        unless data['tasks']['add'].nil?
          data['tasks']['add'].each do |tsk_t, args|
            tsk = Task.find_by title: tsk_t

            et = EventTask.new
            et.arguments = args
            et.macro = mcr

            event.event_tasks << et if et.save
          end
        end

        unless data['tasks']['remove'].nil?
          data['tasks']['remove'].each do |tsk_t|
            tsk = Task.find_by title: tsk_t

            event.event_tasks.delete tsk unless tsk.nil?
          end
        end
      end

      if event.save
        Eddie.messenger.respond topic, 'SUCCESS: Updated ' + evt_n, data_raw
      else
        Eddie.messenger.respond topic, 'ERROR: Updating ' + evt_n + " > Couldn't save (some changes might have been made)!", data_raw, true
      end
    else
      Eddie.messenger.respond topic, "ERROR: No such event > #{evt_n}", data_raw, true
    end
  end


  def list
    events = Event.all

    evnts = []

    events.each do |event|
      evnts.push event.title
    end

    return evnts.to_json
  end

  def call( topic, payload )
    top = topic.split('/events/').last
    meth, rest = top.split('/',2)

    case meth
    when 'list'
      Eddie.messenger.respond topic, list, payload
    when 'add'
      add topic, payload, rest
    when 'update'
      update topic, payload, rest
    when 'delete'
      delete_event topic, payload, rest
    when 'info'
      send_info topic, payload, rest
    else
      Eddie.messenger.respond topic, "Unknown method: #{meth}", payload, true
    end
  end


  def self.state_value_changed state, value, old_value = nil
    puts "Event::State_Value_Changed"
#    p state
#    p value
#    p old_value
    g_args = { "_state" => state, "value" => value, "value_old" => old_value }

    events = Event.where event_type: Event::Types['state_change']

    events.each do |event|

      p event
      next unless event.check_conditions g_args

      event.event_macros.each do |em| 
        args = g_args.merge em.arguments

        em.macro.run args
      end
    end
  end

end

puts "Event Handler Loading"
Eddie.register "events", EventHandler.new

=begin
{
 "title":"event_test",
 "desc":"Event test!",
 "type": "state_change",
 "conditions": {  },
 "arguments": {}
}
{
 "title":"temp_change",
 "desc":"Event temp test!",
 "type": "state_change",
 "conditions": { "state": "temp_room", "value": { "more_than": 30 } },
 "arguments": {},
 "macros": { "say": { "say": "The temperature is too damn high!" } }
}
{
 "title":"temp_changed",
 "desc":"Event temp test!",
 "type": "state_change",
 "conditions": { "state": "temp_room" },
 "arguments": { "s": "Current Temp %value% " },
 "macros": { "say": { "say": "Current temperature is %value% degrees" } }
}
{
 "title":"door_bell_pressed",
 "desc":"Door bell event!",
 "type": "state_change",
 "conditions": { "state": "door_bell", "value": "ringing" },
 "arguments": { "file": "bell*", "random": true },
 "macros": { "play_sound": { "file": "bell_*", "select_random": true } }
}


Update:
eddie/events/update/temp_change
{
  "desc": "Temperature Event",
  "macros": { "add": { "say": { "say": "The temperature is too damn high!" } } }
}
{
  "macros": { "remove": [ "say" ] }
}
=end
