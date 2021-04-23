#include <EXTERN.h>
#include <perl.h>
#include <XSUB.h>
#include <stdio.h>

static GV *sub_to_gv(pTHX_ SV *sv);
Perl_ppaddr_t orig_subhandler;
Perl_ppaddr_t orig_openhandler;
Perl_ppaddr_t orig_sysopenhandler;

// If we do not use threads we will make this global
// The performance impact of fetching it each time is significant, so avoid it
// if we can.
#ifdef USE_ITHREADS
#define fetch_report HV *report = get_hv("Test2::Plugin::Cover::REPORT", GV_ADDMULTI);
#else
HV *report;
#define fetch_report NOOP
#endif

#define fetch_from SV *from = get_sv("Test2::Plugin::Cover::FROM", 0);
#define fetch_root SV *root = get_sv("Test2::Plugin::Cover::ROOT", 0);

static OP* my_subhandler(pTHX) {
    dSP;
    OP* out = orig_subhandler(aTHX);

    if (out != NULL && (out->op_type == OP_NEXTSTATE || out->op_type == OP_DBSTATE)) {
        char *fname = CopFILE(cCOPx(out));
        STRLEN namelen = strlen(fname);

        // Check for absolute paths and reject them. This is a very
        // unix-oriented optimization.
        if (!strncmp(fname, "/", 1)) {
            fetch_root;

            if (root != NULL && SvPOK(root)) {
                STRLEN len;
                char *rt = NULL;
                rt = SvPV(root, len);

                if (namelen < len) return out;

                if (strncmp(fname, rt, len)) {
                    return out;
                }
            }
        }

        fetch_report;
        HV *file = NULL;
        SV **existing_file = hv_fetch(report, fname, namelen, 0);
        if (existing_file) {
            file = (HV *)SvRV(*existing_file);
        }
        else {
            file = newHV();
            hv_store(report, fname, namelen, newRV_inc((SV *)file), 0);
        }

        HV *subs;
        SV **existing_subs = hv_fetch(file, "subs", 4, 0);
        if (existing_subs) {
            subs = (HV *)SvRV(*existing_subs);
        }
        else {
            subs = newHV();
            hv_store(file, "subs", 4, newRV_inc((SV *)subs), 0);
        }

        char *subname = NULL;
        STRLEN sublen = 0;

        GV *my_gv = sub_to_gv(aTHX_ *SP);
        if (my_gv != NULL) {
            subname = GvNAME(my_gv);
            sublen = strlen(subname);
        }
        else {
            subname = "*";
            sublen = 1;
        }

        HV *sub = NULL;
        SV **existing_sub = hv_fetch(subs, subname, sublen, 0);
        if (existing_sub) {
            sub = (HV *)SvRV(*existing_sub);
        }
        else {
            sub = newHV();
            hv_store(subs, subname, sublen, newRV_inc((SV *)sub), 0);
        }

        fetch_from;
        if (!(from && SvOK(from))) {
            from = newSVpv("*", 1);
        }
        else {
            from = sv_mortalcopy(from);
            SvREFCNT_inc(from);
        }

        if (!hv_exists_ent(sub, from, 0)) {
            hv_store_ent(sub, from, from, 0);
        }
    }

    return out;
}

