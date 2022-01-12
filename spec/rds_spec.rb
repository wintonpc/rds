# frozen_string_literal: true

# - syntax
# - quasisyntax / unsyntax
# - define_syntax: transform ast and eval
# - eval_ast(ast, binding) -> value
# - block_ast(block)

RSpec.describe Rds do
  it "block_ast" do
    # result = proc { 5 }.source_region
    # puts result.inspect

    expect(ast_text(block_ast(proc { x + y }))).to eql "x + y"
    expect(ast_text(block_ast(proc { x + y }, full: true))).to eql "proc { x + y }"
  end
end

def ast_text(node)
  node.location.expression.source
end
