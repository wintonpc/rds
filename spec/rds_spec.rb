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
    b = parse(ast_text(a), ast_file(a))
    [a,b]
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

    a = 1
    s = quasisyntax { unsyntax(a) + 2 + unsyntax { b = 3; quasisyntax { unsyntax(b) + 4 } } }
    expect(ast_text(s)).to eql "1 + 2 + 3.+(4)"
    expect(Asts.eval(s)).to eql 10

    a = 1
    s = _q { _u(a) + 2 + _u { b = 3; _q { _u(b) + 4 } } }
    expect(ast_text(s)).to eql "1 + 2 + 3.+(4)"
    expect(Asts.eval(s)).to eql 10

    s = _q { _q { _u(_u(a).m) } }
    expect(ast_text(s)).to eql "_q { _u(1.m) }"
  end
  it "nests quasisyntax" do
    four = 4
    s = quasisyntax do
      [1,
        unsyntax do
          quasisyntax do
            [2,
              unsyntax do
                quasisyntax do
                  [3,
                    unsyntax do
                      four
                    end
                  ]
                end
              end
            ]
          end
        end
      ]
    end
    expect(ast_text(s)).to eql "[1, [2, [3, 4]]]"

    a = syntax { 2 }
    s = _q { _q { _u(_u(a)) } }
    expect(ast_text(s)).to eql "_q { _u(2) }"

    a = syntax { 1 }
    s =
      _q do
        b = syntax { 2 }
        _q do
          c = syntax { 3 }
          _q { _u(_u(_u(a))) + _u(_u(b)) + _u(c) }
        end
      end
    expect(unparse(s)).to eql <<~CODE
      b = syntax {
        2
      }
      _q {
        c = syntax {
          3
        }
        _q {
          _u(_u(1)) + _u(_u(b)) + _u(c)
        }
      }
    CODE
    s = Asts.eval(s)
    expect(unparse(s)).to eql <<~CODE
      c = syntax {
        3
      }
      _q {
        _u(1) + _u(2) + _u(c)
      }
    CODE
    s = Asts.eval(s)
    expect(unparse(s)).to eql "1 + 2 + 3"
    v = Asts.eval(s)
    expect(v).to eql 6
  end
  it "unsyntax in ruby pattern" do
    pat = syntax { x in [a] }.children[1]
    s = _q do
      case [1]
      in { unsyntax: ^pat }
        a
      end
    end
    expect(ast_text(s)).to eql "case [1] in [a] then a end"
  end
  it "unsyntax_splicing cases" do
    pat = syntax { case q; in [a]; a; end }.children[1]
    s = _q do
      case x
      when case_unsyntax_splicing([pat])
      end
    end
    expect(ast_text(s)).to eql "case x in [a] then a end"
  end
  it "unsyntax in block arguments" do
    a = Parser::AST::Node.new(:arg, [:x])
    b = Parser::AST::Node.new(:kwarg, [:y])
    s = _q do
      proc { |unsyntax: a, _u2: b| _u(lvar(:x)) + _u(lvar(:y)) + 1 }
    end
    expect(ast_text(s)).to eql "proc { |x, y:| x + y + 1 }"
  end
  it "unsyntax_splicing in block arguments" do
    sargs = [
      Parser::AST::Node.new(:kwarg, [:z]),
      Parser::AST::Node.new(:optarg, [:y, Parser::AST::Node.new(:int, [1])]),
      Parser::AST::Node.new(:arg, [:x])
    ]
    s = _q do
      proc { |w, _us: sargs| w + _u(lvar(:x)) + _u(lvar(:y)) + _u(lvar(:z)) }
    end
    expect(ast_text(s)).to eql "proc { |w, x, y = 1, z:| w + x + y + z }"
  end
  it "unsyntax local assignment" do
    var = _s { a }
    b = _s { 1 }
    s = _q { _u(var)._= _u(b) }
    expect(ast_text(s)).to eql "a = 1"

    # raw lhs
    s = _q { _u(:a)._= _u(b) }
    expect(ast_text(s)).to eql "a = 1"
  end

  def lvar(name)
    Parser::AST::Node.new(:lvar, [name])
  end

  class Foo
    define_syntax(:five_plus) do |stx|
      quasisyntax { 5 + unsyntax(stx.children[0].children[2]) }
    end

    def go(n)
      five_plus(n) {}
    end
  end
  it "define_syntax" do
    # s = syntax { foo(a, b) }
    foo = Foo.new
    expect(foo.go(2)).to eql 7
    expect(foo.go(3)).to eql 8

    # foo.go_or
    # expect(foo.log).to eql [false, true]
  end
end