// Copied and modified from Devel::NYTProf
static GV *sub_to_gv(pTHX_ SV *sv) {
    CV *cv = NULL;

    /* copied from top of perl's pp_entersub */
    /* modified to return either CV or else a GV */
    /* or a NULL in cases that pp_entersub would croak */
    switch (SvTYPE(sv)) {
        default:
            if (!SvROK(sv)) {
                char *sym;

                if (sv == &PL_sv_yes) {           /* unfound import, ignore */
                    return NULL;
                }
                if (SvGMAGICAL(sv)) {
                    mg_get(sv);
                    if (SvROK(sv))
                        goto got_rv;
                    sym = SvPOKp(sv) ? SvPVX(sv) : Nullch;
                }
                else
                    // This causes the warnings from issue #2 https://github.com/Test-More/Test2-Plugin-Cover/issues/2
                    //sym = SvPV_nolen(sv);
                if (!sym)
                    return NULL;
                if (PL_op->op_private & HINT_STRICT_REFS)
                    return NULL;
                cv = get_cv(sym, TRUE);
                break;
            }
            got_rv:
            {
                SV **sp = &sv;                    /* Used in tryAMAGICunDEREF macro. */
                tryAMAGICunDEREF(to_cv);
            }
            cv = (CV*)SvRV(sv);
            if (SvTYPE(cv) == SVt_PVCV)
                break;

            /* FALL THROUGH */
        case SVt_PVHV:
        case SVt_PVAV:
            return NULL;

        case SVt_PVCV:
            cv = (CV*)sv;
            break;

        case SVt_PVGV:
            if (!(isGV_with_GP(sv) && (cv = GvCVu((GV*)sv)))) {
                HV *stash = NULL;
                GV *gv = NULL;
                cv = sv_2cv(sv, &stash, &gv, FALSE);

                if (gv) {
                    return gv;
                }
            }

            if (!cv) {                            /* would autoload in this situation */
                return NULL;
            }

            break;
    }

    if (cv) {
        GV *out = CvGV(cv);
        if (out && isGV_with_GP(out)) {
            return out;
        }
    }

    return NULL;
}

void _sv_file_handler(SV *filename) {
    if (filename == NULL) return;
    if (!SvPOKp(filename)) return;

    fetch_report;
    HE *file_he = hv_fetch_ent(report, filename, 0, 0);
    HV *file = NULL;
    if (file_he) {
        file = (HV *)SvRV(HeVAL(file_he));
    }
    else {
        file = newHV();
        hv_store_ent(report, filename, newRV_inc((SV *)file), 0);
    }

    HV *opens;
    SV **existing_opens = hv_fetch(file, "opens", 5, 0);
    if (existing_opens) {
        opens = (HV *)SvRV(*existing_opens);
    }
    else {
        opens = newHV();
        hv_store(file, "opens", 5, newRV_inc((SV *)opens), 0);
    }

    fetch_from;
    if (!(from && SvOK(from))) {
        from = newSVpv("*", 1);
    }

    if (!hv_exists_ent(opens, from, 0)) {
        SV *from_val = sv_mortalcopy(from);
        SvREFCNT_inc(from_val);
        hv_store_ent(opens, from_val, from_val, 0);
    }
}

static OP* my_openhandler(pTHX) {
    dSP;
    SV **mark = PL_stack_base + TOPMARK;
    I32 items = (I32)(sp - mark);

    // Only grab for 2-arg or 3-arg form
    if (items == 2 || items == 3) {
        _sv_file_handler(TOPs);
    }

    return orig_openhandler(aTHX);
}

static OP* my_sysopenhandler(pTHX) {
    dSP;
    SV **mark = PL_stack_base + TOPMARK;
    I32 ax    = (I32)(mark - PL_stack_base + 1);
    I32 items = (I32)(sp - mark);

    if (items >= 2) {
        _sv_file_handler(PL_stack_base[ax + (1)]);
    }

    return orig_sysopenhandler(aTHX);
}

MODULE = Test2::Plugin::Cover PACKAGE = Test2::Plugin::Cover

PROTOTYPES: ENABLE

BOOT:
    {
        //Initialize the global files HV, but only if we are not a threaded perl
#ifndef USE_ITHREADS
        report = get_hv("Test2::Plugin::Cover::REPORT", GV_ADDMULTI);
        SvREFCNT_inc(report);
#endif

        orig_subhandler = PL_ppaddr[OP_ENTERSUB];
        PL_ppaddr[OP_ENTERSUB] = my_subhandler;

        orig_openhandler = PL_ppaddr[OP_OPEN];
        PL_ppaddr[OP_OPEN] = my_openhandler;

        //orig_sysopenhandler = PL_ppaddr[OP_SYSOPEN];
        //PL_ppaddr[OP_SYSOPEN] = my_sysopenhandler;
    }
