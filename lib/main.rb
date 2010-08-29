module Main
	class << self
		attr_accessor :config
		@@traps = []

		def loop()
			Kernel.loop do
				sleep 1
			end
		end

		def start()
			Gui::Controller.init
			Gui::Controller.start
			Main.loop()
		end

		def trap(p)
			@@traps.push(p)
		end
		alias register_exit_callback trap
		
		def on_exit()
			@@traps.each do |p|
				p.call
			end
		end 

		def exit()
			on_exit()
			Kernel.exit()
		end
	end
end
# class alias Vala is Main
Vala = Main

["HUP", "INT", "TERM"].each do |term|
	Signal.trap(term) do
		puts "\n"
		shutting_down = "Shutting down on"
		wrapped_up = "wrapped up"
		if defined? I18n
			shutting_down = I18n.t(shutting_down, {:to => Registry.i18n[:language]})
			wrapped_up    = I18n.t(   wrapped_up, {:to => Registry.i18n[:language]})
		end
		puts "#{shutting_down} SIG" + term

		Main.on_exit
		puts "Vala: on_exit #{wrapped_up}"

		Kernel.exit()
	end
end
