defmacro(:syntax_rules) do |_, _, body|
  body => [:case, _, *cases, else_case]
  quasisyntax do
    proc do |_, args|
      case args
      when case_unsyntax_splicing(cases.map do |c|
        c => [:when, cpat, cbody]
        pvars = {}
        pat = transform_pattern(cpat, pvars)
        body = transform_expression(cbody, pvars, {})
        Parser::AST::Node.new(:in_pattern, [pat, nil, qwrap(body)])
      end)
      end
    end
  end
end

def qwrap(x)
  Parser::AST::Node.new(:block, [
    Parser::AST::Node.new(:send, [nil, :quasisyntax]),
    Parser::AST::Node.new(:args, []), x
  ])
end

def transform_pattern(x, pvars)
  case x
  in [:array]
    Parser::AST::Node.new(:array_pattern)
  in [:array, *pats]
    Parser::AST::Node.new(:array_pattern, pats.map { |p| transform_pattern(p, pvars) })
  in [:send, nil, var]
    pvars[var] = :single
    Parser::AST::Node.new(:match_var, [var])
  in [:erange, [:send, nil, var], nil]
    pvars[var] = :splat
    Parser::AST::Node.new(:match_rest, [Parser::AST::Node.new(:match_var, [var])])
  in Parser::AST::Node
    Parser::AST::Node.new(x.type, x.children.map { |c| transform_pattern(c, pvars) }, location: x.location)
  else
    x
  end
end

def transform_expression(x, pvars, gvars)
  x.to_s
  case x
  in [:erange, [:send, nil, id] => svar, nil] if pvars[id] == :splat
    Parser::AST::Node.new(:send, [nil, :unsyntax_splicing, svar])
  in [:send, nil, id] => svar if pvars[id] == :single
    Parser::AST::Node.new(:send, [nil, :unsyntax, svar])
  in [:lvar, ident]
    ident = gvars.fetch(ident) { gensym(gvars, ident) }
    Parser::AST::Node.new(:lvar, [ident])
  in [:lvasgn, ident, expr]
    ident = gvars.fetch(ident) { gensym(gvars, ident) }
    Parser::AST::Node.new(:lvasgn, [ident, transform_expression(expr, pvars, gvars)])
  in Parser::AST::Node
    Parser::AST::Node.new(x.type, x.children.map { |c| transform_expression(c, pvars, gvars) }, location: x.location)
  else
    x
  end
end

def gensym(gvars, ident)
  c = 1
  loop do
    name = "#{ident}_#{c}"
    if gvars.keys.include?(name)
      c += 1
    else
      gvars[ident] = name
      return name
    end
  end
end
