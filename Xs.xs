#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"
#include "ppport.h"

#include "lex/creolize-lex.h"
#include "lex/creolize-grammar.h"

enum {
    ESCAPE_XML_ALL = FALSE,
    ESCAPE_XML_TEXT = TRUE
};

enum {
    WTYPE_NULL = 0,
    WTYPE_TEXT = 1,
    WTYPE_STAG = 2,
    WTYPE_ETAG = 3,
    WTYPE_ATAG = 4,
};

static const char *XML_SPECIAL[] = {"&amp;", "&lt;", "&gt;", "&quot;", "&#39;"};

typedef struct {
    SV *instance;       /* instance a cache of perl's $self */
    U8* source;         /* source input C string of source */
    STRLEN size;        /* size input C string length of source */
    int utf8;           /* utf8 input utf8 flag */
    STRLEN pos;         /* pos input \G position in bytes */
    int token;          /* token output token category no */
    /* token data = substr source, pos_start, pos_end - pos_start */
    STRLEN pos_start;   /* pos_start output token data start position in bytes */
    STRLEN pos_end;     /* pos_end output token data end position in bytes */
    SV *result;         /* result cache of the $self->{result} string scalar */
    int wtype;          /* wtype latest word type in the result */
    int blank;          /* blank latest blank condition in the result */
} creolize_t;

static void creolize_match(creolize_t *);
static void sv_cat_escape_xml(SV *, const U8 *, const STRLEN, const int);
static void creolize_put_text(creolize_t *, const U8 *, const STRLEN);
static void creolize_put_xml(creolize_t *, const U8 *, const STRLEN);
static void creolize_put_blank(creolize_t *, const U8 *, const STRLEN);
static void creolize_put_markup(creolize_t *, const U8 *, const STRLEN, int);

/**
 * substitutes XML special characters in buffer (U8 * s, STRLEN size).
 * substitutued results are appended into SV *result.
 * XML special characters are four marks: '&', '<', '>', and '\''.
 * This subroutine changes behaviour for named or number entities
 * with pass_entity switch. If it is ESCAPE_XML_ALL, all '&' marks
 * are escaped. If the pass_entity is ESCAPE_XML_TEXT, '&' marks
 * are not escaped when they form percent encoded entities.
 *
 * @param SV * result concatinates an escaped string.
 * @param const U8 * s the C string to be escaped.
 * @param const STRLEN size the bytes length of the s C string.
 * @param const int pass_entity switchs ESCAPE_XML_ALL or ESCAPE_XML_TEXT.
 */
