#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <stdio.h>

Perl_ppaddr_t orig_subhandler;

SV *one;
HV *files;

static OP* my_subhandler(pTHX) {
    OP* out = orig_subhandler(aTHX);

    if (out != NULL && (out->op_type == OP_NEXTSTATE || out->op_type == OP_DBSTATE)) {
        char *file = CopFILE(cCOPx(out));
        long len = strlen(file);

        if (!hv_exists(files, file, len)) {
            SvREFCNT_inc(one);
            hv_store(files, file, len, one, 0);
        }
    }

    return out;
}

MODULE = Test2::Plugin::Cover PACKAGE = Test2::Plugin::Cover

PROTOTYPES: ENABLE

BOOT:
    {
        MY_CXT_INIT;

        files = get_hv("Test2::Plugin::Cover::FILES", 0);
        SvREFCNT_inc(files);

        one = newSVnv(1);
        SvREFCNT_inc(one);

        orig_subhandler = PL_ppaddr[OP_ENTERSUB];
        PL_ppaddr[OP_ENTERSUB] = my_subhandler;
    }
