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
    b = Parser::CurrentRuby.parse(ast_text(a), ast_file(a))
    [a,b]
  end
  it "eval_ast" do
    x = 2
    y = 3
    expect(eval_ast(block_ast(proc { x + y }), binding)).to eql 5

    inner = eval_ast(block_ast(proc { block_ast(proc { a + b }) }), binding)
    expect(ast_text(inner)).to eql "a + b"
    expect(ast_file(inner)).to eql __FILE__
    expect(ast_begin_line(inner)).to eql __LINE__ - 3
    expect(ast_begin_column(inner)).to eql 55

    inner = eval_ast(block_ast(proc { eval_ast(block_ast(proc { block_ast(proc { a + b }) }), binding) }), binding)
    expect(ast_text(inner)).to eql "a + b"
    expect(ast_file(inner)).to eql __FILE__
    expect(ast_begin_line(inner)).to eql __LINE__ - 3
    expect(ast_begin_column(inner)).to eql 81

    inner = eval_ast(block_ast(proc { block_ast(proc { a + b }, full: true) }), binding)
    expect(ast_text(inner)).to eql "proc { a + b }"
    expect(ast_file(inner)).to eql __FILE__
    expect(ast_begin_line(inner)).to eql __LINE__ - 3
    expect(ast_begin_column(inner)).to eql 48
  end
end
