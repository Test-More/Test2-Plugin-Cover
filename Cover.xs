#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <stdio.h>

Perl_ppaddr_t orig_subhandler;

// If we do not use threads we will make this global
// The performance impact of fetching it each time is significant, so avoid it
// if we can.
#ifndef USE_ITHREADS
HV *files;
#endif

static OP* my_subhandler(pTHX) {
    OP* out = orig_subhandler(aTHX);

    if (out != NULL && (out->op_type == OP_NEXTSTATE || out->op_type == OP_DBSTATE)) {

        // If we are using threads we need to grab this each time
#ifdef USE_ITHREADS
        HV *files = get_hv("Test2::Plugin::Cover::FILES", GV_ADDMULTI);
#endif

        char *file = CopFILE(cCOPx(out));
        long len = strlen(file);

        // There was 0 performance difference between always setting it, and
        // setting it only if it did not exist yet.
        hv_store(files, file, len, &PL_sv_yes, 0);
    }

    return out;
}

MODULE = Test2::Plugin::Cover PACKAGE = Test2::Plugin::Cover

PROTOTYPES: ENABLE

BOOT:
    {
        //Initialize the global files HV, but only if we are not a threaded perl
#ifndef USE_ITHREADS
        files = get_hv("Test2::Plugin::Cover::FILES", GV_ADDMULTI);
        SvREFCNT_inc(files);
#endif

        orig_subhandler = PL_ppaddr[OP_ENTERSUB];
        PL_ppaddr[OP_ENTERSUB] = my_subhandler;
    }
