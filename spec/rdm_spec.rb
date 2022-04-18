# frozen_string_literal: true

require "rdm"

$rdm_test_cases = []

def add_test(name, &block)
  $rdm_test_cases.push([name, block])
end

require_relative_expand "rdm_tests"
# require_relative_expand "proto_tests"

RSpec.describe Rdm do
  $rdm_test_cases.each do |(name, f)|
    it name do
      instance_exec(&f)
    end
  end
end