static void
sv_cat_escape_xml(SV *result, const U8 *s, const STRLEN size, const int pass_entity)
{
    STRLEN pos_from, pos;
    unsigned int state;
    U8 ch;

    /*
     *  s =~ s{
     *      (   [<>"']
     *      |   &
     *  # if ESCAPE_XML_TEXT
     *          (?: (?: [A-Za-z_][A-Za-z0-9_]{,62}
     *              |   \# (?:[0-9]{1,10} | x [0-9A-Fa-f]{1,8})
     *              )
     *              ;
     *          )?
     *  # endif
     *      )
     *  }{
     *        $1 eq q{&} ? q{&amp;}
     *      : $1 eq q{<} ? q{&lt;}
     *      : $1 eq q{>} ? q{&gt;}
     *      : $1 eq q{"} ? q{&quot;}
     *      : $1 eq q{'} ? q{&#39;}
     *      : $1
     *  }gcmosx;
     *  result .= s;
     */
    SvGROW(result, (SvCUR(result) + size + 8)); 
    pos_from = 0;
    while (pos_from < size) {
        /* from state 7, '&amp;' -> '&amp;'
         * from state 14, '&amp;' -> '&amp;amp;'
         */ 
        state = pass_entity ? 7 : 14;
        pos = pos_from;
        while (pos < size) {
            ch = s[pos];
            if (state == 7) {
                if (ch == '<')
                    state = 1;
                else if (ch == '>')
                    state = 2;
                else if (ch == '"')
                    state = 3;
                else if (ch == '\'')
                    state = 4;
                else if (ch == '&')
                    state = 8;
                else
                    state = 5;
            }
            else if (state == 14) {
                if (ch == '<')
                    state = 1;
                else if (ch == '>')
                    state = 2;
                else if (ch == '"')
                    state = 3;
                else if (ch == '\'')
                    state = 4;
                else if (ch == '&')
                    state = 0;
                else
                    state = 5;
            }
            else if (state == 5) {
                if (ch == '<' || ch == '>' || ch == '"' || ch == '\'' || ch == '&')
                    break;
            }
            else if (state == 8) {
                if ((isascii(ch) && isalpha(ch)) || ch == '_')
                    state = 9;
                else if (ch == '#')
                    state = 10;
                else
                    break;
            }
            else if (state == 9) {
                if (pos - pos_from > 65)
                    break;
                if ((isascii(ch) && isalnum(ch)) || ch == '_')
                    state = 9;
                else if (ch == ';')
                    state = 6;
                else
                    break;
            }
            else if (state == 10) {
                if (isascii(ch) && isdigit(ch))
                    state = 11;
                else if (ch == 'x')
                    state = 12;
                else
                    break;
            }
            else if (state == 11) {
                if (pos - pos_from > 12)
                    break;
                if (isascii(ch) && isdigit(ch))
                    state = 11;
                else if (ch == ';')
                    state = 6;
                else
                    break;
            }
            else if (state == 12) {
                if (isascii(ch) && isxdigit(ch))
                    state = 13;
                else
                    break;
            }
            else if (state == 13) {
                if (pos - pos_from > 12)
                    break;
                if (isascii(ch) && isxdigit(ch))
                    state = 13;
                else if (ch == ';')
                    state = 6;
                else
                    break;
            }
            else {
                break;
            }
            ++pos;
        }
        if (state > 6) {
            /* the case of malformed entity, '&X' -> '&amp;X' */
            pos = pos_from + 1;
            state = 0;
        }
        if (state <= 4)
            sv_catpv(result, (char *)XML_SPECIAL[state]);
        else if (pos_from < pos)
            sv_catpvn(result, s + pos_from, pos - pos_from);
        pos_from = pos;
    }
    return;
}

/**
 * one step of lexical scan for WikiCreole.
 *
 * @param self creolize instance.
 */
