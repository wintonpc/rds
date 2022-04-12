calibration_proto = [:calibration, :degree, :weighting, :origin]

def expand_proto(p, kw_stx)
  tag, *fields = p
  kw_stx => [:kwargs, *pairs]
  array_args = pairs.map do |arg|
    arg => [:pair, [:sym, field], value]
    [field, value]
  end.to_h.values_at(*fields)
  quasisyntax { [unsyntax(datum_to_syntax(tag, kw_stx)), unsyntax_splicing(array_args)] }
end

defmacro(:make_calibration) do |k, args|
  expand_proto(calibration_proto, args[0])
end

def make_a_calibration
  make_calibration(degree: 2, weighting: "none", origin: "ignore")
end

