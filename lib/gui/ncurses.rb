if not defined? Vala.config.Gui.NCurses
	Vala.config.Gui.NCurses = {}
	Vala.config.Gui.NCurses.Player = { :preferred_width => 34 }
	Vala.config.Gui.NCurses.Log = { :popup => true, :preferred_lines => 5 }
end

module Gui
	module NCurses
		class Controller
			attr_reader :strscr

			def initialize()
				require 'ffi-ncurses'
				
				begin
					@stdscr = FFI::NCurses.initscr
					FFI::NCurses.start_color
					FFI::NCurses.curs_set 0
					FFI::NCurses.raw
					FFI::NCurses.cbreak
					FFI::NCurses.noecho
					FFI::NCurses.keypad(@stdscr, 1)
					FFI::NCurses.clear

					#order is important!
					Gui::NCurses::Controller::Log.new()
					Gui::NCurses::Controller::AttackStatus.new()
					Gui::NCurses::Controller::Player.new()
					Gui::NCurses::Controller::Map.new()
					#Gui::NCurses::Controller::Input.new()
				rescue Object => e
					FFI::NCurses.endwin
					init_failed = I18n.t("init_failed", {:to => Registry.i18n[:langauge]})

					puts "FFI::NCurses: #{init_failed}: #{e}"
					Main.exit()
				end
				Main.register_exit_callback(lambda { Gui::NCurses::end })
			end
			def end()
				FFI::NCurses.endwin
			end
		end
		
		class Window
			attr_accessor :window
			attr_reader   :lines, :width, :x, :y, :data

			def update(data=nil)
				if not data.nil?
					self.write(data)
				end
				FFI::NCurses.wrefesh(self.window)
			end
			
			def write(data)
				@data = data
				FFI::NCurses.waddstr(data)
			end
			
			def resize(opts={})
				opts = {
					:width => (width or self.width),
					:lines => (lines or self.lines),
					:x     => (x     or self.x),
					:y     => (y     or self.y)
				}.merge opts
				@width = opts[:width]
				@lines = opts[:lines]
				@x     = opts[:x]
				@y     = opts[:y]

				self.window = FFI::NCurses.newwin(@lines, @width, @x, @y)

				data = @data
				self.update(data)
			end
		end

		class Port
			attr_accessor :port, :x_updaters, :y_updaters
			attr_reader   :lines, :width, :x, :y
			
			def update(data=nil)
				self.port.update(data)
			end
		
			def write(data)
				self.port.write(data)
			end
			
			def notify(opts, old)
				if (opts[:x] != old[:x]) or (opts[:lines] != old[:lines])
					self.x_updaters.each do |full_classname|
						c = (full_classname.to_s.split(/.*::/,2))[1].to_sym
						instance = Registry.actual_windows[c]
						
						opts = instance.calc_size()	
						if not opts.nil?
							if (opts[:y] != instance.y) or
								 (opts[:x] != instance.x) or 
								 (opts[:width] != instance.width) or
								 (opts[:lines] != instance.lines)
								instance.resize(opts)
							end
						end
					end
				end

				if (opts[:y] != old[:y]) or (opts[:width] != old[:width])
					self.y_updaters.each do |full_classname|
						c = (full_classname.to_s.split(/.*::/,2))[1].to_sym
						instance = Registry.actual_windows[c.to_sym]

						opts = instance.calc_size()
						if not opts.nil?
							if (opts[:y] != instance.y) or
								 (opts[:x] != instance.x) or 
								 (opts[:width] != instance.width) or
								 (opts[:lines] != instance.lines)
								instance.resize(opts)
							end
						end
					end
				end	
			end
		end
		
		class LabelledPort < Port
			attr_accessor :label
			attr_reader   :port_lines

			def resize(opts={}) 
				opts = {
					:width => (width or self.width),
					:lines => (lines or self.lines),
					:x     => (x     or self.x),
					:y     => (y     or self.y)
				}.merge opts

				old_width = self.width
				old_lines = self.lines
				old_x     = self.x
				old_y     = self.y

				self.width      = opts[:width]
				self.port_lines = opts[:lines] - 1
				self.x          = opts[:x]
				self.y          = opts[:y]

				self.label.resize({
					:lines => 1, 
					:width => self.width,
					:x     => self.x,
					:y     => self.y
				})
				self.port.resize({
					:lines => self.port_lines, 
					:width => self.width,
					:x     => self.x,
					:y     => self.y
				})

				self.notify(opts, {:width => old_width, :lines => old_lines, :x => old_x, :y => old_y})
			end
						
			def lines()
				self.port.lines + self.label.lines
			end
		end

		class Map < LabelledPort
			def initialize()
				_in = I18n.t("in", {:to => Registry.i18n[:language]})
				assert((not Registry.actual_windows[:Player].nil?), "#{_in} #{self.class}.initialize(): not ActualWindows.Player.nil?")
				assert((not Registry.actual_windows[:AttackStatus].nil?), "#{_in} #{self.class}.initialize(): not ActualWindows.AttackStatus.nil?")
				assert((not Registry.actual_windows[:Log].nil?), "#{_in} #{self.class}.initialize(): not ActualWindows.Log.nil?")

				opts   = calc_size()
				if not opts.nil?
					@label = Window.new(opts[:label][:lines], opts[:label][:width], opts[:label][:x], opts[:label][:y])
					@port  = Window.new(opts[:port][:lines], opts[:port][:width], opts[:port][:x], opts[:port][:y])
				
					@lines = opts[:port][:lines] + opts[:label][:lines]
					@width = opts[:port][:width]
					@x = opts[:port][:x]
					@y = opts[:port][:y]
				end
				
				@x_updaters = []
				@y_updaters = []

				Registry.actual_windows[:Map] = self
			end

			def calc_size()
				port_lines = TerminalHeight - ( 
					ActualWindows.AttackStatus.lines +
					ActualWindows.Log.lines)
				if not ActualWindows.Log.is_popup
					port_lines += 1
				end
				
				width = TerminalWidth - (1 + ActualWindows.Player.width)
				
				x = 0
				y = 0
				
				if width > 0 and port_lines > 0
					return {
						:label => {
							:lines => 1,
							:width => width,
							:x     => 0,
							:y     => 0
						}, :port => {
							:lines => port_lines,
							:width => width,
							:x     => 1,
							:y     => 0						
						}
					}
				else
					return nil
				end
			end
		end
		
		class Player < LabelledPort
			def initialize()
				_in = I18n.t("in", {:to => Registry.i18n[:language]})
				assert((not Registry.actual_windows[:AttackStatus].nil?), "#{_in} #{self.class}.initialize(): not ActualWindows.AttackStatus.nil?")
				assert((not Registry.actual_windows[:Log].nil?), "#{_in} #{self.class}.initialize(): not ActualWindows.Log.nil?")

				opts = calc_size()
				if not opts.nil?
					@label = Window.new(opts[:label][:lines], opts[:label][:width], opts[:label][:x], opts[:label][:y])
					@port  = Window.new(opts[:port][:lines], opts[:port][:width], opts[:port][:x], opts[:port][:y])
				
					@lines = opts[:port][:lines] + opts[:label][:lines]
					@width = opts[:port][:width]
					@x = opts[:port][:x]
					@y = opts[:port][:y]
				end

				@x_updaters = []
				@y_updaters = []
				@y_updaters.push Map

				Registry.actual_windows[:Player] = self
			end

			def calc_size()
				port_lines = TerminalHeight - ( 
					ActualWindows.AttackStatus.lines +
					ActualWindows.Log.lines)
				if not ActualWindows.Log.is_popup
					port_lines += 1
				end
				
				#First, set the width to the preferred width
				width = Vala.config.Gui.NCurses.Player.preferred_width or 34
				#then set the width to the largest value, if it was too big
				while width > TerminalWidth
					width -= 1
				end
				
				x = 0
				y = TerminalWidth - width

				if width > 0 and port_lines > 0
					return {
						:label => {
							:lines => 1,
							:width => width,
							:x     => 0,
							:y     => y
						}, :port => {
							:lines => port_lines,
							:width => width,
							:x     => 1,
							:y     => y
						}
					}
				else
					return nil
				end
			end
		end

		class AttackStatus < Port
			def initialize()
				_in = I18n.t("in", {:to => Registry.i18n[:language]})
				assert((not Registry.actual_windows[:Log].nil?), "#{_in} #{self.class}.initialize(): not ActualWindows.Log.nil?")

				opts = calc_size()
				if not opts.nil?
					@port  = Window.new(opts[:lines], opts[:width], opts[:x], opts[:y])
				
					@lines = opts[:lines] + opts[:lines]
					@width = opts[:width]
					@x = opts[:x]
					@y = opts[:y]
				end

				@x_updaters = []
				@y_updaters = []
				@x_updaters.push Map, Players

				Registry.actual_windows[:AttackStatus] = self
			end		
			
			def calc_size()
				lines = TerminalHeight - ActualWindows.Log.lines
				if lines > 1
					lines = 1
				end
				
				width = TerminalWidth
				
				x = TerminalHeight - (lines + ActualWindows.Log.lines)
				if not ActualWindows.Log.is_popup
					x += 1
				end
				y = 0

				if lines > 0
					return {
						:lines => lines,
						:width => width,
						:x     => x,
						:y     => 0
					}
				else
					return nil
				end
			end	
			
			def resize(opts={})
				old = {
					:width => @width,
					:lines => @lines,
					:x     => @x,
					:y     => @y
				}

				@width = @port.width
				@lines = @port.lines
				@x = @port.x
				@y = @port.y

				@port.resize(opts)

				notify(opts, old)
			end
		end
		
		class Log < Port
			attr_reader :is_popup

			def initialize()
				@is_popup = Vala.config.Gui.NCurses.Log.popup or true

				opts   = calc_size()
				if not opts.nil?
					if @is_popup
						@lines = opts[:port][:lines] + opts[:handle][:lines]
						@width = opts[:port][:width]
						@x = opts[:port][:x]
						@y = opts[:port][:y]
					else
						@lines = opts[:port][:lines]
						@width = opts[:port][:width]
						@x = opts[:port][:x]
						@y = opts[:port][:y]
					end

					@label = Window.new(opts[:label][:lines], opts[:label][:width], opts[:label][:x], opts[:label][:y])
					@port  = Window.new(opts[:port][:lines], opts[:port][:width], opts[:port][:x], opts[:port][:y])
				else
					@lines = -1
					@width = -1
					@x     = -1
					@y     = -1
				end

				if @lines > 0
					if @is_popup
						@handle = Window.new(     1, @width, @x,   0)
						@port   = Window.new(@lines, @width, @x+1, 0)
					else
						@port   = Window.new(@lines, @width, @x,   0)
					end
				end

				@x_updaters = []
				@y_updaters = []
				@x_updaters.push Map, Players, AttackStatus

				Registry.actual_windows[:AttackStatus] = self
			end

			def calc_size()
				#First, set the lines to the preferred value
				lines = Vala.config.Gui.NCurses.Log.preferred_lines or 5
				if @is_popup
					lines += 1
				end
				#then set the lines to the largest value, if it was too big
				while lines > TerminalHeight
					lines -= 1
				end
				width = TerminalWidth
				x = TerminalHeight - @lines
				y = 0

				if lines > 0
					if @is_popup
						return {
							:handle => {
								:lines => 1,
								:width => width,
								:x     => 0,
								:y     => 0
							}, :port => {
								:lines => port_lines,
								:width => width,
								:x     => 1,
								:y     => 0						
							}
						}
					else
						return {
							:port => {
								:lines => port_lines,
								:width => width,
								:x     => 1,
								:y     => 0						
							}
						}
					end
				else
					return nil
				end
			end

			def toggle_popup(bool)
				@is_popup = bool
				if not bool
					@handle = nil
					opts = no_popup_calc_resize()
					@port.resize(opts)
				else
					@handle = Window.new( 1, @width, @x,   0)
					opts = popup_calc_resize()
					@port.resize(opts, notifications=false)
				end
			end

			def resize(opts={})
				(@is_popup)? popup_resize(opts): no_popup_resize(opts)
			end

			def no_popup_resize(opts={})
				old = {
					:width => @width,
					:lines => @lines,
					:x     => @x,
					:y     => @y
				}

				@width = @port.width
				@lines = @port.lines
				@x = @port.x
				@y = @port.y

				@port.resize(opts)

				notify(opts, old)
			end

			def popup_resize(opts={}) 
				opts = {
					:width => (width or @width),
					:lines => (lines or @lines),
					:x     => (x     or @x),
					:y     => (y     or @y)
				}.merge opts

				old_width = @width
				old_lines = @lines
				old_x     = @x
				old_y     = @y

				@width      = opts[:width]
				@port_lines = opts[:lines] - 1
				@x          = opts[:x]
				@y          = opts[:y]

				@label.resize({
					:lines => 1, 
					:width => @width,
					:x     => @x,
					:y     => @y
				})
				@port.resize({
					:lines => @port_lines, 
					:width => @width,
					:x     => @x,
					:y     => @y
				})

				notify(opts, {:width => old_width, :lines => old_lines, :x => old_x, :y => old_y})
			end 
		end
		
	end
end
