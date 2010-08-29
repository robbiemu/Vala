if not defined? Vala.config.gui
	Vala.config.Gui = {:type =>"NCurses"}
end

module Gui
	module Controller
		class << self
			attr_reader :screen

			def init()
				case Vala.config.Gui.type
				when "NCurses"
					require "lib/gui/ncurses"
					@screen = Gui::NCurses::Controller.new()
					Vala.config.Gui.type = "NCurses"
				end
			end

			def start()
				@screen.start()
			end

			def end()
				@screen.end()
			end
			
			def redraw()
				@screen.redraw()
			end
			
			def clear()
				@screen.clear()
			end
		end
	end
end
