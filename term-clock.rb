#!/usr/bin/env ruby
# Encoding: UTF-8
# Frozen_string_literal: false
# Written by Sourav Goswami
# MIT Licence
$-v = true

Warning.warn("Detected system is probably not a Linux (#{RUBY_PLATFORM}) or you are not running MRI. This could cause issues.\n") || sleep(1) unless /linux/ === RUBY_PLATFORM
abort("#{File.basename($0)} didn't find any terminal. You can run `#{File.basename($0)} --tty?' to check for a terminal...") unless STDOUT.tty?
abort("You are using #{RUBY_ENGINE.capitalize} #{RUBY_VERSION}, which is incompatible. Atleast Ruby 2.5 is Recommended...") if RUBY_VERSION.split(?.).first(2).join.to_i < 25

# Version and files
VERSION = '0.60'
ROOT = false

CHARACTERS = ROOT ? File.join(%w(/ usr share term-clock characters.txt)) : File.join(Dir.pwd, %w(term-clock characters.txt))
QUOTE = ROOT ? File.join(%w(/ usr share term-clock quotes.txt)) : File.join(Dir.pwd, %w(term-clock quotes.txt))
CONFIGURATION = ROOT ? File.join(%w(/ usr share term-clock term-clock.conf)) : File.join(Dir.pwd, %w(term-clock term-clock.conf))

# Stop flickering the clock while running in the TTYs!
COLOURTERM = ENV.key?('COLORTERM')
CLEAR = COLOURTERM ? "\e[3J\e[H\e[2J" : "\e[H"
$-n, $-s = ?\n, ?\s
CPU_USAGE = '/proc/stat'
MEMINFO = '/proc/meminfo'
SWAPINFO = '/proc/swaps'

Kernel.class_exec { define_method(:then) { |&b| b === self } } unless defined?(Kernel.then)
GC.start(full_mark: true, immediate_sweep: true)

require('io/console')

String.define_method(:colourize) do |colours: [208, 203, 198, 164, 129, 92], animate: false, pattern: 1|
	c, final = colours.dup.tap { |y| y.concat(y.reverse) }, ''

	each_line do |str|
		colour, len = c, str.length
		colour_size = colour.size - 1
		div, i, index = str.length./(colour_size.next).then { |x| x == 0 ? 1 : x }, -1, 0

		while i < len
			index += 1 if (i += 1) > 1 && i.%(div).==(0) && index < colour_size
			final << "\e[38;5;#{colour[index]}m#{str[i]}"

			if animate
				colour.shuffle! if pattern == 11
				colours.shuffle! if pattern == 12
				colour.rotate! if pattern == 7 || pattern == 9
				colour.rotate!(-1) if pattern == 8 || pattern == 10
			end
		end

		if animate
			colour.rotate! if pattern == 1
			colour.rotate!(-1) if pattern == 2
			colour.rotate! if pattern == 5
			colour.rotate!(-1) if pattern == 6
			colours.rotate! if pattern == 9
			colours.rotate!(-1) if pattern == 10
		end
	end
	final << "\e[0m"
end unless ARGV.any? { |x| x[/^\-\-no\-colour$/] }

String.define_method(:colourize) { |arg = nil| self.replace("\e[0m#{self}") } if ARGV.any? { |x| x[/^\-\-no\-colour$/] }
Float.define_method(:rpad) { |round = 2| round(round).to_s.then { |x| x.split(?.)[1]&.length&.then { |y| y < round ? x << ?0.freeze.*(round - y).freeze : x } }.to_s }

