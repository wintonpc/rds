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
        gvars = {}
        fixups = []
        pat = transform_pattern(cpat, pvars, gvars, fixups)
        body = transform_expression(cbody, pvars, gvars)
        n(:in_pattern, pat, nil, n(:begin, *fixups, qwrap(body)))
      end)
      end
    end
  end
end

def qwrap(x)
  n(:send, n(:const, nil, :SyntaxRules), :fix_locals,
    n(:block, n(:send, nil, :quasisyntax), n(:args), x),
    n(:array))
end

def transform_pattern(x, pvars, gvars, fixups)
  case x
  in [:array]
    n(:array_pattern)
  in [:array, *pats]
    n(:array_pattern, *pats.map { |p| transform_pattern(p, pvars, gvars, fixups) })
  in [:send, nil, var]
    pvars[var] = 0
    n(:match_var, var)
  in [:erange, [:send, nil, var], nil]
    pvars[var] = 1
    n(:match_rest, n(:match_var, var))
  in [:erange, [:hash, [:pair, [:send, nil, k], [:send, nil, v]]], nil]
    pvars[k] = 1
    pvars[v] = 1
    kws = gensym(gvars, :kws)
    pairs = gensym(gvars, :pairs)
    spairs = lvar(pairs)
    fixups << _q { _u(pairs)._= _u(lvar(kws)).select { |x| x.type == :kwargs }.flat_map(&:children).map(&:children) }
    fixups << _q { _u(k)._= _u(spairs).map { |x| x[0] } }
    fixups << _q { _u(v)._= _u(spairs).map { |x| x[1] } }
    n(:match_rest, n(:match_var, kws))
  in Parser::AST::Node
    n(x.type, *x.children.map { |c| transform_pattern(c, pvars, gvars, fixups) })
  else
    x
  end
end

def transform_expression(x, pvars, gvars)
  x.to_s
  case x
  in [:erange, [:send, nil, id] => svar, nil] if pvars[id] == 1
    n(:send, nil, :unsyntax_splicing, svar)
  in [:send, nil, id] => svar if pvars[id] == 0
    n(:send, nil, :unsyntax, svar)
  in [:lvar, ident]
    ident = gvars.fetch(ident) { gensym(gvars, ident) }
    n(:lvar, ident)
  in [:lvasgn, ident, expr]
    ident = gvars.fetch(ident) { gensym(gvars, ident) }
    n(:lvasgn, ident, transform_expression(expr, pvars, gvars))
  in [:optarg, dummy, [:begin, [:erange, [:send, nil, id] => svar, nil]]] if pvars[id] == 1
    n(:optarg, dummy, n(:send, nil, :_us, _q { _u(svar).map { |x| SyntaxRules.as_arg(x) } }))
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
      return gvars[ident] = name.to_sym
    end
  end
end

class SyntaxRules
  class << self
    def as_arg(x)
      case x
      in Symbol
        n(:arg, x)
      in [:sym, name]
        n(:arg, name)
      end
    end

    # In ruby code, raw symbols can refer to either locals or methods. In macro transformations,
    # these tend to come through as method calls since the parser doesn't see a local assignment.
    # Unparser writes [:send, nil, :a] as "a()", which rules it out as a local, though the macro
    # may use it as one.
    def fix_locals(x, locals)
      return x unless x.is_a?(Parser::AST::Node)
      case x
      in [:block, call, [:args, *proc_args] => args, body]
        locals += proc_args.map do |pa|
          case pa
          in [:procarg0, [_, name, *_]] then name
          in [_, name, *_] then name
          end
        end
        Parser::AST::Node.new(:block, [call, args, fix_locals(body, locals)], location: x.location)
      in [:send, nil, name] if locals.include?(name)
        Parser::AST::Node.new(:lvar, [name], location: x.location)
      else
        Parser::AST::Node.new(x.type, x.children.map { |c| fix_locals(c, locals) }, location: x.location)
      end
    end
  end
end
