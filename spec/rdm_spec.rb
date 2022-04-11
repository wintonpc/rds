# frozen_string_literal: true

require "rdm"

require_relative_expand("rdm1")

RSpec.describe Rdm do
  it "works" do
    expect(five).to eql 5
  end
end
