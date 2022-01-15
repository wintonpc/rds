# frozen_string_literal: true

# - syntax
# - quasisyntax / unsyntax
# - define_syntax: transform ast and eval
# - eval_ast(ast, binding) -> value
# - block_ast(block)

RSpec.describe Rds do
  it "block_ast" do
    expect(ast_text(syntax { x + y })).to eql "x + y"
    expect(ast_text(block_ast(proc { x + y }, full: true))).to eql "proc { x + y }"

    a = block_ast(proc { x + y }, full: true)
    b = Parser::CurrentRuby.parse(ast_text(a), ast_file(a))
    [a,b]
  end
  it "eval_ast" do
    x = 2
    y = 3
    expect(Asts.eval(syntax { x + y })).to eql 5

    inner = Asts.eval(syntax { syntax { a + b } })
    expect(ast_text(inner)).to eql "a + b"
    expect(ast_file(inner)).to eql __FILE__
    expect(ast_begin_line(inner)).to eql __LINE__ - 3
    expect(ast_begin_column(inner)).to eql 40

    inner = Asts.eval(syntax { Asts.eval(syntax { syntax { a + b } }) })
    expect(ast_text(inner)).to eql "a + b"
    expect(ast_file(inner)).to eql __FILE__
    expect(ast_begin_line(inner)).to eql __LINE__ - 3
    expect(ast_begin_column(inner)).to eql 59

    inner = Asts.eval(syntax { block_ast(proc { a + b }, full: true) })
    expect(ast_text(inner)).to eql "proc { a + b }"
    expect(ast_file(inner)).to eql __FILE__
    expect(ast_begin_line(inner)).to eql __LINE__ - 3
    expect(ast_begin_column(inner)).to eql 41

    inner = Asts.eval(syntax { block_ast(   proc   {
        a +
            b
    }, full: true) })
    expect(ast_file(inner)).to eql __FILE__
    expect(ast_begin_line(inner)).to eql __LINE__ - 5
    expect(ast_begin_column(inner)).to eql 44
    expr = inner.children[2]
    expect(ast_begin_line(expr)).to eql __LINE__ - 7
    expect(ast_begin_column(expr)).to eql 8

    get_an_ast = proc do
      block_ast(proc { a + b })
    end

    inner1 = Asts.eval(block_ast(proc { get_an_ast.() }))
    inner2 = Asts.eval(block_ast(proc { get_an_ast.() }))
    expect(inner1).to be inner2
  end
  it "syntax" do
    s = syntax { a + b }
    expect(s).to be_a AST::Node
    expect(ast_text(s)).to eql "a + b"
  end
  it "quasisyntax" do
    s1 = syntax { foo(a) }
    s2 = quasisyntax { b + unsyntax(s1) }
    expect(ast_text(s2)).to eql "b + foo(a)"
  end
end
