# encoding: utf-8

module ConfigController
	class << self
		def load(fh)
			if File.exists? fh
				Vala.config = Construct.load File.open("#{fh}") { |f| f.read() }
			else
				Vala.config = Construct.new
			end
		end

		def merge(fh)
			#unimplemented
		end

		def save(construct)
			File.open("#{Registry.config[:filename]}", "w") do |fh| 
				fh.write(Vala.config.to_yaml) 
			end
		end
	end
end
Main.register_exit_callback(lambda { ConfigController.save(Config) })

ConfigController.load(Registry.config[:filename])
Registry.config[:merge].each do |fh|
	ConfigController.merge(fh)
end
