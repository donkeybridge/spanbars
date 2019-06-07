Gem::Specification.new do |s|
  s.name        = "spanbars"
  s.version     = "0.2.3.1"
  s.date        = "2019-05-23"
  s.summary     = "Tiny tool to process input CSV data as timeseries to span bars"
  s.description = "Tiny tool to process input CSV data as timeseries to span bars "
  s.authors     = [ "Benjamin L. Tischendorf" ]
  s.email       = "donkeybridge@jtown.eu"
  s.homepage    = "https://github.com/donkeybridge/spanbars"
  s.platform    = Gem::Platform::RUBY
  s.license     = "BSD-4-Clause" 
  s.required_ruby_version = '~> 2.0'

  versioned = `git ls-files -z`.split("\0")

  s.files = Dir['{lib,features}/**/*',
                  'Rakefile', 'README*', 'LICENSE*',
                  'VERSION*', 'HISTORY*', '.gitignore'] & versioned
  s.executables = (Dir['bin/**/*'] & versioned).map { |file| File.basename(file) }
  s.test_files = Dir['features/**/*'] & versioned
  s.require_paths = ['lib']

  # Dependencies
  # s.add_dependency 'bundler', '>= 1.1.16'
  s.add_dependency 'slop', '~> 4.6'
  s.add_dependency 'csv',  '~> 3.0'
  s.add_dependency 'colorize', '~> 0.8'
  s.add_development_dependency 'rspec','~>3.6'
  s.add_development_dependency 'cucumber','~>3.1'  
  s.add_development_dependency 'yard', '~>0.9'
end

