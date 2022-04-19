# frozen_string_literal: true

require "unparser"

def ast_text(node, pretty: false)
  s = unparse(node)
  (pretty ? s : s.gsub(/\s*\n\s*/, " ")).strip
end

def ast_file(node)
  if !node.location
    raise "Node has no location: #{node}"
  end
  node.location.expression.source_buffer.name
end

# 1-based
def ast_begin_line(ast)
  ast.location.expression.line
end

# 0-based
def ast_begin_column(ast)
  ast.location.expression.column
end

# 0-based
def ast_begin_char(ast)
  ast.location.expression.begin_pos
end

# 0-based
def ast_end_char(ast)
  ast.location.expression.end_pos
end

# basename:line:column
# line is 1-based, column is 0-based
def nd(n)
  append = proc do |text, n|
    e = n.location.expression
    text += " @ #{File.basename(e.source_buffer.name, ".rb")}:#{e.line}:#{e.column}"
    parent = Asts.parent(n)
    parent ? append.(text, parent) : text
  end
  append.("#{ast_text(n)}", n)
end

# Returns the root parent. This returns the concrete .rb file location, when available.
def root_location(n)
  e = n.location.expression
  parent = Asts.parent(n)
  if parent
    root_location(parent)
  else
    if column
      "#{e.source_buffer.name}:#{e.line}:#{e.column}"
    else
      "#{e.source_buffer.name}:#{e.line}"
    end
  end
end

module SyntaxHelpers
  refine Object do
    private
    def n(type, *children)
      Parser::AST::Node.new(type, children)
    end

    def lvar(name)
      n(:lvar, name)
    end

    def as_arg(x)
      case x
      in Symbol
        n(:arg, x)
      in [:sym, name]
        n(:arg, name)
      end
    end
  end
end

class Hash
  def get_or_add(key)
    fetch(key) { |k| self[k] = yield(k) }
  end
end
