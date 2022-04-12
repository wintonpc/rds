# frozen_string_literal: true

require "rdm"

require_relative_expand("rdm1")

RSpec.describe Rdm do
  it "works" do
    expect(make_a_calibration1).to eql [:calibration, 2, "none", "ignore"]
    expect(make_a_calibration2).to eql [:calibration, 2, "none", "ignore"]
  end
end
