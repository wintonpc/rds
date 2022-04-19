# frozen_string_literal: true
# rubocop:disable all
# These tests are brittle because they test source locations within this file. Do not insert lines, only append.

RSpec.describe Rds do
  it "tracks locations" do
    a = syntax { x }
    expect(nd(a)).to eql "x @ loc_spec:7:17"

    b = syntax { syntax { x } }
    expect(nd(b)).to eql "syntax { x } @ loc_spec:10:17"
    expect(nd(b.children[2])).to eql "x @ loc_spec:10:26"
    b2 = Asts.eval(b)
    expect(b2).to eql b.children[2]

    c = quasisyntax { quasisyntax { x } }
    expect(nd(c)).to eql "quasisyntax { x } @ loc_spec:16:22"
    expect(nd(c.children[2])).to eql "x @ loc_spec:16:36"
    c2 = Asts.eval(c)
    expect(c2).to_not be c.children[2]
    expect(c2).to eql c.children[2]
    expect(nd(c2)).to eql "x @ ast\##{c.object_id}:2:2 @ loc_spec:16:36"

    d = quasisyntax { unsyntax(a) + y }
    expect(d.children[0]).to be a
    expect(nd(d.children[0])).to eql "x @ loc_spec:7:17"
    expect(nd(d.children[2])).to eql "y @ loc_spec:24:36"

    n1 = syntax { 1 }
    e = quasisyntax { quasisyntax { unsyntax(unsyntax(n1)) + y } }
    expect(nd(e)).to eql "quasisyntax { unsyntax(1) + y } @ loc_spec:30:22"
    f = Asts.eval(e)
    expect(nd(f)).to eql "1 + y @ ast\##{e.object_id}:2:2 @ loc_spec:30:36"
    expect(nd(f.children[2])).to eql "y @ ast\##{e.object_id}:2:16 @ loc_spec:30:61"

    n2 = syntax { 2 }
    g = quasisyntax { quasisyntax { quasisyntax { unsyntax(unsyntax(unsyntax(n2))) + y } } }
    expect(nd(g)).to eql "quasisyntax { quasisyntax { unsyntax(unsyntax(2)) + y } } @ loc_spec:37:22"
    h = Asts.eval(g)
    expect(nd(h)).to eql "quasisyntax { unsyntax(2) + y } @ ast\##{g.object_id}:2:2 @ loc_spec:37:36"
    i = Asts.eval(h)
    expect(nd(i)).to eql "2 + y @ ast\##{h.object_id}:2:2 @ ast\##{g.object_id}:3:4 @ loc_spec:37:50"

    j = quasisyntax { n3 = syntax { 4 }; quasisyntax { quasisyntax { unsyntax(unsyntax(n3)) + y } } }
    expect(nd(j)).to eql "n3 = syntax { 4 } quasisyntax { quasisyntax { unsyntax(unsyntax(n3)) + y } } @ loc_spec:44:22"
    k = Asts.eval(j)
    expect(nd(k)).to eql "quasisyntax { unsyntax(4) + y } @ ast\##{j.object_id}:5:2 @ loc_spec:44:55"
    l = Asts.eval(k)
    expect(nd(l)).to eql "4 + y @ ast\##{k.object_id}:2:2 @ ast\##{j.object_id}:6:4 @ loc_spec:44:69"
  end
end
# rubocop:enable all
