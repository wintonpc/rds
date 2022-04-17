# frozen_string_literal: true

require "rdm"

require_relative_expand("rdm1")

RSpec.describe Rdm do
  it "works" do
    # expect(make_a_calibration(1)).to eql [:calibration, [:compound, "morphine"], 3, "none", "ignore"]
    expect(test_or2).to eql 2 # and no exception
    expect(test_kvflatten).to eql [:a, :b, 1, 2]
    1.to_s
  end
end
