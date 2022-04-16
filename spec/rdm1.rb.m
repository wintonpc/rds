require_relative_expand "syntax_rules"

# defmacro(:defproto) do |(_, *args)|
#   type, *fields = args
#   quasisyntax do
#     defmacro(unsyntax(:"make_#{syntax_to_datum(type)}")) do |(_, *args)|
#       args[0] => [:kwargs, *pairs]
#       array_args = pairs.map do |arg|
#         arg => [:pair, [:sym, field], value]
#         [field, value]
#       end.to_h.values_at(unsyntax_splicing(fields))
#       quasisyntax { [unsyntax(unsyntax(type)), unsyntax_splicing(array_args)] }
#     end
#     unsyntax_splicing(
#       fields.each_with_index.map do |f, fi|
#         quasisyntax do
#           defmacro(unsyntax(:"#{syntax_to_datum(type)}_#{syntax_to_datum(f)}")) do |(_, *args)|
#             arr = args[0]
#             quasisyntax do
#               unsyntax(arr)[unsyntax(unsyntax(fi) + 1)]
#             end
#           end
#         end
#       end
#     )
#     unsyntax_splicing(
#       fields.each_with_index.map do |f, fi|
#         quasisyntax do
#           defmacro(unsyntax(:"set_#{syntax_to_datum(type)}_#{syntax_to_datum(f)}")) do |(_, *args)|
#             arr = args[0]
#             val = args[1]
#             quasisyntax do
#               unsyntax(arr)[unsyntax(unsyntax(fi) + 1)] = unsyntax(val)
#             end
#           end
#         end
#       end
#     )
#   end
# end
#
# defproto(:calibration, :compound, :degree, :weighting, :origin)
# defproto(:compound, :name)
#
# def make_a_calibration(d)
#   cal = make_calibration(degree: d + 1, weighting: "none", origin: "ignore",
#     compound: make_compound(name: "morphine"))
#   set_calibration_degree(cal, calibration_degree(cal) + 1)
#   cal
# end

# defmacro(:or2,
#   syntax_rules do
#     case
#     when []
#       false
#     when [e1, e2 ...]
#       t = e1
#       if t
#         t
#       else
#         or2(e2 ...)
#       end
#     end
#   end)

# defmacro(:kvflatten,
#   syntax_rules do
#     case
#     when [{v => e} ...]
#       [v ..., e ...]
#     end
#   end
# )

defmacro(:kvflatten) do |(_, *args)|
  case args
  in [*erange]
    pairs = erange.select { |x| x.type == :kwargs }.flat_map(&:children)
    vs = pairs.map { |x| x.children[0] }
    es = pairs.map { |x| x.children[1] }
    quasisyntax do
      [unsyntax_splicing(vs), unsyntax_splicing(es)]
    end
  end
end

# defmacro(:let2,
#   syntax_rules do
#     case
#     when [{v => e} ..., body]
#       (lambda { |v=(v...)| body }).(e ...)
#     end
#   end
# )

def test_or2
  or2(false, 2, 3 + raise("oops"))
end

def test_kvflatten
  kvflatten(a: 1, b: 2)
end
