#include "ruby.h"
#include "vm_core.h"
#include "iseq.h"

VALUE rb_proc_region(VALUE self);

void Init_rds() {
  rb_define_method(rb_cProc, "source_region", rb_proc_region, 0);
}

static VALUE
iseq_region(const rb_iseq_t *iseq)
{
    // modified from iseq_location
    VALUE loc[5];

    if (!iseq) return Qnil;
    rb_iseq_check(iseq);
    loc[0] = rb_iseq_path(iseq);
    loc[1] = INT2FIX(iseq->body->location.code_location.beg_pos.lineno);
    loc[2] = INT2FIX(iseq->body->location.code_location.beg_pos.column);
    loc[3] = INT2FIX(iseq->body->location.code_location.end_pos.lineno);
    loc[4] = INT2FIX(iseq->body->location.code_location.end_pos.column);

    return rb_ary_new4(5, loc);
}

VALUE
rb_proc_region(VALUE self)
{
    return iseq_region(rb_proc_get_iseq(self, 0));
}
