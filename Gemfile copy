source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2.1'
gem 'mysql2', '0.3.13'
gem 'sass-rails', '~> 4.0.0' # Use SCSS for stylesheets
gem 'yui-compressor'
gem 'uglifier', '>= 1.3.0' # Use Uglifier as compressor for JavaScript assets
gem 'slim'
# Use CoffeeScript for .js.coffee assets and views
#gem 'coffee-rails', '~> 4.0.0'
# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

gem 'jquery-rails' # Use jquery as the JavaScript library
gem 'turbolinks', '~> 2.5.3' # Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
gem "recaptcha", require: "recaptcha/rails" # recaptcha gem
gem 'exception_notification'
gem 'bcrypt-ruby', '~> 3.0.0' # Use ActiveModel has_secure_password

group :doc do
  gem 'sdoc', require: false # bundle exec rake doc:rails generates the API under doc/api.
end

group :development do
  gem 'letter_opener'
  gem "migration_comments" # allows you to add comments to tables
  gem 'capistrano',  '~> 3.1'
  gem 'capistrano-rails'
  gem 'capistrano-bundler'
end

group :production do
  gem "non-stupid-digest-assets" # generate static and non-static assets
end

group :test, :development do
  gem 'rspec-rails'
  gem 'pry'
  gem 'pry-remote'
end

group :test do
  gem 'factory_girl_rails'
  gem 'guard-rspec'
  gem 'timecop'
  gem 'spork', github: 'sporkrb/spork'
  gem 'spork-rails', github: 'sporkrb/spork-rails'
 	gem 'guard-spork', github: 'guard/guard-spork'
end
