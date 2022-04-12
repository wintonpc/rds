# frozen_string_literal: true

require "rdm"

require_relative_expand("rdm1")

RSpec.describe Rdm do
  it "works" do
    expect(make_a_calibration).to eql [:calibration, [:compound, "morphine"], 3, "none", "ignore"]
  end
end
