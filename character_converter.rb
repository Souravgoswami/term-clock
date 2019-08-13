#!/usr/bin/env ruby

warn "Ruby version 2.5+ is recommended to run both this and term-clock... You are currently running #{RUBY_ENGINE.capitalize} #{RUBY_VERSION}" if RUBY_VERSION.split(?.).first(2).join.to_i < 25

# For regular term-clock
FILE = File.join(__dir__, %w(term-clock characters.txt))

# For root installation
# FILE ||= File.join(%w(/ usr share term-clock characters.txt))

Kernel.define_method(:then) { |&block| block.(self) } unless defined?(Kernel.then)

def convert(file, char)
	require 'timeout'

	abort ":: You shouldn't use # as the replacing character.\nTip: Please use something else..." if char.eql?(?#)
	anim = %W(\xE2\xA0\x81 \xE2\xA0\x82 \xE2\xA0\x84 \xE2\xA0\x91 \xE2\xA0\x8A)

	if char.bytesize > 3 || char.length > 1
		text = if char.bytesize > 3
			%Q(An emoji like "#{char}" could create problems in term-clock. You may want to use something else?)
		else
			"Looks like you have #{char.length} characters rather than 1.This could create problems while running term-clock..."
		end

		w = Thread.new do
			text.tap do |x|
				x.length.times { |y| print(" \e[2K#{anim.rotate![0]} #{x[0..y]}\r") || sleep(0.01) }
			end.tap { |x| x.length.times { |y| print(" \e[2K#{anim.rotate![0]} #{x[y..-1]}\r") || sleep(0.025) } } while true
		end

		begin
			Timeout.timeout(3) do STDIN.gets end
		rescue Exception
		end
		puts ?\n * 2
		w.kill
	end

	puts "Reading file #{file}..."
	data = IO.read(file)

	puts 'Searching for characters...'
	ch = data.split(?#).reject(&:empty?)[0].strip.split[-1][0]

	abort %Q(Looks like the old character "#{ch}" is same as the replacing character "#{char}".\nThere's no need to continue...) if ch.eql?(char)

	puts %Q(Replacing "#{ch}" with "#{char}"...)
	new_data = data.each_line.map { |x| x.strip.start_with?(?#) ? x : x.gsub(ch, char) }.join

	t = Thread.new do
		loop do
			ch = ''
			'Press Enter to review the new data.........'.each_char { |x| print(" \e[2K#{anim.rotate![0]} :: #{ch.concat(x)}\r") || sleep(0.025) }
			ch.each_char { print(" \e[2K#{anim.rotate![0]} :: #{ch.chop!}\r") || sleep(0.075) }
		end
	end

	begin
		STDIN.gets
	rescue Exception
		exit! 0
	end

	t.kill
	puts new_data

	t = Thread.new do
		"Press Enter to write the data to #{File.basename(file)}. [ctrl + c] to exit...".tap do |x|
			x.length.times { |i| print(" \e[2K#{anim.rotate![0]} :: #{x[0...i]}#{x[i].swapcase}#{x[i.next..-1]}\r") || sleep(0.025) }
			x.length.times { |i| print(" \e[2K#{anim.rotate![0]} :: #{x[i..-1]}#{x[0..i]}\r") || sleep(0.025) }
		end while true
	end

	begin
		STDIN.gets
	rescue Exception
		puts ?\n * 2
		exit! 0
	end
	t.kill

	begin
		File.write(file, new_data)
		puts "Successflly overwritten #{file}..."
	rescue Errno::EACCES
		STDERR.puts "Sorry, but it looks like you don't have permission to write #{file}"
	rescue Exception => e
		STDERR.puts "\e[4mSorry #{File.basename($0)} Encountered an Error :(\e[0m\n#{e.backtrace.join}\n\n#{e.full_message}"
	end
end

if ARGV.any? { |x| x[/(^\-\-help$)|(^\-h$)/] }
	puts <<~EOF
		This is the character converter for term-clock!

		Generally you can change the term-clock characters by editing the characters.txt.
		But to make it easier, if you want to change all the character to something else,
		you can use this program.

		This program will detect the characters, take care of comments, iterate over the
		uncommented lines and replace the characters to your specification.

		Arguments:
			--char=<char>/-c=<char>    Specify the character you want to see.
			--file=<file>/-f=<file>    Specify the character file [default: #{FILE}].
			--help/-h                  Display this this help message.

		Usage examples:
			1. Replace the characters with 0
				#{$0} --char=0
			2. Specify a different characters file:
				#{$0} --file=./term-clock/characters.txt

		Limitation:
			Although it term-clock can work with most of the characters,
			but specifying something unsupported will break the look. That's why you need to
			confirm if the file looks right by pressing the enter key.

			You can specify an \e[1mASCII character\e[0m or \e[1mUTF characters\e[0m like these:
				\xE2\x96\xBC \xE2\xAC\xA2 \xE2\x98\xBB \xE2\x98\xA2 \xE2\x98\x98 \xE2\x97\xBC \xE2\x98\x85 \xE2\xAC\xA4
				\xE2\xAC\x9E\xE2\xA0\xB6 \xE2\xA0\x81 1 a % 6

			Emojis like \xF0\x9F\x95\x97 \xF0\x9F\x8C\x86 \xF0\x9F\x8C\x9A \xE2\x9B\xB2 \e[4mare bound to cause issues.\e[0m

			\e[1mASCII # character is unsupported because it's used to specify the name of the characters in the file.\e[0m

			This program is limited to changing all the character in the character file. It cannot
			change different display characters to different characters.

	EOF
	exit 0
end

file = 	ARGV.find { |x| x[/(^\-\-file=.+$)|(^\-f=.+$)/] }.then { |x| x ? x.split(?=)[1].to_s : FILE }
File.readable?(file) ? "Using #{file}" : File.exist?(file) ? Kernel.abort("#{file} is not readable!") : Kernel.abort("#{file} doesn't exist!")

convert(
	file,
	ARGV.find { |x| x[/(^\-\-char=.+$)|(^\-c=.+$)/] }.tap { |x| Kernel.abort("No character given... Usage -c=<character>") unless x }.split(?=)[-1]
)
