
def script_main arguments, cmd_name
  sound_dir = PROJECT_ROOT + '/sounds/'

  p arguments

  if arguments['_payload'] != ''
    file = arguments['file'].nil? ? arguments['f'] : arguments['file']
  else
    return
  end

  file.gsub! '..', ''
  file.gsub! ' ', ''

  


  system "mplayer #{sound_dir}#{file}" 

end
