require 'simplecov-cobertura'

SimpleCov.configure do
  add_filter do |source_file|
    !source_file.filename.include?('/functions/')
  end
end

SimpleCov.formatter = SimpleCov::Formatter::MultiFormatter.new([
  SimpleCov::Formatter::HTMLFormatter,
  SimpleCov::Formatter::CoberturaFormatter,
])
