class State < ActiveRecord::Base
  has_many :logs
  belongs_to :group
  belongs_to :zone

  serialize :value_map, JSON

  Types = { 'integer' => 1, 'float' => 2, 'bool' => 3, 'string' => 4 }
  StateTypes = { 'default' => 1, 'switch' => 2, 'momentary' => 3 }

  def self.value_type_to_int t
    if Types.key? t
      return Types[t]
    else
      raise 'Unrecognized type: ' + t
    end
  end
  def self.value_type_to_str t
    type = Types.key(t)

    raise 'Unrecognized type: #' + t if type.nil?

    return type
  end
  def self.state_type_to_int t
    if StateTypes.key? t
      return StateTypes[t]
    else
      raise 'Unrecognized type: ' + t
    end
  end
  def self.state_type_to_str t
    type = StateTypes.key(t)

    raise 'Unrecognized type: #' + t if type.nil?

    return type
  end

  def self.get_state part1, part2, payload, topic, filter = nil, force_zone = false, return_do_set = false
    state      = nil
    state_name = ''
    zone_name  = ''
    zone_id    = nil
    do_set     = false

#print "Filter:"
#p filter

#print "P1:"
#p part1
#print "P2:"
#p part2

    if part2 == 'set'
      do_set = true
      part2 = nil
    elsif (! part2.nil? ) && (part2.end_with? '/set')
      do_set = true
      part2.chomp! '/set'
    end

    if payload.include? '{'
      begin
        payload    = JSON.parse payload
        state_name = payload['state'].nil? ? '' : palyoad['state']
        zone_name  = payload['zone'].nil? ? '' : palyoad['zone']
      rescue
        puts "GetState: Couldn't parse payload as JSON"
      end
    end

    if part1 != '' && !part2.nil?
      zone_name  = part1
      state_name = part2
    elsif ! part1.include? '/'
      state_name = part1
    else
      zone_name,state_name = part1.split '/'
    end

#print "ZON:"
#p zone_name

#print "STN:"
#p state_name

    unless zone_name.empty?
      zone = Zone.find_by title: zone_name
      if zone.nil?
        Eddie.messenger.respond topic, "ERROR: No such zone > #{zone_name}", payload, true
        raise NotFoundException, "No such Zone > #{zone_name}!!"
      end

      zone_id = zone.id
    end

    if zone_id.nil? && !force_zone
      states = self.where title: state_name
#puts "======================================"
#p states
      state = states.to_a
    else
      state = self.find_by title: state_name, zone_id: zone_id
    end


    if state.nil?
      state_name = zone_name + '/' + state_name unless zone_name.empty?

      Eddie.messenger.respond topic, "ERROR: No such state > #{state_name}", payload, true
      raise NotFoundException, "No such state > #{state_name}!!"
    end

    return return_do_set ? [state, do_set] : state
  end

  def get_value with_label = true, map_value = true
    val = self.value

    if val.nil?
      case self.value_type
      when Types['integer'], Types['float']
        val = 0
      when Types['string']
        val = ''
      when Types['bool']
        val = false
      end
    end

    if map_value && ! value_map.nil?
      begin
        val = value_map[val] unless value_map[val].nil?
      rescue
        puts "ERROR: Couldn't map value!"
      end
    end

    if with_label && ! self.label.nil?
      return val.to_s + self.label
    else
      return val
    end
  end

  def set_value value
    puts "Set Value!"
    value_old = self.value

    case self.value_type
    when Types['string']
      self.value = value
    when Types['bool']
      if value.is_a? String
        value = remove_label value
        self.value = remap value
      elsif value.is_a? Number
        self.value = value != 0
      elsif [true, false].include? value
        self.value = value
      else
        puts "Unknown variable type for Bool"
        self.value = value
      end
    when Types['integer'], Types['float']
      if value.is_a? String
        value = remove_label value
        self.value = remap value #self.value_type == Types['integer'] ? value.to_i : value.to_f
      elsif value.is_a? Number
        self.value = value
      elsif [true, false].include? value
        self.value = value ? 1 : 0
      else
        puts "Unknown variable type for Int/Float"
        self.value = value
      end
      
    else
      puts "Unknown value type [#{self.value_type}] for #{value}"
      self.value = value
    end

    unless self.state_type == StateTypes['momentary']
      unless self.save
        raise "ERROR: Couldn't save new state value (#{value})"
      end
    end

    EventHandler.state_value_changed self, value, value_old

    if self.do_log
#      Log.log_state self, value # TODO: Fix this! <<<<<<<
    end

    return true
  end

  def get para
    val = nil

    case
    when :do_log
      val = self.do_log
    when :locked
      val = self.locked
    end

    unless val.nil?
      if val == "t" || val == "true" || val == 1 || val == true
        val = true
      else
        val = false
      end
    end

    return val
  end

  def get_full_id
    if self.zone.nil?
      return self.title
    else
      return self.zone.title + '/' + self.title
    end
  end

  def remove_label value
    return value if self.label.nil?

    if value.is_a? String and value.end_with? self.label
      value.chomp! self.label
    end

    return value
  end

  def remap value, type = nil
    type = self.value_type if type.nil?

    begin
      if value_map.value? value
        print "Remapping value "
        p value

        value = value_map.key value

        print " > "
        p value
      else
        print "No Remapping for"
        p value
      end
    rescue
      puts "Couldn't remap!"
#      p value_map
    end


    if value.is_a? String
      case type
      when Types['bool']
        value = value.downcase == "true"
      when Types['integer']
        value = value.to_i
      when Types['float']
        value = value.to_f
      end
    end

    return value
  end

end


=begin
{
	"title": "temp_room",
	"desc": "The temperature in the room",
	"label": "C",
	"value": 0,
	"value_map": 0,
	"value_type": "float"
}
=end
