class OutputType
	class Default
		# File name is for checking the existence of outputs
		def file_name(rule_name, scope = '')
			scope.to_s + (scope.empty? ? '' : '/') + rule_name
		end

		# Real name is for further processing, like schema.table_name in database
		# defaultly the file is the output, but when the file is merely a placeholder
		# the two will differ
		def real_name(rule_name, scope = '')
			file_name
		end

		def ext
			res = self.class.to_s
			res[0] = res[0].downcase
			res
		end
	end

	class Table < Default
		def real_name(file_name, scope = '')
			stem = file_name.gsub(/\.table$/, '')
			scope.to_s + (scope.empty? ? '' : '.') + stem
		end
	end

	def create(sym)
		self.class.const_get(sym.capitalize).new || Default.new
	end

	def self.parse_option(opt)
		opt.map { |obj| obj.class == Symbol ? create(obj) : obj }
	end
end