def generate_files(file, url, permission = 0644)
	begin
		t = nil

		# The files will be created as root if the user is root, no need to change ownership
		if File.exist?(file)
			STDERR.write "This will overwrite #{file} file. Accept? [N/y]: ".colourize
			return unless STDIN.gets.to_s.strip.downcase[0] == ?y
		else
			STDERR.puts "Generating #{file} file...".colourize
		end

		cols = [63, 33, 39, 44, 49, 83, 118]
		t = Thread.new { %W(\xE2\xA0\x82 \xE2\xA0\x92 \xE2\xA0\xB2 \xE2\xA0\xB6 \xE2\xA0\x94)
			.each_with_index { |x, i| print("\e[2K" + "#{x} Downloading#{?. * i}\r".colourize(colours: cols.rotate!).freeze) || sleep(0.1) } while true }

		require('net/https')

		Dir.mkdir(File.dirname(file)) unless Dir.exist?(File.dirname(file))
		File.write(file, Net::HTTP.get(URI.parse(url)))
		File.chmod(permission, file)

	rescue Errno::EACCES
		abort "Cannot write to #{file}. Permission denied.\nPlease try running #{$0} as root".colourize
	rescue SignalException, Interrupt, SystemExit
		abort "\nDownloading is aborted. This may also lead to corrupted data.".colourize
	rescue SocketError, OpenSSL::SSL::SSLError
		abort "Can't download #{file}. Is there any connection issue?".colourize
	rescue Exception => e
		puts(e.full_message)
	ensure
		t&.kill
	end

	STDERR.puts "Generated #{file} file successfully.".colourize
end

