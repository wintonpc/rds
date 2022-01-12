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

    a = block_ast(proc { x + y }, full: true)
    b = Parser::CurrentRuby.parse(ast_text(a), a.location.begin.source_buffer.name)
    [a,b]
  end
  it "eval_ast" do
    x = 2
    y = 3
    expect(eval_ast(block_ast(proc { x + y }), binding)).to eql 5

    inner = eval_ast(block_ast(proc { block_ast(proc { a + b }) }), binding)
    expect(ast_text(inner)).to eql "a + b"

    inner = eval_ast(block_ast(proc { block_ast(proc { a + b }, full: true) }), binding)
    expect(ast_text(inner)).to eql "proc { a + b }"
    expect(inner.location.expression.source_buffer.name).to eql __FILE__
    expect(inner.location.begin.line).to eql __LINE__ - 3
  end
end
