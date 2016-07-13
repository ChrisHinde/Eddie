class EddieServer
end

class EddieThread
  attr_accessor :client
  attr_accessor :friend

  def initialize( client, friend )
    @client = client
    @friend = friend
  end

  def talk

    loop do
      str = @client.gets.strip

      case str.upcase
      when /^EVENT/
        EventHandler.incoming str[6..-1], self
      when /^TASK/
        TaskHandler.incomig str[5..-1], self
      when /^MACRO/
        MacroHandler.incoming str[5..-1], self
      when /^COMMAND/
        CommandHandler.inoming str[8..-1], self
      when "EYB"
        return false
      else
        puts "WHAT: " + str
        tell "WAHT? <" + str + ">"
      end
    end
  end

  def tell str
    @client.puts str + "\n"
  end


end
