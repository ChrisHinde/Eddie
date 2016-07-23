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

    if map_value
      begin
        val = value_map[val] unless value_map[val].nil?
      rescue
        puts "Couldn't map value!"
      end
    end

    p val

    if with_label
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
      Log.log_state self, value
    end

    return true
  end


  def remove_label value
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
