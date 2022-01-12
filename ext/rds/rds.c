#include "rds.h"

VALUE rb_mRds;

void
Init_rds(void)
{
  rb_mRds = rb_define_module("Rds");
}
