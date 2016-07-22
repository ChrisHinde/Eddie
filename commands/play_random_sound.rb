
def script_main arguments, cmd_name
  sound_dir = PROJECT_ROOT + '/sounds/'

  p arguments

  count = 1
  if arguments['_payload'] != ''
    count = arguments['count'].nil? ? 1 : arguments['count'] 
  end

  player = Eddie.conf['audio_player']
  system player + " `find #{sound_dir} -type f | shuf -n #{count}`" 

end
