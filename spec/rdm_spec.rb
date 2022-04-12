# frozen_string_literal: true

require "rdm"

require_relative_expand("rdm1")

RSpec.describe Rdm do
  it "works" do
    expect(make_a_calibration).to eql [:calibration, 2, "none", "ignore"]
  end
end