def main
	abort(
		"Configuration file #{CONFIGURATION} #{File.exist?(CONFIGURATION) ? 'cannot be read' : 'is not found'}!\nRun #{$0} --download-conf to get a #{CONFIGURATION} file.".colourize
	) unless File.readable?(CONFIGURATION)

	abort(
		"Character mapping file #{CHARACTERS} #{File.exist?(CHARACTERS) ? 'cannot be read' : 'is not found'}!\nRun #{$0} --download-characters to get a #{CHARACTERS} file.".colourize
	) unless File.readable?(CHARACTERS)

	characters = IO.read(CHARACTERS).split(/#+/).reject!(&:empty?).reduce({}) do |x, y|
		lines = y.tap(&:lstrip!).split(y[0].freeze)[1]
		max = lines.lines.max_by(&:length).length + 1
		x.merge!(y[0] => lines.lines.each { |z| z.replace(z.chomp.ljust(max) + $-n) }.join)
	end.freeze

	conf = IO.readlines(CONFIGURATION).reverse.map!(&:strip).reject! { |x| x.strip.start_with?(?#).|(x.empty?) }
	conf_reader = lambda { |a, default = ''| conf.find { |x| x.split(?=)[0].to_s.strip.downcase.eql?(a.downcase) }
		.to_s.split(?=)[1].to_s.strip.then { |x| x.empty? ? default : x }  }

	time_format = conf_reader.('time format', '%H:%M:%S')
	refresh = conf_reader.('refresh', '0.05').to_f
	animate = conf_reader.('animation', 'false').downcase == 'true'
	colours = conf_reader.('colours', '129').split(?,).map!(&:strip).then { |x| x.size < 1 ? [10, 10] : x.size == 1 ? x + x : x }
	pattern = conf_reader.('animation pattern', ?1).to_i.then { |x| x < 1 || x > 12 ? 1 : x }
	unit = conf_reader.('unit', 'mb').upcase

	bar_colour = conf_reader.('bar colour', '-1').to_i.then { |x| x < -1 ? 129 : x > 255 ? 129 : x }
	bar_text_colour = conf_reader.('bar text colour', '255').to_i.then { |x| x < 0 ? 255 : x }
	bar_text_anim_colour = 	conf_reader.('bar text animate colours', '10').split(?,).map!(&:strip).then { |x| x.size < 1 ? [129, 129] : x.size == 1 ? x + x : x }
	bar_text_anim = conf_reader.('bar text animation pattern', ?1).to_i

	username = conf_reader.('username', 'auto').then { |x| x == 'auto' ? ENV['USER'].to_s : x }.split.each(&:capitalize!).join.tap { |x| x.replace("\xF0\x9F\x91\xA4 #{x.tap(&:strip)}") }

	display_message = conf_reader.('display message', 'true') != 'false'
	message_colours = conf_reader.('message colours', '129').split(?,).map!(&:strip).then { |x| x.size < 1 ? [129, 129] : x.size == 1 ? x + x : x }
	message_animation_pattern = conf_reader.('message animation pattern', ?1).to_i

	display_quote = conf_reader.('display quote', 'true') != 'false'
	quote_colours = conf_reader.('quote colours', '184, 208, 203, 198, 164, 129, 92').split(?,).map!(&:strip).then { |x| x.size < 1 ? [129, 129] : x.size == 1 ? x + x : x }
	quote_animation_pattern = conf_reader.('quote animation pattern', ?0).to_i
	quote_refresh_time = conf_reader.('quote refresh time', '15').to_f

	morning_message = conf_reader.('Morning Message', " \xF0\x9F\x8C\x85 Good Morning  \xF0\x9F\x8C\x85")
	afternoon_message = conf_reader.('Afternoon Message', " \xF0\x9F\x8C\x87 Good Afternoon \xF0\x9F\x8C\x87")
	evening_message = conf_reader.('Evening Message', "\xF0\x9F\x8C\x86 Good Evening \xF0\x9F\x8C\x86")
	night_message = conf_reader.('Night Message', "\xF0\x9F\x8C\x83 Good Night \xF0\x9F\x8C\x83")

	puts "\e[?25l" if conf_reader.('hide cursor', 'false') == 'true'

	display = proc do |c|
		c.to_s.chars.map! { |x| x.upcase.then { |y| characters.fetch(y) { y } } }
			.then { |y| y[0].to_s.split($-n).size.times.map { |i| y.map { |z| z.lines[i] }.join.delete($-n) }.join($-n) }
	end

	display = proc do |c|
		c.to_s.chars.each { |x| x.replace(x.upcase.then { |y| characters.fetch(y) { y } }) }
			.then { |y| y[0].to_s.split($-n).size.times.map { |i| y.map { |z| z.lines[i] }.join.delete($-n) }.join($-n) }
	end

	if display_quote
		if File.readable?(QUOTE)
			quotes = IO.readlines(QUOTE).uniq.map! { |x| x.split(?\t).values_at(1, 0).each(&:strip!).join("    -".freeze) }
			quote_refreshed = Time.now.to_i
		else
			Kernel.warn(QUOTE.colourize + (File.exist?(QUOTE) ? ' is not readable' : ' does not exist').+('... Disabling quotes.').colourize)
			Kernel.warn("You may download quotes with `#{File.basename($0)} --download-quote' option".colourize)
			display_quote = false
			sleep 1
		end
	end

	gc_compact, gc_compacted = GC.respond_to?(:compact), Time.now.to_i + 7200
	q, message = display_quote ? quotes.sample : '', ''

	clocks, counter = "\xF0\x9F\x95\x8F".then { |x| 12.times.map { |y| x.next!.dup } }, 0
	anim_bars = %W(\xE2\xA0\x82 \xE2\xA0\x92 \xE2\xA0\xB2 \xE2\xA0\xB6 \xE2\xA0\xA2 \xE2\xA0\xA2 \xE2\xA0\xA2 \xE2\xA0\xA2\xE2\xA0\xA2
					\xE2\xA0\x87 \xE2\xA0\x87 \xE2\xA0\x87 \xE2\xA0\x94 \xE2\xA0\x94 \xE2\xA0\x94 \xE2\xA0\x92 \xE2\xA0\x92)
	anim_bars2 = %W(\xE2\xA0\x81 \xE2\xA0\x82 \xE2\xA0\x84 \xE2\xA0\x91 \xE2\xA0\x8A)
	quote_counter, quote_anim, anim_quote, final_quote = -1, '', '', ''

	print "\e[2J\e[H\e[3J" unless COLOURTERM
	while true
		width, time_now = STDOUT.winsize[1], Time.now.to_i

		# Calculate Memory Usage
		mem_used = if File.readable?(MEMINFO)
			mem_total, mem_available = IO.foreach(MEMINFO).first(3).then { |x| [x[0].split[1].to_f, x[2].split[1].to_f] }
			mem_total - mem_available
		else
			mem_total = mem_available = 0.0
		end

		# Calculate Swap Usage
		swap_stats = if File.readable?(SWAPINFO)
			swap_devs = IO.readlines(SWAPINFO).drop(1).map!(&:split)
			swap_total, swap_used = swap_devs.map { |x| x[2].to_f }.sum, swap_devs.map { |x| x[3].to_f }.sum

			unless swap_total.zero?
				" | \xF0\x9F\x92\x9E Swap: #{swap_used.send(:/, unit == 'MIB'.freeze ? 1024.0 : 1000.0).rpad} #{unit}/#{swap_total.send(:/, unit == 'MIB'.freeze ? 1024.0 : 1000.0).rpad} #{unit}"
			else
				''.freeze
			end
		else
			''.freeze
		end

		# Calculate battery usage
		battery = if File.readable?('/sys/class/power_supply/BAT0/charge_now'.freeze)
			begin
				status = IO.read('/sys/class/power_supply/BAT0/status'.freeze).strip.downcase
				if status == 'full'.freeze then " | \xE2\x9A\xA1".freeze
				elsif status == 'discharging'.freeze then " | \xF0\x9F\x94\x8B".freeze
				else " | \xF0\x9F\x94\x8C".freeze
				end + ' Battery: '.freeze + IO.read('/sys/class/power_supply/BAT0/charge_now'.freeze).to_i.*(100.0)./(IO.read('/sys/class/power_supply/BAT0/charge_full'.freeze).to_i).rpad.rjust(4) + ?%
			rescue Exception
				''.freeze
			end
		else
			''.freeze
		end

		# Calculate CPU usage
		cpu_usage = if File.readable?(CPU_USAGE)
			prev_data = IO.foreach(CPU_USAGE).detect { |line| line[0..2] == 'cpu'.freeze }.split.map!(&:to_f)
			Kernel.sleep(refresh)
			data = IO.foreach(CPU_USAGE).detect { |line| line[0..2] == 'cpu'.freeze }.split.map!(&:to_f)

			%w(user nice sys idle iowait irq softirq steal).each_with_index { |e, i| binding.eval "@#{e}, @prev_#{e} = #{data[i += 1]}, #{prev_data[i]}" }

			previdle, idle = @prev_idle + @prev_iowait, @idle + @iowait
			totald = idle + (@user + @nice + @sys + @irq + @softirq + @steal) -
			(previdle + (@prev_user + @prev_nice + @prev_sys + @prev_irq + @prev_softirq + @prev_steal))

			" | \xF0\x9F\xA7\xA0 CPU: #{totald.-(idle - previdle)./(totald).*(100.0).rpad.rjust(6)}% "
		else
			Kernel.sleep(refresh)
			''.freeze
		end

		message.replace(
			case Time.new.hour
				when 5..11 then morning_message
				when 12..16 then afternoon_message
				when 17..19 then evening_message
				else night_message
			end
		) if display_message

		if display_quote
			posix_time = time_now

			if anim_quote.empty?
				quote_refreshed, quote_counter = posix_time, -1
				q.replace(quotes.sample)
				anim_quote.clear
			end

			unless anim_quote.length.eql?(q.length) || posix_time > quote_refreshed + quote_refresh_time
				anim_quote << q[quote_counter += 1].to_s
				quote_anim.replace(anim_bars.rotate![0])
			else
				quote_anim.replace(anim_bars2.rotate![0])
			end

			if posix_time > quote_refreshed + quote_refresh_time
				final_quote.replace(((quote_anim[0] + $-s + anim_quote.chop!.to_s + ?|.freeze).center(width)).colourize + "\e[0m\n\n")
			else
				final_quote.replace(((quote_anim[0] + $-s + anim_quote).center(width).rstrip).colourize + "\e[5m|\e[0m\n\n")
			end
		end

		info = "#{username} | #{clocks[(counter += 1) % clocks.size]} #{Time.new.strftime('%a, %b %D')}"\
			" | \xF0\x9F\x92\xAD Memory: #{mem_used.send(:/, unit == 'MIB'.freeze ? 1024.0 : 1000.0).rpad} #{unit}/#{mem_total.send(:/, unit == 'MIB'.freeze ? 1024.0 : 1000.0).rpad} #{unit}"\
			"#{swap_stats}#{cpu_usage}#{battery}".center(width - (COLOURTERM ? 6 : 0))

		# Print to the STDOUT
		print <<~EOF
			#{CLEAR}#{
			(bar_colour != -1 ? info.chars.each { |x| x.replace("\e[48;5;#{bar_colour}m\e[38;5;#{bar_text_colour}m#{x}\e[0m") }.join : info.colourize(colours: bar_text_anim_colour))
			} #{$-s * (STDOUT.winsize[0]./(3) * width)}#{
			display.(Time.new.strftime(time_format)).lines.each { |x| x.replace(x.chomp.+($-n).then { |y| $-s * width./(2).-(y.length / 2).abs + y }) }
				.join.colourize(colours: colours, animate: animate, pattern: pattern).strip + $-n +
			final_quote + message.center(width - 2).colourize(colours: message_colours)}
		EOF

		case pattern
			when 3, 5 then colours.rotate!
			when 4, 6 then colours.rotate!(-1)
		end

		case bar_text_anim
			when 0
			when 1 then bar_text_anim_colour.rotate!
			when 2 then bar_text_anim_colour.rotate!(-1)
			else bar_text_anim_colour.shuffle!
		end

		case message_animation_pattern
			when 0
			when 1 then message_colours.rotate!
			when 2 then message_colours.rotate!(-1)
			else message_colours.shuffle!
		end

		case quote_animation_pattern
			when 0
			when 1 then quote_colours.rotate!
			when 2 then quote_colours.rotate!(-1)
			else quote_colours.shuffle!
		end

		if gc_compact && time_now > gc_compacted
			GC.compact
			gc_compacted = time_now + 7200
		end
	end
end

begin
	if ARGV[0].to_s[/^\-\-download\-conf$/]
		generate_files(CONFIGURATION, 'https://raw.githubusercontent.com/Souravgoswami/term-clock/master/term-clock/term-clock.conf')

	elsif ARGV[0].to_s[/^\-\-download\-quote$/]
		generate_files(QUOTE, 'https://raw.githubusercontent.com/Souravgoswami/term-clock/master/term-clock/quotes.txt')

	elsif ARGV[0].to_s[/^\-\-download\-characters$/]
		generate_files(CHARACTERS, 'https://raw.githubusercontent.com/Souravgoswami/term-clock/master/term-clock/characters.txt')

	elsif ARGV[0].to_s[/^\-\-download\-all$/]
		generate_files(CONFIGURATION, 'https://raw.githubusercontent.com/Souravgoswami/term-clock/master/term-clock/term-clock.conf')
		generate_files(QUOTE, 'https://raw.githubusercontent.com/Souravgoswami/term-clock/master/term-clock/quotes.txt')
		generate_files(CHARACTERS, 'https://raw.githubusercontent.com/Souravgoswami/term-clock/master/term-clock/characters.txt')

	elsif ARGV.any? { |x| x[/^\-\-help/] || x[/^\-h$/] }
		STDOUT.puts <<~EOF.lines.map!(&:colourize).join
			This is term-clock. A lightweight digital clock for your GNU/Linux system.

			Configuration: The configuration can be found in #{CONFIGURATION}.
				Read the file for more info.

			Quotes: Generally all the quotes are in #{QUOTE}.
				You can edit them if you like.

			Characters: All the characters are specified in #{CHARACTERS}.
				If you want to add a different time format in the
				configuration file, you have to make sure the character
				exist in the file. There are currently 0-9, A-Z, : characters.

			Arguments: The available arguments that #{File.basename(__FILE__)} accepts are:
					1. --download-conf         Downloads the configuration file from the internet.
					2. --download-quote        Downloads missing quote file from the internet.
					3. --download-characters   Downloads missing character mapping file.
					4. --download-all          Downloads all the necessary files to run term-clock.
					5. --help / -h             To visit this help section again.
					6. --version / -v          To review the term-clock version.
					7. --colours               Shows all the available colours
					8. --tty?                  Shows if the current terminal is TTY.
					                           [Generally code editors are not TTY]
					9. --no-colour             Disables all the colour effects [in the clock only]
		EOF

	elsif ARGV.any? { |x| x[/^\-\-version$/] || x[/^\-v$/] }
		STDOUT.print <<~EOF.each_line.map(&:colourize).join
			#{File.basename(__FILE__)} version #{VERSION}
			#{RUBY_ENGINE.capitalize} Version #{RUBY_VERSION} - #{RUBY_PLATFORM}
		EOF

	elsif ARGV[0].to_s[/^\-\-colours$/]
		STDOUT.print 15.then { |i| 6.times.map { 6.times.map { 6.times.map { "\e[48;5;#{i += 1}m#{i.to_s.center(8)}\e[0m" }.join } }
        		.each_slice(STDOUT.winsize[1] / 49).map { |x| 6.times.map { |y| x.map { |z| z.at(y) }.join($-s) }.join($-n) + $-n }.join($-n) }

	elsif ARGV[0].to_s[/^\-\-tty\?$/]
		unless STDOUT.tty?
			abort 'No Terminal Running! This program should support Tilix (terminix), GNOME Terminal, XFCE Terminal, LX '.colourize + $-n +
				'Terminal, Konsole, Terminilogy, XTerm, UXterm, etc.'.colourize + $-n +
				'Terminals like Cool-Retro-Term may not display emoji correctly.'.colourize + $-n +
				'Also note to run this program to all intents and purposes, you need noto-fonts and noto-fonts-emoji to display characters and emojis.'.colourize
		else
			<<~EOF.colourize.each_char { |x| STDOUT.print(x) || Kernel.sleep(0.001) }
				A TTY is running.
				Note that This program should support Tilix (terminix), GNOME Terminal, XFCE Terminal, LX
				Terminal, Konsole, Terminilogy, XTerm, UXterm, etc
				Terminals like Cool-Retro-Term may not display emoji correctly even if proper font(s) is/are installed.
				Also note to run this program to all intents and purposes, you need noto-fonts and noto-fonts-emoji to display characters and emojis.
			EOF
			sleep 2
			main
		end

	elsif ARGV.any? { |x| x[/^\-\-no\-colour$/] }
		main

	elsif !ARGV.empty?
		STDERR.puts "Invalid Argument #{ARGV[0].dump}!".colourize + $-n * 2 +
		"Avaiable Arguments are:
		(1) --download-conf (2) --download-quote (3) --download-characters
		(4) --download-all  (5) --help / -h      (6) --version / -v
		(7) --colours       (8) --tty?           (9) --no-colour\n".colourize + $-n +
		"Please run #{$0} --help/-h for more information...".colourize
	else
		main
	end

rescue SignalException, Interrupt, SystemExit
	puts "\e[?25h\e[0m"

rescue Errno::ENOTTY
	puts "Uh Oh! No terminal found. Please Run this in a terminal.\nOptionally run #{$0} --tty? to check for a TTY".colourize

rescue Exception
	puts "Uh oh! An Error Occurred...\n".colourize +
		"#{$!.to_s}: ".colourize + $-n +
		$!.backtrace.map { |x| "  #{x}" }.join($-n).colourize + $-n +
		?-.*(50).colourize + $-n +
		"Bug reports are appreciated".colourize
ensure
	puts "\e[?25h\e[0m\n"
end
