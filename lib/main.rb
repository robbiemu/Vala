module Main
	class << self
		attr_accessor :config
		@@traps = []

		def start()
			Gui::Controller.init
			Gui::Controller.start
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
		puts "Shutting down on SIG" + term
		Main.on_exit
		puts "Vala: on_exit wrapped up"
		Kernel.exit()
	end
end
