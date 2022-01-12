# frozen_string_literal: true

require "mkmf"

$CFLAGS += " -I/home/pwinton/git/ruby "
create_makefile("rds/rds")
