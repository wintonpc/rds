# frozen_string_literal: true

require "unparser"

def ast_text(node, pretty: false)
  s = Unparser.unparse(node)
  pretty ? s : s.gsub(/\s*\n\s*/, " ")
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

module SyntaxHelpers
  refine Object do
    private
    def n(type, *children)
      Parser::AST::Node.new(type, children)
    end

    def lvar(name)
      n(:lvar, name)
    end
  end
end
