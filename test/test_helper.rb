ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "mocha/minitest"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    # Individual test classes can disable fixtures by setting:
    # self.use_transactional_tests = false
    fixtures :all

    # Add more helper methods to be used by all tests here...
  end
end
