source :rubygems
gem 'rails', '2.3.5'
gem 'cucumber', '0.4.0'
gem 'webrat'
gem 'rspec', '1.2.9'
gem 'rspec-rails', '1.2.9'
gem 'Selenium', '>= 1.1.14'
gem 'selenium-client', '>= 1.2.17'
gem 'database_cleaner'
gem 'exception_notification', '1.0.20090728'
gem 'system_timer'
gem 'rake'

def program(name)
  unless system("which #{name} > /dev/null")
    puts "W: Program #{name} is needed, but was not found in your PATH"
  end
end

program 'java'
program 'firefox'
