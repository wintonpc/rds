defmacro(:defproto) do |_, args|
  tag, *fields = args
  syntax do
    defmacro(:make_calibration) do |k, args|
      args[0] => [:kwargs, *pairs]
      array_args = pairs.map do |arg|
        arg => [:pair, [:sym, field], value]
        [field, value]
      end.to_h.values_at(:degree, :weighting, :origin)
      quasisyntax { [:calibration, unsyntax_splicing(array_args)] }
    end
  end
end

defproto(:calibration, :degree, :weighting, :origin)

# defmacro(:make_calibration) do |k, args|
#   args[0] => [:kwargs, *pairs]
#   array_args = pairs.map do |arg|
#     arg => [:pair, [:sym, field], value]
#     [field, value]
#   end.to_h.values_at(:degree, :weighting, :origin)
#   quasisyntax { [:calibration, unsyntax_splicing(array_args)] }
# end

def make_a_calibration
  make_calibration(degree: 2, weighting: "none", origin: "ignore")
end