static void
creolize_match(creolize_t *self)
{
    const U8 *source = self->source;
    const STRLEN size = self->size;
    const int is_utf8 = self->utf8;
    STRLEN pos = self->pos;
    STRLEN pos_from, pos1, pos2;
    int state;
    int token, token1;
    int c;
    U8 ch;

    /* lookahead postion marks */
    int pos_url = -1;
    int pos_endheading = -1;
    int pos_verb0 = -1;

    /* choose pattern entry point */
    state = 2; /* assume inline */
    if (pos == 0 || source[pos - 1] == '\n') {
        state = 0; /* (?:\A | (?<= \n )) (?! [\t\x20]) */
        if (pos < size && (source[pos] == ' ' || source[pos] == '\t')) {
            state = 1; /* (?:\A | (?<= \n )) [\t\x20]* */
            while (pos < size && (source[pos] == ' ' || source[pos] == '\t'))
                ++pos;
        }
    }
    pos_from = pos;
    /* return LEX_EOF for out of string length */
    if (pos >= size) {
        token = LEX_EOF;
        goto ensure; /* and return */
    }
    /* substr source, pos_from, pos - pos_from => the head of token */
    state = LEX_STATE[state];
    while (1) {
        while (pos < size) {
            /* remember the position on entering lookahead clauses.
             *   URL qr{(?:f|ht)tps?://[withpunct]+[withoutpunct]}
             *   HEADINGEOL qr{=+(?=(?:$S*)\n)}
             */
            if (state == LEX_STATE_URL || state == LEX_STATE_ESCAPE_URL)
                pos_url = pos;
            else if (state == LEX_STATE_ENDHEADING1)
                pos_endheading = pos;
            else if (state == LEX_STATE_VERB0)
                pos_verb0 = pos;
            /* go next state corresponding to the current character. */
            c = LEX_CODE[source[pos]];
            if (c <= 0 || LEX_CHECK[state + c] != state)
                break;
            pos += is_utf8 ? UTF8SKIP((source + pos)) : 1;
            state = LEX_STATE[state + c];
        }
        if (pos_verb0 < 0 || state == LEX_STATE_VERBATIM)
            break;
        /* retry as a nowiki in faults of a verbatim. */
        pos = pos_verb0;
        pos_verb0 = -1;
        state = LEX_STATE_NOWIKI0;
    }
    if (LEX_CHECK[state] == state) {
        token = -LEX_STATE[state];
    }
    else {
        /* in othercases, get one character TEXT */
        token = LEX_TEXT;
        pos = pos_from + (is_utf8 ? UTF8SKIP((source + pos_from)) : 1);
    }
    /* gleanings as nessesaries */
    if (token == LEX_TEXT && pos < size) {
        /* strech the token region as long as possible. TEXT (?:[\t\x20]* TEXT)*
         */
        pos1 = pos;
        ch = source[pos1];
        while(1) {
            while (pos1 < size && (ch == ' ' || ch == '\t')) {
                pos1 += is_utf8 ? UTF8SKIP((source + pos1)) : 1;
                ch = source[pos1];
            }
            if (pos1 >= size)
                break;
            /* check the substring after blanks TEXT. 
             * inline token must be started from state 2.
             */
            state = LEX_STATE[2];
            pos2 = pos1;
            while (pos2 < size) {
                ch = source[pos2];
                c = LEX_CODE[ch];
                if (c <= 0 || LEX_CHECK[state + c] != state)
                    break;
                pos2 += is_utf8 ? UTF8SKIP((source + pos2)) : 1;
                state = LEX_STATE[state + c];
            }
            token1 = LEX_TEXT;
            if (LEX_CHECK[state] == state) {
                /* if the final state has a token label, we use it.  */
                token1 = -LEX_STATE[state];
            }
            else {
                pos2 = pos1 + (is_utf8 ? UTF8SKIP((source + pos1)) : 1);
            }
            if (token1 == LEX_TEXT)
                pos = pos1 = pos2;
            else if (token1 == LEX_BLANK)
                pos1 = pos2;
            else
                break;
        }
    }
    else if (token == LEX_Z_TH) {
        /* token is LEX_TD for both '|' mark and '|=' mark */
        token = LEX_TD;
    }
    else if (token == LEX_TD || token == LEX_ENDTR) {
        /* ignore lookahead region. qr{\| (?=$S*\n)}msx */
        pos = pos_from + (is_utf8 ? UTF8SKIP((source + pos_from)) : 1);
    }
    else if (token == LEX_Z_ENDHEADING) {
        /* ignore lookahead region. qr{=+ (?=$S*\n)}msx */
        pos = pos_endheading;
        token = LEX_HEADING;
    }
    else if (token == LEX_Z_URL7) {
        /* ignore last punctuations. */
        if (pos_url >= 0) {
            pos = pos_url;
        }
        token = LEX_FREESTAND;
    }
    else if (token == LEX_Z_ESCAPE_URL7) {
        /* ignore last punctuations. */
        if (pos_url >= 0) {
            pos = pos_url;
        }
        token = LEX_ESCAPE;
    }
    else if (token == LEX_Z_ESCAPE1) {
        pos = pos_from + (is_utf8 ? UTF8SKIP((source + pos_from)) : 1);
        if (source[pos] == '[' || source[pos] == '{') {
            /* tilde escape ~[[ or ~{{ cases */
            pos += 2;
        }
        else if (pos < size) {
            /* tilde escape one character ~. */
            pos += is_utf8 ? UTF8SKIP((source + pos)) : 1;
        }
        token = LEX_ESCAPE;
    }

ensure:
    self->pos = pos;
    self->token = token;
    self->pos_start = pos_from;
    self->pos_end = pos;
    return;
}

