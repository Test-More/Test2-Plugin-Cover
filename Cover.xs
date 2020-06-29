#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <stdio.h>

Perl_ppaddr_t orig_subhandler;
Perl_ppaddr_t orig_openhandler;
Perl_ppaddr_t orig_sysopenhandler;

// If we do not use threads we will make this global
// The performance impact of fetching it each time is significant, so avoid it
// if we can.
#ifdef USE_ITHREADS
#define fetch_files \
    HV *files = get_hv("Test2::Plugin::Cover::FILES", GV_ADDMULTI)
#else
HV *files;
#define fetch_files NOOP
#endif

static OP* my_subhandler(pTHX) {
    OP* out = orig_subhandler(aTHX);

    if (out != NULL && (out->op_type == OP_NEXTSTATE || out->op_type == OP_DBSTATE)) {
        fetch_files;
        char *file = CopFILE(cCOPx(out));
        long len = strlen(file);

        // There was 0 performance difference between always setting it, and
        // setting it only if it did not exist yet.
        hv_store(files, file, len, &PL_sv_yes, 0);
    }

    return out;
}

static OP* my_openhandler(pTHX) {
    dSP;

    SV *file = TOPs;
    if (SvPOKp(file)) {
        fetch_files;
        hv_store_ent(files, file, &PL_sv_yes, 0);
    }

    return orig_openhandler(aTHX);
}

static OP* my_sysopenhandler(pTHX) {
    dAXMARK;

    SV *file = ST(1);
    if (SvPOKp(file)) {
        fetch_files;
        hv_store_ent(files, file, &PL_sv_yes, 0);
    }

    return orig_sysopenhandler(aTHX);
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

        orig_openhandler = PL_ppaddr[OP_OPEN];
        PL_ppaddr[OP_OPEN] = my_openhandler;

        orig_sysopenhandler = PL_ppaddr[OP_SYSOPEN];
        PL_ppaddr[OP_SYSOPEN] = my_sysopenhandler;
    }
