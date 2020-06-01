require 'rubygems'
require 'spork'
#uncomment the following line to use spork with the debugger
#require 'spork/ext/ruby-debug'

# to start fork run "spork" at the command line
# OR just
Spork.prefork do
  # Loading more in this block will cause your tests to run faster. However,
  # if you change any configuration or code from libraries loaded here, you'll
  # need to restart spork for it take effect.

  # This file is copied to spec/ when you run 'rails generate rspec:install'
  ENV["RAILS_ENV"] = 'test'
  require File.expand_path("../../config/environment", __FILE__)
  require 'rspec/rails'
  #require 'rspec/autorun'
  require 'capybara/rspec'
  require 'capybara/webkit/matchers'
  # Requires supporting ruby files with custom matchers and macros, etc,
  # in spec/support/ and its subdirectories.
  Dir[Rails.root.join("spec/support/**/*.rb")].each { |f| require f }

  # Checks for pending migrations before tests are run.
  # If you are not using ActiveRecord, you can remove this line.
  ActiveRecord::Migration.check_pending! if defined?(ActiveRecord::Migration)

  RSpec.configure do |config|
    # ## Mock Framework
    #
    # If you prefer to use mocha, flexmock or RR, uncomment the appropriate line:
    #
    # config.mock_with :mocha
    # config.mock_with :flexmock
    # config.mock_with :rr
    #

    # only run tests with :focus
    config.filter_run focus: true
    # run all if none have focus
    config.run_all_when_everything_filtered = true

    # # Remove this line if you're not using ActiveRecord or ActiveRecord fixtures
    # config.fixture_path = "#{::Rails.root}/spec/fixtures"

    # If you're not using ActiveRecord, or you'd prefer not to run each of your
    # examples within a transaction, remove the following line or assign false
    # instead of true.
    config.use_transactional_fixtures = true

    # If true, the base class of anonymous controllers will be inferred
    # automatically. This will be the default behavior in future versions of
    # rspec-rails.
    config.infer_base_class_for_anonymous_controllers = false

    # add the DSL to request scope so I could follow along.
    config.include Capybara::DSL, :type => :request

    # Run specs in random order to surface order dependencies. If you find an
    # order dependency and want to debug it, you can fix the order by providing
    # the seed, which is printed after each run.
    #     --seed 1234
    config.order = "random"

    # include mailerMacro
    config.include(MailerMacros)
    config.include(AuthMacros)

    config.before(:each) do
      if(example.options[:js])
        Capybara.app_host   = "http://rails4.test/#{ENV['RAILS_RELATIVE_URL_ROOT']}"
      else
        Capybara.app_host   = 'http://rails4.test'
      end

      reset_email # clear delivered email before each spec is run
      Timecop.return # return to unfrozen time (reset timecop)
      # User.delete_all
    end

    config.after(:each) do
      if example.exception && example.metadata[:js]
        meta = example.metadata
        filename = File.basename(meta[:file_path])
        line_number = meta[:line_number]
        screenshot_name = "screenshot-#{filename}-#{line_number}.png"
        screenshot_path = "#{Rails.root.join("tmp")}/#{screenshot_name}"

        page.save_screenshot(screenshot_path)

        puts meta[:full_description] + "\n  Screenshot: #{screenshot_path}"
      end
    #   Capybara.app_host   = 'http://rails4.test'
    #   # make sure user records are deleted after tests are run. I could use the database_cleaner,
    #   # but that seemed a bit heavy handed since I just want to truncate 1 table (and really I
    #   # only need to do this in for the test(s) that are run with self.use_transactional_fixtures = false)
    #   # User.delete_all
    #   # i think I commented this out b/c it wasn't working? Instead I moved "User.delete_all" into the
    #   # spec that needed it
    end

    Capybara.configure do |con|

      con.javascript_driver = :webkit
      # note, it's not the greatest idea to set these manually if you do not know what you are doing.
      # for instance, I set the app_host to 'http://rails4.local' since that was my local dev address
      # this seemed to work fine in most of my tests, however, when I ran specs with js: true some
      # failed because when they ran in selenium the were running using the 'http://rails4.local' dev
      # environment NOT the test environment. This created issues if the spec had database record dependencies
      # (e.g. a user record that was just created using FactoryGirl in the Test.users table)
      # 2013-12-08, fixed by creating a new virtual host, specifically for running tests. Importantly, in the
      # apache config file for this server, there is the following line:
      # RailsEnv test
      con.run_server=false

      # config.server_port = 80
    end

    config.include(Capybara::Webkit::RspecMatchers, :type => :feature)

  end

end


Spork.each_run do
  # This code will be run each time you run your specs.
  FactoryGirl.reload
  User.delete_all

end



# --- Instructions ---
# Sort the contents of this file into a Spork.prefork and a Spork.each_run
# block.
#
# The Spork.prefork block is run only once when the spork server is started.
# You typically want to place most of your (slow) initializer code in here, in
# particular, require'ing any 3rd-party gems that you don't normally modify
# during development.
#
# The Spork.each_run block is run each time you run your specs.  In case you
# need to load files that tend to change during development, require them here.
# With Rails, your application modules are loaded automatically, so sometimes
# this block can remain empty.
#
# Note: You can modify files loaded *from* the Spork.each_run block without
# restarting the spork server.  However, this file itself will not be reloaded,
# so if you change any of the code inside the each_run block, you still need to
# restart the server.  In general, if you have non-trivial code in this file,
# it's advisable to move it into a separate file so you can easily edit it
# without restarting spork.  (For example, with RSpec, you could move
# non-trivial code into a file spec/support/my_helper.rb, making sure that the
# spec/support/* files are require'd from inside the each_run block.)
#
# Any code that is left outside the two blocks will be run during preforking
# *and* during each_run -- that's probably not what you want.
#
# These instructions should self-destruct in 10 seconds.  If they don't, feel
# free to delete them.