/**
 * concatenates XML escaped text string with previous blank space.
 *
 * @param self the instance.
 * @param str C string body.
 * @param size number of bytes of str. 
 */
static void
creolize_put_text(creolize_t *self, const U8 *str, const STRLEN size)
{
    U8* data_body;
    STRLEN data_size;

    if (self->blank)
        sv_catpvn(self->result, " ", 1);
    sv_cat_escape_xml(self->result, str, size, ESCAPE_XML_TEXT);
    self->blank = FALSE;
    self->wtype = WTYPE_TEXT;
}

/**
 * concatenates XML escaped string with previous blank space.
 *
 * @param self the instance.
 * @param str C string body.
 * @param size number of bytes of str. 
 */
static void
creolize_put_xml(creolize_t *self, const U8 *str, const STRLEN size)
{
    U8* data_body;
    STRLEN data_size;

    if (self->blank)
        sv_catpvn(self->result, " ", 1);
    sv_cat_escape_xml(self->result, str, size, ESCAPE_XML_ALL);
    self->blank = FALSE;
    self->wtype = WTYPE_TEXT;
}

/**
 * marks blank. if the size is equal to zero, concatenates newline.
 *
 * @param self the instance.
 * @param str C string body.
 * @param size number of bytes of str. 
 */
static void
creolize_put_blank(creolize_t *self, const U8 *str, const STRLEN size)
{
    U8 ch;
    U8* result_body;
    STRLEN result_size;

    self->blank = FALSE;
    result_body = SvPV(self->result, result_size);
    if (size == 0) {
        sv_catpvn(self->result, "\n", 1);
        self->wtype = WTYPE_NULL;
    }
    else if (self->wtype == WTYPE_TEXT) {
        ch = result_body[result_size - 1];
        if (ch >= 0x21 && ch <= 0x7e)
            self->blank = TRUE;
    }
    else if (self->wtype == WTYPE_ETAG) {
        self->blank = TRUE;
    }
}

/**
 * concatenates XML markup with previous blank space.
 *
 * @param self the instance.
 * @param str C string body.
 * @param size number of bytes of str.
 * @param wtype 
 */
static void
creolize_put_markup(creolize_t *self, const U8 *str, const STRLEN size, int wtype)
{
    if (wtype != WTYPE_STAG) {
        self->blank = FALSE;
    }
    if (self->blank) {
        sv_catpvn(self->result, " ", 1);
    }
    sv_catpvn(self->result, str, size);
    self->blank = FALSE;
    self->wtype = wtype == WTYPE_ETAG ? WTYPE_ETAG : WTYPE_STAG;
}

static void
creolize_scan(creolize_t *self)
{
    int state, succ, token, i, j;
    SV *data;

    for (state = 0; state >= 0; state = succ) {
        creolize_match(self);
        token = self->token;
        succ = LEX_GRAMMAR[token][state][0];
        for (i = 1; (j = LEX_GRAMMAR[token][state][i]) >= 0; i++) {
            switch (j) {
            case LEX_ACTION_PUT:
                creolize_put_text(self,
                    self->source + self->pos_start, self->pos_end - self->pos_start
                );
                break;
            case LEX_ACTION_PUTS:
                creolize_put_blank(self,
                    self->source + self->pos_start, self->pos_end - self->pos_start
                );
                break;
            default:
                {
                    dSP;
                    ENTER;
                    SAVETMPS;
                    PUSHMARK(SP);
                    XPUSHs(self->instance);
                    data = newSVpvn_utf8(
                        self->source + self->pos_start,
                        self->pos_end - self->pos_start,
                        SvUTF8(self->result)
                    );
                    XPUSHs(sv_2mortal(data));
                    PUTBACK;

                    call_method(LEX_ACTION[j], G_SCALAR);

                    FREETMPS;
                    LEAVE;
                }
                break;
            }
        }
    }
}

MODULE = Text::Creolize::Xs		PACKAGE = Text::Creolize::Xs		

