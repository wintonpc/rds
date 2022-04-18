require_relative_expand "syntax_rules"
using SyntaxHelpers

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
#
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
#     when [x, {v => e} ...]
#       [v ..., e ..., x]
#     end
#   end
# )

# defmacro(:let2,
#   syntax_rules do
#     case
#     when [{v => e} ..., body]
#       (lambda { |_=(v...)| body }).(e ...)
#     end
#   end
# )

defmacro(:let2, proc do |stx|
  case stx
  in [_, *kws_1, body] then
    pairs_1 = kws_1.select { |x| x.type == :kwargs }.flat_map(&:children).map(&:children)
    v = pairs_1.map { |x| x[0] }
    e = pairs_1.map { |x| x[1] }
    quasisyntax do
      (lambda { |_=unsyntax_splicing(v.map { |x| as_arg(x) })| _u(body) }).(_us(e))
    end
  end
end)

def rdm_test_cases
  proc do
    # it "defproto" do
    #   expect(make_a_calibration(1)).to eql [:calibration, [:compound, "morphine"], 3, "none", "ignore"]
    # end
    # it "or2" do
    #   x = or2(false, 2, 3 + raise("oops"))
    #   expect(x).to eql 2
    # end
    # it "kvflatten" do
    #   x = kvflatten(3, a: 1, b: 2)
    #   expect(x).to eql [:a, :b, 1, 2, 3]
    # end
    it "let2" do
      x = let2(a: 1, b: 2) do
        [a + 1, b + 1]
      end
      expect(x).to eql [2, 3]
    end
  end
end
