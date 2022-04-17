# frozen_string_literal: true

require "rdm"
require_relative_expand "rdm_test_cases"

RSpec.describe Rdm do
  instance_exec(&rdm_test_cases)
end
