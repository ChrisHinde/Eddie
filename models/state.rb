class State < ActiveRecord::Base

  Types = { 'integer' => 1, 'float' => 2, 'bool' => 3, 'string' => 4 }

  def self.type_to_int t
    if Types.key? t
      return Types[t]
    else
      raise 'Unrecognized type: ' + t
    end
  end
  def self.type_to_str t
    type = Types.key(t)

    raise 'Unrecognized type: #' + t if type.nil?

    return type
  end

  def get_value with_label = true, map_value = true
    val = self.value

    if map_value
      begin
        maps = JSON.parse self.value_map

        val = maps[val]
      rescue
        puts "Couldn't map value!"
      end
    end

    return val + (with_label ? self.label : '')
  end

end


=begin
{
	"title": "temp_room",
	"desc": "The temperature in the room",
	"label": "C",
	"value": 0,
	"value_map": 0,
	"type": "float"
}
=end