void
_xs_alloc(SV *self_sv)
  PROTOTYPE: $
  PREINIT:
    creolize_t *self;
    HV *self_hv;
    SV **p_result;
    SV *self_iv;
  CODE:
    if (! sv_isobject(self_sv) || SvTYPE(SvRV(self_sv)) != SVt_PVHV)
        croak("_xs_alloc: $self is not blessed HASHREF!");
    Newx(self, 1, creolize_t);
    self_hv = (HV *)SvRV(self_sv);
    if (! hv_exists(self_hv, "result", 6)) {
        hv_store(self_hv, "result", 6, newSVpvn("", 0), 0);
    }
    p_result = hv_fetch(self_hv, "result", 6, FALSE);
    if (p_result == NULL || ! SvPOK(*p_result))
        croak("_xs_alloc: $self->{result} is not SCALAR");
    self->result = *p_result;
    self->wtype = WTYPE_NULL;
    self->blank = FALSE;
    self_iv = newSViv(PTR2IV(self));
    sv_magic(SvRV(self_sv), sv_2mortal(self_iv), PERL_MAGIC_ext, NULL, 0);

void
_xs_free(SV *self_sv)
  PROTOTYPE: $
  PREINIT:
    creolize_t *self;
    MAGIC *mg;
  CODE:
    mg = mg_find(SvRV(self_sv), PERL_MAGIC_ext);
    if (mg == NULL)
        XSRETURN_EMPTY;
    self = INT2PTR(creolize_t *, SvIV(mg->mg_obj));
    sv_unmagic(SvRV(self_sv), PERL_MAGIC_ext);
    Safefree(self);

void
_scan(SV * self_sv, SV * src_sv)
  PROTOTYPE: $$
  PREINIT:
    creolize_t *self;
    MAGIC *mg;
  CODE:
    if (! sv_isobject(self_sv) || SvTYPE(SvRV(self_sv)) != SVt_PVHV)
        croak("_scan: $self is not blessed HASHREF!");
    mg = mg_find(SvRV(self_sv), PERL_MAGIC_ext);
    if (mg == NULL)
        croak("_scan: forgot _xs_alloc!");
    self = INT2PTR(creolize_t *, SvIV(mg->mg_obj));
    self->instance = self_sv;
    self->source = SvPV(src_sv, self->size);
    self->pos = 0;
    self->utf8 = DO_UTF8(src_sv);
    if (SvUTF8(src_sv) && ! SvUTF8(self->result))
        SvUTF8_on(self->result);
    SvGROW(self->result, (self->size + 64)); 
    creolize_scan(self);

void
match(SV * klass, SV * srcsv)
  PROTOTYPE: $$
  PREINIT:
    creolize_t self;
    MAGIC* mg;
  PPCODE:
    /* ($token, $pos_start, $pos_end) = $class->match($source) */
    /* uses \G magic. see PP(pp_match) definition in perl/pp_hot.c */
    mg = NULL;
    if (SvTYPE(srcsv) >= SVt_PVMG && SvMAGIC(srcsv))
        mg = mg_find(srcsv, PERL_MAGIC_regex_global);
    if (! mg) {
        mg = sv_magicext(srcsv, NULL, PERL_MAGIC_regex_global,
                         &PL_vtbl_mglob, NULL, 0);
        mg->mg_len = 0;
    }
    self.pos = mg->mg_len;
    /* Since mg_find may realloc the PV structure,
       we call SvPV after mg_find */
    self.source = SvPV(srcsv, self.size);
    self.utf8 = DO_UTF8(srcsv);

    creolize_match(&self);

    mg->mg_len = self.pos;
    if (self.pos >= self.size)
        mg->mg_flags |= MGf_MINMATCH;
    else
        mg->mg_flags &= ~MGf_MINMATCH;
    if (self.utf8) {
        sv_pos_b2u(srcsv, (I32*)&(self.pos_start));
        sv_pos_b2u(srcsv, (I32*)&(self.pos_end));
    }
    XPUSHs(sv_2mortal(newSViv(self.token)));
    XPUSHs(sv_2mortal(newSViv(self.pos_start)));
    XPUSHs(sv_2mortal(newSViv(self.pos_end)));

