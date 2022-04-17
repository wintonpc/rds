require "rds/syntax_helpers"
using SyntaxHelpers

defmacro(:syntax_rules) do |stx|
  body = stx.last
  body => [:case, _, *cases, else_case]
  quasisyntax do
    proc do |(_, *args)|
      case args
      when case_unsyntax_splicing(cases.map do |c|
        c => [:when, cpat, cbody]
        pvars = {}
        pat = transform_pattern(cpat, pvars)
        body = transform_expression(cbody, pvars, {})
        n(:in_pattern, pat, nil, qwrap(body))
      end)
      end
    end
  end
end

def qwrap(x)
  n(:block, n(:send, nil, :quasisyntax), n(:args), x)
end

def transform_pattern(x, pvars)
  case x
  in [:array]
    n(:array_pattern)
  in [:array, *pats]
    n(:array_pattern, *pats.map { |p| transform_pattern(p, pvars) })
  in [:send, nil, var]
    pvars[var] = :single
    n(:match_var, var)
  in [:erange, [:send, nil, var], nil]
    pvars[var] = :splat
    n(:match_rest, n(:match_var, var))
  in Parser::AST::Node
    n(x.type, *x.children.map { |c| transform_pattern(c, pvars) })
  else
    x
  end
end

def transform_expression(x, pvars, gvars)
  case x
  in [:erange, [:send, nil, id] => svar, nil] if pvars[id] == :splat
    n(:send, nil, :unsyntax_splicing, svar)
  in [:send, nil, id] => svar if pvars[id] == :single
    n(:send, nil, :unsyntax, svar)
  in [:lvar, ident]
    ident = gvars.fetch(ident) { gensym(gvars, ident) }
    n(:lvar, ident)
  in [:lvasgn, ident, expr]
    ident = gvars.fetch(ident) { gensym(gvars, ident) }
    n(:lvasgn, ident, transform_expression(expr, pvars, gvars))
  in Parser::AST::Node
    n(x.type, *x.children.map { |c| transform_expression(c, pvars, gvars) })
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
