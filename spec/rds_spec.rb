# frozen_string_literal: true

# - syntax
# - quasisyntax / unsyntax
# - define_syntax: transform ast and eval
# - eval(ast, binding) -> value
# - block_ast(block)

RSpec.describe Rds do
  it "block_ast" do
    # result = proc { 5 }.source_region
    # puts result.inspect

    expect(unp(block_ast(proc { x + y }))).to eql "x + y"
    expect(unp(block_ast(proc { x + y }, full: true))).to eql "proc { x + y }"
  end
end

def unp(x)
  Unparser.unparse(x).gsub(/\n\s*/, " ")
end
