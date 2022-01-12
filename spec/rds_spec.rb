# frozen_string_literal: true

# - syntax
# - quasisyntax / unsyntax
# - define_syntax: transform ast and eval
# - eval(ast, binding) -> value
# - ast(block)

RSpec.describe Rds do
  it "has a version number" do
    expect(Rds::VERSION).not_to be nil
  end
end
