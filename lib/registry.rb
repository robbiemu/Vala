module Registry
	class << self
		attr_accessor :actual_windows, :config, :debug, :i18n
	end
end
Registry.actual_windows = {}
Registry.config = {}
Registry.i18n = {}
