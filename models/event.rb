class Event < ActiveRecord::Base
  has_many :event_macros, :dependent => :delete_all
  has_many :event_tasks, :dependent => :delete_all

  has_many :macros, through: :event_macros
  has_many :tasks, through: :event_tasks

  serialize :arguments, JSON
  serialize :conditions, JSON

  Types = { 'state_change' => 1, '' => 2, 'timed' => 3 }

  
  def self.type_to_int t
    if Types.key? t
      return Types[t]
    else
      raise 'Unrecognized type: ' + t
    end
  end
  def self.type_to_str t
    type = Types.key(t)

    raise 'Unrecognized type: ' + t.to_s if type.nil?

    return type
  end

  def check_conditions args, conds = nil
    puts "Event::CheckConditions"
    conds = self.conditions if conds.nil?

    operator = args['_op'].nil? ? :and : ( args['_op'].downcase == 'or' ? :or : :and )
    result = operator == :and

    conds.each do |name,val|
      case name
      when 'state'
        result = val == args['_state'].title
      when 'value'
        result = do_comparison val, args, 'value'
      when 'value_old','old_value'
        result = do_comparison val, args, 'value_old'
      when 'time'
        result = do_time_comparison val, args
      else
        puts "Unknown condition: #{name}"
      end

      if operator == :and 
        break unless result
      elsif operator == :or
        break if result
      end
    end

    return result
  end

  def do_comparison val, args, par = 'value'
    result = false

    if val.is_a? Hash
      operator = val.keys[0]
      c_val = val[operator] # The value we compare with..

      # We can compare with another argument (like comparing value vs value_old)
      # The other argument is denoted with a colon (:), similar to symbols
      if c_val.is_a?(String) && c_val[0] == ':'
        c_val = args[value[1..-1]]
      end

      value = args[par]

      # We need them to be the same type for comparison..
      if c_val.is_a? Integer
        value = value.to_i
      elsif c_val.is_a? Float
        value = value.to_f
      end

      case operator
      when 'equal', 'eq'
        result = value == c_val
      when 'not_equal', 'ne'
        result = value != c_val
      when 'more_than', 'mt', 'greater_than', 'gt'
        result = value > c_val
      when 'more_than_equal', 'mte'
        result = value >= c_val
      when 'less_than', 'lt'
        result = value < c_val
      when 'less_than_equal', 'lte'
        result = value <= c_val
      end
    else
      result = val == args[par]
    end

    return result
  end
end
