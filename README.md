# Term-Clock ⏰
#### A Configurable and Colourful Terminal Clock...
![RPi](https://github.com/Souravgoswami/term-clock/blob/master/Screenshots/Raspberry%20Pi.jpg)

# Dependencies ➕
  + Ruby: The program is written in Ruby. So you need to download the Ruby interpreter (ruby 2.5+) to run:
      `ruby term-clock.rb`

  + Fonts: The noto-fonts and noto-fonts-emoji are neededto display unicode characters used in this program.
  
# Usage and Running 🔄
  + Term-clock root installer will be coming soon. However, this repo is only for non-root usage. You can grab the [source code](https://github.com/Souravgoswami/term-clock/blob/master/term-clock.rb) and run it with --download-all option.
  + If you zip download the files, you have to run the `term-clock.rb`.
  
  Note that this program is only for GNU/Linux. But it's tested on Termux. It should also run on BSDs and MacOS though we can't guarantee the support.

# Configuration ⚙️
   Read and edit the [configuration file](https://github.com/Souravgoswami/term-clock/blob/master/term-clock/clock.conf)
   according to your need.

# Arguments 💡
Arguments: The available arguments that term-clock.rb accepts are:

+ --download-conf         Downloads the configuration file from the internet [gihub]
+ --download-quote        Downloads missing quote file from the internet [github]
+ --download-characters   Downloads missing character mapping file.
+ --download-all          Downloads all the necessary files to run term-clock.
+ --help / -h             To visit this help section again.
+ --version / -v          To review the term-clock version.
+ --colours                Shows all the available colours.
+ --tty?                  Shows if the current terminal is TTY.
		                           [Generally code editors are not TTY]
					   
# Converter
Let me talk about the ![converter](https://github.com/Souravgoswami/term-clock/blob/master/character_converter.rb) a bit.
It converts all the characters in the characters.txt to something else you specify. It isn't directly related to term-clock, but if you are interested, run `ruby character_converter.rb -c='your_character'` where your character is a single digit character. Note that this and term-clock is only tested on various GNU/Linux systems.

# Preview 📸
![Screenshot 1](https://github.com/Souravgoswami/term-clock/blob/master/Screenshots/1.png)
![Screenshot 2](https://github.com/Souravgoswami/term-clock/blob/master/Screenshots/1.png)