char *
token_name(SV * klass, int token)
  PROTOTYPE: $$
  CODE:
    if (token >= 0 && token < LEX_TOKEN_NAME_SIZE)
        RETVAL = (char *)(LEX_TOKEN_NAME[token]);
    else
        RETVAL = NULL;
  OUTPUT:
    RETVAL

void
put(SV *self_sv, SV *data)
  PROTOTYPE: $$
  PREINIT:
    creolize_t *self;
    MAGIC *mg;
    U8 *data_body;
    STRLEN data_size;
  CODE:
    mg = mg_find(SvRV(self_sv), PERL_MAGIC_ext);
    if (mg == NULL)
        croak("put: called out of context in _xs_scan.");
    self = INT2PTR(creolize_t *, SvIV(mg->mg_obj));
    data_body = SvPV(data, data_size);
    creolize_put_text(self, data_body, data_size);
    if (SvUTF8(data) && ! SvUTF8(self->result))
        SvUTF8_on(self->result);

void
puts(SV *self_sv, SV *data)
  PROTOTYPE: $$
  PREINIT:
    creolize_t *self;
    MAGIC *mg;
    U8 *data_body;
    STRLEN data_size;
  CODE:
    mg = mg_find(SvRV(self_sv), PERL_MAGIC_ext);
    if (mg == NULL)
        croak("puts: called out of context in _xs_scan.");
    self = INT2PTR(creolize_t *, SvIV(mg->mg_obj));
    data_body = SvPV(data, data_size);
    creolize_put_blank(self, data_body, data_size);

void
put_xml(SV *self_sv, SV *data)
  PROTOTYPE: $$
  PREINIT:
    creolize_t *self;
    MAGIC *mg;
    U8 *data_body;
    STRLEN data_size;
  CODE:
    mg = mg_find(SvRV(self_sv), PERL_MAGIC_ext);
    if (mg == NULL)
        croak("put_xml: called out of context in _xs_scan.");
    self = INT2PTR(creolize_t *, SvIV(mg->mg_obj));
    data_body = SvPV(data, data_size);
    creolize_put_xml(self, data_body, data_size);
    if (SvUTF8(data) && ! SvUTF8(self->result))
        SvUTF8_on(self->result);

void
put_raw(SV *self_sv, SV *data)
  PROTOTYPE: $$
  PREINIT:
    creolize_t *self;
    MAGIC *mg;
  CODE:
    mg = mg_find(SvRV(self_sv), PERL_MAGIC_ext);
    if (mg == NULL)
        croak("put_raw: called out of context in _xs_scan.");
    self = INT2PTR(creolize_t *, SvIV(mg->mg_obj));
    if (self->blank)
        sv_catpvn(self->result, " ", 1);
    sv_catsv(self->result, data);
    self->blank = FALSE;
    self->wtype = WTYPE_TEXT;
    if (SvUTF8(data) && ! SvUTF8(self->result))
        SvUTF8_on(self->result);

void
_put_markup_string(SV *self_sv, SV *markup_string, SV *markup_type)
  PROTOTYPE: $$$
  PREINIT:
    creolize_t *self;
    MAGIC *mg;
    U8 *markup_string_body;
    STRLEN markup_string_size;
    U8 *markup_type_body;
    STRLEN markup_type_size;
    int wtype;
  CODE:
    mg = mg_find(SvRV(self_sv), PERL_MAGIC_ext);
    if (mg == NULL)
        croak("_put_markup_string: called out of context in _xs_scan.");
    self = INT2PTR(creolize_t *, SvIV(mg->mg_obj));
    markup_string_body = SvPV(markup_string, markup_string_size);
    markup_type_body = SvPV(markup_type, markup_type_size);
    wtype = WTYPE_ATAG;
    if (markup_type_size == 4) {
        if (memcmp(markup_type_body, "stag", 4) == 0)
            wtype = WTYPE_STAG;
        else if (memcmp(markup_type_body, "etag", 4) == 0)
            wtype = WTYPE_ETAG;
    }
    creolize_put_markup(self, markup_string_body, markup_string_size, wtype);

