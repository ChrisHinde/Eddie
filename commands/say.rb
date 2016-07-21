
def script_main arguments, cmd_name
  say_filename = '/tmp/eddie.wav'

  p arguments

  say = arguments['say'].nil? ? arguments['_payload'] : arguments['say'] 
  say = Command.replace_arguments say, arguments # Replace placeholders (like %value%) with appropriate value
  say.gsub!('"', '\\"')
  say.gsub!('!','')

  puts "Saying: #{say}"

  puts 'pico2wave -w=' + say_filename + ' "' + say + '"'
  system 'pico2wave -w=' + say_filename + ' "' + say + '"'
  system 'aplay ' + say_filename

  begin
    File.delete say_filename
  rescue
  end
end
