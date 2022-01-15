# frozen_string_literal: true

def ast_text(node)
  node.location.expression.source
end

def ast_file(node)
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
