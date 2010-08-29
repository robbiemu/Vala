#!/usr/bin/env ruby
#encoding: utf-8

require 'construct'

$:.push(".").uniq!
require 'lib/main'
require 'lib/i18n'
	Dir.glob("i18n/*").reject{ |e| e =~ /(?:~|.swp)$/}.select{|e| not File.directory? e  }.each do |fh|
		# files not matching gedit and vi temporary files
		dict = (fh.split("/"))[1]
		I18n.add_dictionary(dict, YAML.load_file(fh) || {})
		puts "I18n: << #{dict} (#{fh})"
end
 
require 'lib/registry'
	Registry.i18n[:language]   = :en
	Registry.config[:filename] = "vala.conf"
	Registry.config[:merge]    = ["~/.vala.rc"]
	Registry.debug             = true
	
def assert(*arg)
	if Registry.debug
		unless arg.shift
			assertion = I18n.t("Assertion failed", {:to => Registry.i18n[:language] })
			if arg.length > 1
				raise "#{assertion}: #{arg}"
			elsif arg.length == 1
				raise "#{assertion}: #{arg[0]}"
			else
				raise "#{assertion}!"
			end
		end
	end
end 

require 'lib/config'
	if not defined? Vala.config.I18n
		Vala.config.I18n = {:language => :en}
	else
		Registry.i18n[:language] = Vala.config.I18n
	end

	if defined? Vala.config.debug
		Registry.debug = Vala.config.debug
	end

	if defined? Vala.config.merge
		Registry.config[:merge] = Vala.config.merge
	end
require 'lib/gui'

Main.start()
