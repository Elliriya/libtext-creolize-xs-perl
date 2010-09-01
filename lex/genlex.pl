use strict;
use warnings;
use bytes;

my @BUT_EOL = map { chr $_ } 0x09, 0x20 .. 0x7e, 0x80 .. 0xff;
my @BUT_SPACE = map { chr $_ } 0x21 .. 0x7e, 0x80 .. 0xff;
my @TEXT_STARTCHAR = (
    '$', '%', '+', '-', '&', '@', '0' .. '9', 'a' .. 'e', 'g', 'i' .. 'z',
);
my @TEXT_CHAR = (
    '$', '%', '+', '-', '&', '@', '0' .. '9', 'A' .. 'Z', 'a' .. 'z',
);
my @TEXT_PUNCT = (
    '!', '"', '\'', '(', ')', '.', ';', '>', '?', ']', '`', '}',
    (map { chr $_ } 0x80 .. 0xff),
);
my $TOKEN_LABEL = "\0";
our $PATTERN = {
    'S0' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_STARTCHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        "\t" => 'BLANK',
        "\n" => 'EOL',
        ' ' => 'BLANK',
        '-' => 'HRULE1',
        '*' => 'ULIST1',
        '#' => 'OLIST1',
        ';' => 'TERM',
        ':' => 'DESC',
        '>' => 'QUOTE',
        '=' => 'HEADING',
        '|' => 'TD',
        '/' => 'ITALIC1',
        '^' => 'SUP1',
        ',' => 'SUB1',
        '_' => 'UNDER1',
        '\\' => 'BREAK1',
        '[' => 'BRACKET1',
        '<' => 'ANGLE1',
        '{' => 'S0BRACE1',
        '~' => 'ESCAPE',
        'h' => 'HTTP1',
        'f' => 'URL1',
        (map { $_ => 'WORD1' } 'A' .. 'Z'),
    },
    'S1' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_STARTCHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        "\n" => 'EOL',
        '-' => 'HRULE1',
        '*' => 'ULIST1',
        '#' => 'OLIST1',
        ';' => 'TERM',
        ':' => 'DESC',
        '>' => 'QUOTE',
        '=' => 'HEADING',
        '|' => 'TD',
        '/' => 'ITALIC1',
        '^' => 'SUP1',
        ',' => 'SUB1',
        '_' => 'UNDER1',
        '\\' => 'BREAK1',
        '[' => 'BRACKET1',
        '<' => 'ANGLE1',
        '{' => 'BRACE1',
        '~' => 'ESCAPE',
        'h' => 'HTTP1',
        'f' => 'URL1',
        (map { $_ => 'WORD1' } 'A' .. 'Z'),
    },
    'S2' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_STARTCHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        "\t" => 'BLANK',
        "\n" => 'EOL',
        ' ' => 'BLANK',
        '*' => 'BOLD1',
        '#' => 'MONOSPACE1',
        ':' => 'DESC',
        '=' => 'ENDHEADING1',
        '|' => 'TD',
        '/' => 'ITALIC1',
        '^' => 'SUP1',
        ',' => 'SUB1',
        '_' => 'UNDER1',
        '\\' => 'BREAK1',
        '[' => 'BRACKET1',
        '<' => 'ANGLE1',
        '{' => 'BRACE1',
        '~' => 'ESCAPE',
        'h' => 'HTTP1',
        'f' => 'URL1',
        (map { $_ => 'WORD1' } 'A' .. 'Z'),
    },
    'TEXT' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
    },
    'PUNCT' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_STARTCHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
    },
    'BLANK' => {
        $TOKEN_LABEL => 'BLANK',
        "\t" => 'BLANK',
        ' ' => 'BLANK',
        "\n" => 'EOL',
    },
    'EOL' => {
        $TOKEN_LABEL => 'EOL',
    },
    'HRULE1' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        '-' => 'HRULE2',
    },
    'HRULE2' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        '-' => 'HRULE3',
    },
    'HRULE3' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        '-' => 'HRULE4',
    },
    'HRULE4' => {
        "\t" => 'HRULE5',
        "\n" => 'HRULE',
        ' ' => 'HRULE5',
        '-' => 'HRULE4',
    },
    'HRULE5' => {
        "\t" => 'HRULE5',
        "\n" => 'HRULE',
        ' ' => 'HRULE5',
    },
    'HRULE' => {
        $TOKEN_LABEL => 'HRULE',
    },
    'ULIST1' => {
        $TOKEN_LABEL => 'JUSTLIST',
        '*' => 'ULIST2',
    },
    'ULIST2' => {
        $TOKEN_LABEL => 'MAYBELIST',
        '*' => 'ULIST3',
    },
    'ULIST3' => {
        $TOKEN_LABEL => 'JUSTLIST',
        '*' => 'ULIST3',
    },
    'OLIST1' => {
        $TOKEN_LABEL => 'JUSTLIST',
        '#' => 'OLIST2',
    },
    'OLIST2' => {
        $TOKEN_LABEL => 'MAYBELIST',
        '#' => 'OLIST3',
    },
    'OLIST3' => {
        $TOKEN_LABEL => 'JUSTLIST',
        '#' => 'OLIST3',
    },
    'TERM' => {
        $TOKEN_LABEL => 'TERM',
        ';' => 'TERM',
    },
    'DESC' => {
        $TOKEN_LABEL => 'DESC',
        ':' => 'DESC',
    },
    'QUOTE' => {
        $TOKEN_LABEL => 'QUOTE',
        '>' => 'QUOTE',
    },
    'HEADING' => {
        $TOKEN_LABEL => 'HEADING',
        '=' => 'HEADING',
    },
    'ENDHEADING1' => {
        $TOKEN_LABEL => 'TEXT',
        '=' => 'ENDHEADING1',
        ' ' => 'ENDHEADING2',
        "\t" => 'ENDHEADING2',
        "\n" => 'ENDHEADING',
    },
    'ENDHEADING2' => {
        ' ' => 'ENDHEADING2',
        "\t" => 'ENDHEADING2',
        "\n" => 'ENDHEADING',
    },
    'ENDHEADING' => {
        $TOKEN_LABEL => 'Z_ENDHEADING',
    },
    'TD' => {
        $TOKEN_LABEL => 'TD',
        ' ' => 'ENDTR1',
        "\t" => 'ENDTR1',
        "\n" => 'ENDTR',
        '=' => 'TH',
    },
    'ENDTR1' => {
        $TOKEN_LABEL => 'TD',
        ' ' => 'ENDTR1',
        "\t" => 'ENDTR1',
        "\n" => 'ENDTR',
    },
    'ENDTR' => {
        $TOKEN_LABEL => 'ENDTR',
    },
    'TH' => {
        $TOKEN_LABEL => 'Z_TH',
    },
    'BOLD1' => {
        $TOKEN_LABEL => 'TEXT',
        '*' => 'BOLD2',
    },
    'BOLD2' => {
        $TOKEN_LABEL => 'PHRASE',
        '*' => 'BOLD3',
    },
    'BOLD3' => {
        $TOKEN_LABEL => 'TEXT',
        '*' => 'BOLD3',
    },
    'MONOSPACE1' => {
        $TOKEN_LABEL => 'TEXT',
        '#' => 'MONOSPACE2',
    },
    'MONOSPACE2' => {
        $TOKEN_LABEL => 'PHRASE',
        '#' => 'MONOSPACE3',
    },
    'MONOSPACE3' => {
        $TOKEN_LABEL => 'TEXT',
        '#' => 'MONOSPACE3',
    },
    'PHRASE' => {
        $TOKEN_LABEL => 'PHRASE',
    },
    'ITALIC1' => {
        $TOKEN_LABEL => 'TEXT',
        '/' => 'PHRASE',
    },
    'SUP1' => {
        $TOKEN_LABEL => 'TEXT',
        '^' => 'PHRASE',
    },
    'SUB1' => {
        $TOKEN_LABEL => 'TEXT',
        ',' => 'PHRASE',
    },
    'UNDER1' => {
        $TOKEN_LABEL => 'TEXT',
        '_' => 'PHRASE',
    },
    'BREAK1' => {
        $TOKEN_LABEL => 'TEXT',
        '\\' => 'BREAK',
    },
    'BREAK' => {
        $TOKEN_LABEL => 'BREAK',
    },
    'BRACKET1' => {
        $TOKEN_LABEL => 'TEXT',
        '[' => 'BRACKET2',
    },
    'BRACKET2' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'BRACKET3' } @BUT_EOL),
        '[' => 'BRACKET5',
        ']' => 'BRACKET4',
    },
    'BRACKET3' => {
        (map { (chr $_) => 'BRACKET3' } 0x09, 0x20 .. 0x5a, 0x5c .. 0x7e, 0x80 .. 0xff),
        ']' => 'BRACKET4',
    },
    'BRACKET4' => {
        ']' => 'BRACKETED',
    },
    'BRACKETED' => {
        $TOKEN_LABEL => 'BRACKETED',
    },
    'BRACKET5' => {
        $TOKEN_LABEL => 'TEXT',
        '[' => 'BRACKET5',
    },
    'ANGLE1' => {
        $TOKEN_LABEL => 'TEXT',
        '<' => 'ANGLE2',
    },
    'ANGLE2' => {
        (map { $_ => 'PLUGIN1' } @BUT_EOL),
        '<' => 'PLACEHOLDER1',
        '>' => 'PLUGIN2',
    },
    'PLUGIN1' => {
        (map { $_ => 'PLUGIN1' } @BUT_EOL),
        "\n" => 'PLUGIN1',
        '>' => 'PLUGIN2',
    },
    'PLUGIN2' => {
        (map { $_ => 'PLUGIN1' } @BUT_EOL),
        "\n" => 'PLUGIN1',
        '>' => 'PLUGIN',
    },
    'PLUGIN' => {
        $TOKEN_LABEL => 'PLUGIN',
    },
    'PLACEHOLDER1' => {
        (map { $_ => 'PLACEHOLDER1' } @BUT_EOL),
        "\n" => 'PLACEHOLDER1',
        '>' => 'PLACEHOLDER2',
    },
    'PLACEHOLDER2' => {
        (map { $_ => 'PLACEHOLDER1' } @BUT_EOL),
        "\n" => 'PLACEHOLDER1',
        '>' => 'PLACEHOLDER3',
    },
    'PLACEHOLDER3' => {
        (map { $_ => 'PLACEHOLDER1' } @BUT_EOL),
        "\n" => 'PLACEHOLDER1',
        '>' => 'PLACEHOLDER',
    },
    'PLACEHOLDER' => {
        $TOKEN_LABEL => 'PLACEHOLDER',
    },
    'S0BRACE1' => {
        $TOKEN_LABEL => 'TEXT',
        '{' => 'S0BRACE2',
    },
    'S0BRACE2' => {
        (map { $_ => 'S0BRACE20' } @BUT_EOL),
        '{' => 'S0BRACE3',
        '}' => 'S0BRACE21',
    },
    'S0BRACE20' => {
        (map { $_ => 'S0BRACE20' } @BUT_EOL),
        '}' => 'S0BRACE21',
    },
    'S0BRACE21' => {
        '}' => 'S0BRACED',
    },
    'S0BRACED' => {
        $TOKEN_LABEL => 'BRACED',
    },
    'S0BRACE3' => {
        (map { $_ => 'NOWIKI0' } @BUT_EOL),
        "\n" => 'VERB0',
        '}' => 'NOWIKI1',
    },
    'BRACE1' => {
        $TOKEN_LABEL => 'TEXT',
        '{' => 'BRACE2',
    },
    'BRACE2' => {
        (map { $_ => 'BRACE20' } @BUT_EOL),
        '{' => 'BRACE3',
        '}' => 'BRACE21',
    },
    'BRACE20' => {
        (map { $_ => 'BRACE20' } @BUT_EOL),
        '}' => 'BRACE21',
    },
    'BRACE21' => {
        '}' => 'BRACED',
    },
    'BRACED' => {
        $TOKEN_LABEL => 'BRACED',
    },
    'BRACE3' => {
        (map { $_ => 'NOWIKI0' } @BUT_EOL),
        "\n" => 'NOWIKI0',
        '}' => 'NOWIKI1',
    },
    'NOWIKI0' => {
        (map { $_ => 'NOWIKI0' } @BUT_EOL),
        "\n" => 'NOWIKI0',
        '}' => 'NOWIKI1',
    },
    'NOWIKI1' => {
        (map { $_ => 'NOWIKI0' } @BUT_EOL),
        "\n" => 'NOWIKI0',
        '}' => 'NOWIKI2',
    },
    'NOWIKI2' => {
        (map { $_ => 'NOWIKI0' } @BUT_EOL),
        "\n" => 'NOWIKI0',
        '}' => 'NOWIKI',
    },
    'NOWIKI' => {
        $TOKEN_LABEL => 'NOWIKI',
        '}' => 'NOWIKI',
    },
    'VERB0' => {
        (map { $_ => 'VERB1' } @BUT_EOL),
        "\n" => 'VERB2',
        '}' => 'VERB3',
    },
    'VERB1' => {
        (map { $_ => 'VERB1' } @BUT_EOL),
        "\n" => 'VERB2',
    },
    'VERB2' => {
        (map { $_ => 'VERB1' } @BUT_EOL),
        "\n" => 'VERB2',
        '}' => 'VERB3',
    },
    'VERB3' => {
        (map { $_ => 'VERB1' } @BUT_EOL),
        "\n" => 'VERB2',
        '}' => 'VERB4',
    },
    'VERB4' => {
        (map { $_ => 'VERB1' } @BUT_EOL),
        "\n" => 'VERB2',
        '}' => 'VERB5',
    },
    'VERB5' => {
        (map { $_ => 'VERB1' } @BUT_EOL),
        "\n" => 'VERBATIM',
    },
    'VERBATIM' => {
        $TOKEN_LABEL => 'VERBATIM',
    },
    'ESCAPE' => {
        $TOKEN_LABEL => 'ESCAPE',
        (map { $_ => 'ESCAPE_CHAR' } @BUT_SPACE),
        '*' => 'ESCAPE_ULIST',
        '#' => 'ESCAPE_OLIST',
        '/' => 'ESCAPE_ITALIC1',
        '\\' => 'ESCAPE_BREAK1',
        '^' => 'ESCAPE_SUP1',
        ',' => 'ESCAPE_SUB1',
        '_' => 'ESCAPE_UNDER1',
        ':' => 'ESCAPE_DESC',
        '=' => 'ESCAPE_HEADING',
        '<' => 'ESCAPE_ANGLE',
        '[' => 'ESCAPE_BRACKET1',
        '{' => 'ESCAPE_BRACE1',
        '~' => 'ESCAPE2',
        'h' => 'ESCAPE_HTTP1',
        'f' => 'ESCAPE_URL1',
        (map { $_ => 'ESCAPE_WORD1' } 'A' .. 'Z'),
    },
    'ESCAPE_CHAR' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
    },
    'ESCAPE2' => {
        $TOKEN_LABEL => 'ESCAPE',
    },
    'ESCAPE_ULIST' => {
        $TOKEN_LABEL => 'ESCAPE',
        '*' => 'ESCAPE_ULIST',
    },
    'ESCAPE_OLIST' => {
        $TOKEN_LABEL => 'ESCAPE',
        '#' => 'ESCAPE_OLIST',
    },
    'ESCAPE_ITALIC1' => {
        $TOKEN_LABEL => 'ESCAPE',
        '/' => 'ESCAPE_ITALIC1',
    },
    'ESCAPE_BREAK1' => {
        $TOKEN_LABEL => 'ESCAPE',
        '\\' => 'ESCAPE2',
    },
    'ESCAPE_SUP1' => {
        $TOKEN_LABEL => 'ESCAPE',
        '^' => 'ESCAPE_SUP1',
    },
    'ESCAPE_SUB1' => {
        $TOKEN_LABEL => 'ESCAPE',
        ',' => 'ESCAPE_SUB1',
    },
    'ESCAPE_UNDER1' => {
        $TOKEN_LABEL => 'ESCAPE',
        '_' => 'ESCAPE_UNDER1',
    },
    'ESCAPE_DESC' => {
        $TOKEN_LABEL => 'ESCAPE',
        ':' => 'ESCAPE_DESC',
    },
    'ESCAPE_HEADING' => {
        $TOKEN_LABEL => 'ESCAPE',
        '=' => 'ESCAPE_HEADING',
    },
    'ESCAPE_ANGLE' => {
        $TOKEN_LABEL => 'ESCAPE',
        '<' => 'ESCAPE_ANGLE',
    },
    'ESCAPE_BRACKET1' => {
        $TOKEN_LABEL => 'ESCAPE',
        '[' => 'ESCAPE_BRACKET2',
    },
    'ESCAPE_BRACKET2' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        (map { $_ => 'ESCAPE_BRACKET3' } @BUT_EOL),
        '[' => 'ESCAPE_BRACKET5',
        ']' => 'ESCAPE_BRACKET4',
    },
    'ESCAPE_BRACKET3' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        (map { $_ => 'ESCAPE_BRACKET3' } @BUT_EOL),
        ']' => 'ESCAPE_BRACKET4',
    },
    'ESCAPE_BRACKET4' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        ']' => 'ESCAPE2',
    },
    'ESCAPE_BRACKET5' => {
        $TOKEN_LABEL => 'ESCAPE',
        '[' => 'ESCAPE_BRACKET5',
    },
    'ESCAPE_BRACE1' => {
        $TOKEN_LABEL => 'ESCAPE',
        '{' => 'ESCAPE_BRACE2',
    },
    'ESCAPE_BRACE2' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        (map { $_ => 'ESCAPE_BRACE4' } @BUT_EOL),
        '{' => 'ESCAPE_BRACE3',
        '}' => 'ESCAPE_BRACE5',
    },
    'ESCAPE_BRACE3' => {
        $TOKEN_LABEL => 'ESCAPE',
        '{' => 'ESCAPE_BRACE3',
    },
    'ESCAPE_BRACE4' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        (map { $_ => 'ESCAPE_BRACE4' } @BUT_EOL),
        '}' => 'ESCAPE_BRACE5',
    },
    'ESCAPE_BRACE5' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        '}' => 'ESCAPE2',
    },
    'ESCAPE_HTTP1' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        't' => 'ESCAPE_URL1',
    },
    'ESCAPE_URL1' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        't' => 'ESCAPE_URL2',
    },
    'ESCAPE_URL2' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        'p' => 'ESCAPE_URL3',
    },
    'ESCAPE_URL3' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        ':' => 'ESCAPE_URL5',
        's' => 'ESCAPE_URL4',
    },
    'ESCAPE_URL4' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        ':' => 'ESCAPE_URL5',
    },
    'ESCAPE_URL5' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        '/' => 'ESCAPE_URL6',
    },
    'ESCAPE_URL6' => {
        $TOKEN_LABEL => 'Z_ESCAPE1',
        '/' => 'ESCAPE_URL',
    },
    'ESCAPE_URL7' => {
        $TOKEN_LABEL => 'Z_ESCAPE_URL7',
        (map { $_ => 'ESCAPE_URL' } 'A' .. 'Z', 'a' .. 'z', '0' .. '9'),
        '-' => 'ESCAPE_URL',
        '.' => 'ESCAPE_URL7',
        '_' => 'ESCAPE_URL',
        '~' => 'ESCAPE_URL',
        ':' => 'ESCAPE_URL7',
        '/' => 'ESCAPE_URL',
        '?' => 'ESCAPE_URL7',
        '#' => 'ESCAPE_URL',
        '&' => 'ESCAPE_URL',
        '+' => 'ESCAPE_URL',
        ',' => 'ESCAPE_URL7',
        ';' => 'ESCAPE_URL7',
        '=' => 'ESCAPE_URL',
        '%' => 'ESCAPE_URL',
    },
    'ESCAPE_URL' => {
        $TOKEN_LABEL => 'ESCAPE',
        (map { $_ => 'ESCAPE_URL' } 'A' .. 'Z', 'a' .. 'z', '0' .. '9'),
        '-' => 'ESCAPE_URL',
        '.' => 'ESCAPE_URL7',
        '_' => 'ESCAPE_URL',
        '~' => 'ESCAPE_URL',
        ':' => 'ESCAPE_URL7',
        '/' => 'ESCAPE_URL',
        '?' => 'ESCAPE_URL7',
        '#' => 'ESCAPE_URL',
        '&' => 'ESCAPE_URL',
        '+' => 'ESCAPE_URL',
        ',' => 'ESCAPE_URL7',
        ';' => 'ESCAPE_URL7',
        '=' => 'ESCAPE_URL',
        '%' => 'ESCAPE_URL',
    },
    'ESCAPE_WORD1' => {
        $TOKEN_LABEL => 'ESCAPE',
        (map { $_ => 'ESCAPE_WORD2' } 'a' .. 'z'),
    },
    'ESCAPE_WORD2' => {
        $TOKEN_LABEL => 'ESCAPE',
        (map { $_ => 'ESCAPE_WORD3' } 'A' .. 'Z'),
        (map { $_ => 'ESCAPE_WORD2' } 'a' .. 'z'),
    },
    'ESCAPE_WORD3' => {
        $TOKEN_LABEL => 'ESCAPE',
        (map { $_ => 'ESCAPE_WORD' } 'a' .. 'z'),
    },
    'ESCAPE_WORD' => {
        $TOKEN_LABEL => 'ESCAPE',
        (map { $_ => 'ESCAPE_WORD3' } 'A' .. 'Z'),
        (map { $_ => 'ESCAPE_WORD' } 'a' .. 'z'),
    },
    'HTTP1' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        't' => 'URL1',
    },
    'URL1' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        't' => 'URL2',
    },
    'URL2' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        'p' => 'URL3',
    },
    'URL3' => {
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        ':' => 'URL5',
        's' => 'URL4',
    },
    'URL4' => {
        ':' => 'URL5',
    },
    'URL5' => {
        '/' => 'URL6',
    },
    'URL6' => {
        '/' => 'URL',
    },
    'URL7' => {
        $TOKEN_LABEL => 'Z_URL7',
        (map { $_ => 'URL' } 'A' .. 'Z', 'a' .. 'z', '0' .. '9'),
        '-' => 'URL',
        '.' => 'URL7',
        '_' => 'URL',
        '~' => 'URL',
        ':' => 'URL7',
        '/' => 'URL',
        '?' => 'URL7',
        '#' => 'URL',
        '&' => 'URL',
        '+' => 'URL',
        ',' => 'URL7',
        ';' => 'URL7',
        '=' => 'URL',
        '%' => 'URL',
    },
    'URL' => {
        $TOKEN_LABEL => 'FREESTAND',
        (map { $_ => 'URL' } 'A' .. 'Z', 'a' .. 'z', '0' .. '9'),
        '-' => 'URL',
        '.' => 'URL7',
        '_' => 'URL',
        '~' => 'URL',
        ':' => 'URL7',
        '/' => 'URL',
        '?' => 'URL7',
        '#' => 'URL',
        '&' => 'URL',
        '+' => 'URL',
        ',' => 'URL7',
        ';' => 'URL7',
        '=' => 'URL',
        '%' => 'URL',
    },
    'WORD1' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        (map { $_ => 'WORD2' } 'a' .. 'z'),
    },
    'WORD2' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        (map { $_ => 'WORD3' } 'A' .. 'Z'),
        (map { $_ => 'WORD2' } 'a' .. 'z'),
    },
    'WORD3' => {
        $TOKEN_LABEL => 'TEXT',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        (map { $_ => 'WORD' } 'a' .. 'z'),
    },
    'WORD' => {
        $TOKEN_LABEL => 'FREESTAND',
        (map { $_ => 'TEXT' } @TEXT_CHAR),
        (map { $_ => 'PUNCT' } @TEXT_PUNCT),
        (map { $_ => 'WORD3' } 'A' .. 'Z'),
        (map { $_ => 'WORD' } 'a' .. 'z'),
    },
};
my(
    @LEX_TOKEN,
    $LEX_STATE_ENDHEADING1,
    $LEX_STATE_VERBATIM, $LEX_STATE_VERB0, $LEX_STATE_NOWIKI0,
    $LEX_STATE_URL, $LEX_STATE_ESCAPE_URL,
    @LEX_CODE, @LEX_STATE, @LEX_CHECK,
);

if (__FILE__ eq $0) {
    exit main();
}

sub hash_match {
    my($src) = @_;
    my $size = length ${$src};
    my $pos_from = pos ${$src};
    $pos_from = defined $pos_from ? $pos_from : 0;
    my $start = 'S2';
    if ($pos_from == 0 || "\n" eq (substr ${$src}, $pos_from - 1, 1)) {
        $start = 'S0';
        if ($pos_from < $size
            && (q{ } eq (substr ${$src}, $pos_from, 1)
                || "\t" eq (substr ${$src}, $pos_from, 1))
        ) {
            $start = 'S1';
            while ($pos_from < $size
                && (q{ } eq (substr ${$src}, $pos_from, 1)
                    || "\t" eq (substr ${$src}, $pos_from, 1))
            ) {
                ++$pos_from;
            }
        }
    }
    if ($pos_from >= $size) {
        pos(${$src}) = $pos_from;
        return ('EOF', $pos_from, $pos_from);
    }
    my $state = $start;
    my $pos_url = -1;
    my $pos_endheading = -1;
    my $pos_verb0 = -1;
    my $pos = $pos_from;
    while (1) {
        while ($pos < $size) {
            # remember the position on entering lookahead clauses.
            #   URL qr{(?:f|ht)tps?://[withpunct]+[withoutpunct]}
            #   ENDHEADING qr{=+(?=(?:$S*)\n)}
            if ($state eq 'URL' || $state eq 'ESCAPE_URL') {
                $pos_url = $pos;
            }
            elsif ($state eq 'ENDHEADING1') {
                $pos_endheading = $pos;
            }
            elsif ($state eq 'VERB0') {
                $pos_verb0 = $pos;
            }
            # go next state corresponding to the current character.
            my $ch = substr ${$src}, $pos, 1;
            if (! exists $PATTERN->{$state}{$ch}) {
                last;
            }
            $pos++;
            $state = $PATTERN->{$state}{$ch};
        }
        last if $pos_verb0 < 0 || $state eq 'VERBATIM';
        $pos = $pos_verb0;
        $pos_verb0 = -1;
        $state = 'NOWIKI0';
    }
    my $token = 'TEXT';
    if (exists $PATTERN->{$state}{$TOKEN_LABEL}) {
        # if the final state has a token label, we use it. 
        $token = $PATTERN->{$state}{$TOKEN_LABEL};
    }
    else {
        # in default we treat a TEXT which length 1 byte.
        # in this case we got only an seven bits character.
        $pos = $pos_from + 1;
    }
    if ($token eq 'TEXT') {
        # strech region as long as possible. TEXT (BLANK* TEXT)*
        my $pos1 = $pos;
        my $ch = substr ${$src}, $pos1, 1;
        while (1) {
            while ($pos1 < $size && ($ch eq q{ } || $ch eq "\t")) {
                $pos1++;
                $ch = substr ${$src}, $pos1, 1;
            }
            last if $pos1 >= $size;
            # check the substring after blanks TEXT.
            # inline token must be started from state 'S2'.
            my $state = 'S2';
            my $pos2 = $pos1;
            while ($pos2 < $size) {
                $ch = substr ${$src}, $pos2, 1;
                if (! exists $PATTERN->{$state}{$ch}) {
                    last;
                }
                $pos2++;
                $state = $PATTERN->{$state}{$ch};
            }
            my $token1 = 'TEXT';
            if (exists $PATTERN->{$state}{$TOKEN_LABEL}) {
                # if the final state has a token label, we use it. 
                $token1 = $PATTERN->{$state}{$TOKEN_LABEL};
            }
            else {
                $pos2 = $pos1 + 1;
            }
            if ($token1 eq 'TEXT') {
                $pos = $pos1 = $pos2;
            }
            elsif ($token1 eq 'BLANK') {
                $pos1 = $pos2;
            }
            else {
                last;
            }
        }
    }
    elsif ($token eq 'Z_TH') {
        $token = 'TD';
    }
    elsif ($token eq 'TD' || $token eq 'ENDTR') {
        # ignore lookahead region. /\|(?=$S*\n?)/
        $pos = $pos_from + 1;
    }
    elsif ($token eq 'Z_ENDHEADING') {
        # ignore lookahead region. /=+(?=$S*\n)/
        $pos = $pos_endheading;
        $token = 'HEADING';
    }
    elsif ($token eq 'Z_URL7') {
        # ignore last punctuations.
        if ($pos_url >= 0) {
            $pos = $pos_url;
        }
        $token = 'FREESTAND'
    }
    elsif ($token eq 'Z_ESCAPE_URL7') {
        # ignore last punctuations.
        if ($pos_url >= 0) {
            $pos = $pos_url;
        }
        $token = 'ESCAPE'
    }
    elsif ($token eq 'Z_ESCAPE1') {
        # tilde escape one character
        $pos = $pos_from + 1;
        if ($pos < $size) {
            my $ch = substr ${$src}, $pos++, 1;
            if (((ord $ch) & 0xc0) == 0xc0) {
                # UTF-8 : 0b11xxxxxx 0b10xxxxxx+
                while ($pos < $size
                    && ((ord substr ${$src}, $pos, 1) & 0xc0) == 0x80
                ) {
                    ++$pos;
                }
            }
            elsif ($ch eq '[' || $ch eq '{') {
                # broken bracketed or braced, such as ~[[foo]bar]
                ++$pos;
            }
        }
        $token = 'ESCAPE';
    }
    pos(${$src}) = $pos;
    return ($token, $pos_from, $pos); # ($#-, $-[$#-], $+[$#-])
}

sub hash_demo {
    my $wiki_source = do{ local $/ = undef; <DATA> };
    $wiki_source =~ s/(?:\r\n?|\n)/\n/gmsx;
    $wiki_source =~ tr/\x00-\x08\x0b-\x1f\x7f//d;
    while (1) {
        my($token, $p_start, $p_end) = hash_match(\$wiki_source);
        demo_report(\$wiki_source, $token, $p_start, $p_end);
        last if $token eq 'EOF';
    }
}

sub demo_report {
    my($src, $token, $p_start, $p_end) = @_;
    my $t = substr ${$src}, $p_start, $p_end - $p_start;
    $t =~ s/"/\\"/gmsx;
    $t =~ s/\n/\\n/gmsx;
    printf "%s %d '%s'\n", $token, $p_start, $t;
    return;
}

sub array_match {
    my($src, $pattern) = @_;
    my $size = length ${$src};
    my $pos_from = pos ${$src};
    $pos_from = defined $pos_from ? $pos_from : 0;
    my $start = 2;
    if ($pos_from == 0 || "\n" eq (substr ${$src}, $pos_from - 1, 1)) {
        $start = 0;
        if ($pos_from < $size
            && (q{ } eq (substr ${$src}, $pos_from, 1)
                || "\t" eq (substr ${$src}, $pos_from, 1))
        ) {
            $start = 1;
            while ($pos_from < $size
                && (q{ } eq (substr ${$src}, $pos_from, 1)
                    || "\t" eq (substr ${$src}, $pos_from, 1))
            ) {
                ++$pos_from;
            }
        }
    }
    if ($pos_from >= $size) {
        pos(${$src}) = $pos_from;
        return ('EOF', $pos_from, $pos_from);
    }
    my $state = $LEX_STATE[$start];
    my $pos_url = -1;
    my $pos_endheading = -1;
    my $pos_verbatim = -1;
    my $pos = $pos_from;
    while (1) {
        while ($pos < $size) {
            # remember the position on entering lookahead clauses.
            #   URL qr{(?:f|ht)tps?://[withpunct]+[withoutpunct]}
            #   ENDHEADING qr{=+(?=(?:$S*)\n)}
            if ($state == $LEX_STATE_URL || $state == $LEX_STATE_ESCAPE_URL) {
                $pos_url = $pos;
            }
            elsif ($state == $LEX_STATE_ENDHEADING1) {
                $pos_endheading = $pos;
            }
            elsif ($state == $LEX_STATE_VERB0) {
                $pos_verbatim = $pos;
            }
            # go next state corresponding to the current character.
            my $c = $LEX_CODE[ord(substr ${$src}, $pos, 1)];
            if ($LEX_CHECK[$state + $c] != $state) {
                last;
            }
            $pos++;
            $state = $LEX_STATE[$state + $c];
        }
        last if $pos_verbatim < 0 || $state == $LEX_STATE_VERBATIM;
        $pos = $pos_verbatim;
        $pos_verbatim = -1;
        $state = $LEX_STATE_NOWIKI0;        
    }
    my $token = 'TEXT';
    if ($LEX_CHECK[$state] == $state) {
        # if the final state has a token label, we use it. 
        $token = $LEX_TOKEN[-$LEX_STATE[$state]];
    }
    else {
        # in default we treat a TEXT which length 1 byte.
        # in this case we got only an seven bits character.
        $pos = $pos_from + 1;
    }
    if ($token eq 'TEXT') {
        # strech region as long as possible. TEXT (BLANK* TEXT)*
        my $pos1 = $pos;
        my $ch = substr ${$src}, $pos1, 1;
        while (1) {
            while ($pos1 < $size && ($ch eq q{ } || $ch eq "\t")) {
                $pos1++;
                $ch = substr ${$src}, $pos1, 1;
            }
            last if $pos1 >= $size;
            # check the substring after blanks TEXT.
            # inline token must be started from state 'S2'.
            my $state = $LEX_STATE[2];
            my $pos2 = $pos1;
            while ($pos2 < $size) {
                $ch = substr ${$src}, $pos2, 1;
                my $c = $LEX_CODE[ord $ch];
                if ($LEX_CHECK[$state + $c] != $state) {
                    last;
                }
                $pos2++;
                $state = $LEX_STATE[$state + $c];
            }
            my $token1 = 'TEXT';
            if ($LEX_CHECK[$state] == $state) {
                # if the final state has a token label, we use it. 
                $token1 = $LEX_TOKEN[-$LEX_STATE[$state]];
            }
            else {
                # in default we treat a TEXT which length 1 byte.
                # in this case we got only an seven bits character.
                $pos2 = $pos1 + 1;
            }
            if ($token1 eq 'TEXT') {
                $pos = $pos1 = $pos2;
            }
            elsif ($token1 eq 'BLANK') {
                $pos1 = $pos2;
            }
            else {
                last;
            }
        }
    }
    elsif ($token eq 'Z_TH') {
        $token = 'TD';
    }
    elsif ($token eq 'TD' || $token eq 'ENDTR') {
        # ignore lookahead region. /\|(?=$S*\n?)/
        $pos = $pos_from + 1;
    }
    elsif ($token eq 'Z_ENDHEADING') {
        # ignore lookahead region. /=+(?=$S*\n)/
        $pos = $pos_endheading;
        $token = 'HEADING';
    }
    elsif ($token eq 'Z_URL7') {
        # ignore last punctuations.
        if ($pos_url) {
            $pos = $pos_url;
        }
        $token = 'URL'
    }
    elsif ($token eq 'Z_ESCAPE_URL7') {
        # ignore last punctuations.
        if ($pos_url) {
            $pos = $pos_url;
        }
        $token = 'ESCAPE'
    }
    elsif ($token eq 'Z_ESCAPE1') {
        # tilde escape one character
        $pos = $pos_from + 1;
        if ($pos < $size) {
            my $ch = substr ${$src}, $pos++, 1;
            if (((ord $ch) & 0xc0) == 0xc0) {
                # UTF-8 : 0b11xxxxxx 0b10xxxxxx+
                while ($pos < $size
                    && ((ord substr ${$src}, $pos, 1) & 0xc0) == 0x80
                ) {
                    ++$pos;
                }
            }
            elsif ($ch eq '[' || $ch eq '{') {
                # broken bracketed or braced, such as ~[[foo]bar]
                ++$pos;
            }
        }
        $token = 'ESCAPE';
    }
    pos(${$src}) = $pos;
    return ($token, $pos_from, $pos); # ($#-, $-[$#-], $+[$#-])
}

sub create_sparce_array {
    my $tokens = make_token_table($PATTERN);
    my($ctypes, $max_ctype) = make_ctype_array($PATTERN);
    my($dest, $check, $base, $room)
        = make_sparce_array($PATTERN, $tokens, $ctypes, $max_ctype);
    for my $name (sort keys %{$tokens}) {
        $LEX_TOKEN[$tokens->{$name}] = $name;
    }
    @LEX_CODE = @{$ctypes};
    $LEX_STATE_ENDHEADING1 = $base->{'ENDHEADING1'};
    $LEX_STATE_VERBATIM = $base->{'VERBATIM'};
    $LEX_STATE_VERB0 = $base->{'VERB0'};
    $LEX_STATE_NOWIKI0 = $base->{'NOWIKI0'};
    $LEX_STATE_URL = $base->{'URL'};
    $LEX_STATE_ESCAPE_URL = $base->{'ESCAPE_URL'};
    @LEX_STATE = @{$dest};
    @LEX_CHECK = @{$check};
}

sub array_demo {
    create_sparce_array();
    my $wiki_source = do{ local $/ = undef; <DATA> };
    $wiki_source =~ s/(?:\r\n?|\n)/\n/gmsx;
    $wiki_source =~ tr/\x00-\x08\x0b-\x1f\x7f//d;
    while (1) {
        my($token, $p_start, $p_end) = array_match(\$wiki_source);
        demo_report(\$wiki_source, $token, $p_start, $p_end);
        last if $token eq 'EOF';
    }
}

sub make_token_table {
    my($pattern) = @_;
    my %uniq;
    my %token;
    for my $state (keys %{$pattern}) {
        if (exists $pattern->{$state}{$TOKEN_LABEL}) {
            $uniq{$pattern->{$state}{$TOKEN_LABEL}} = 1;
        }
    }
    my $i = 0;
    for my $name (sort keys %uniq) {
        $token{$name} = ++$i;
    }
    $token{'EOF'} = 0;
    return \%token;
}

sub make_ctype_array {
    my($pattern) = @_;
    my @cset = (q{:}) x 256;
    for my $key (keys %{$PATTERN}) {
        for my $c (0 .. 255) {
            my $ct = exists $PATTERN->{$key}{chr $c}
                ? $PATTERN->{$key}{chr $c}
                : q{};
            $cset[$c] .= "$ct:";
        }
    }
    my %ctypemap;
    my $ctypeno = 0;
    for my $i (0, 0x09, 0x0a, 0x20 .. 0x7e, 0x80 .. 0xff) {
        my $k = $cset[$i];
        next if exists $ctypemap{$k};
        $ctypemap{$k} = $ctypeno++;
    }
    return ([map { $ctypemap{$_} } @cset], $ctypeno - 1);
}

sub make_sparce_array {
    my($hash, $tokens, $ctypes, $max_ctype) = @_;
    my @states = sort keys %{$hash};
    my @dest = (0, 1, 2);
    my @check = (0, 1, 2);
    my %base;
    my %used;
    my $maxbp = 0;
    for my $state (@states) {
        my @bytes = sort map { $ctypes->[ord $_] } keys %{$hash->{$state}};
        my $bp = 3;
        while (1) {
            if (exists $used{$bp}) {
                $bp++;
                next;
            }
            my $empty = 1;
            for my $i (@bytes) {
                if (defined $dest[$bp + $i]) {
                    $empty = 0;
                    last;
                }
            }
            last if $empty;
            $bp++;
        }
        for my $i (@bytes) {
            $dest[$bp + $i] = 0;
            $check[$bp + $i] = $bp;
        }
        $base{$state} = $bp;
        $used{$bp} = $state;
        $maxbp = $bp > $maxbp ? $bp : $maxbp;
    }
    my $room = 0;
    for my $i (0 .. $maxbp + $max_ctype) {
        if (! defined $dest[$i]) {
            ++$room;
            $dest[$i] = 0;
            $check[$i] = 0;
        }
    }
    for my $state (@states) {
        my $bp = $base{$state};
        for my $ch (keys %{$hash->{$state}}) {
            if ($ch eq $TOKEN_LABEL) {
                $dest[$bp] = -$tokens->{$hash->{$state}{$ch}};
            }
            else {
                if (! defined $base{$hash->{$state}{$ch}}) {
                    warn "not defined base $state $ch";
                }
                my $p = $bp + $ctypes->[ord $ch];
                $dest[$p] = $base{$hash->{$state}{$ch}};
            }
        }
    }
    $dest[0] = $base{'S0'};
    $dest[1] = $base{'S1'};
    $dest[2] = $base{'S2'};
    return (\@dest, \@check, \%base, $room);
}

sub print_sparce_list {
    my $tokens = make_token_table($PATTERN);
    my($ctypes, $max_ctype) = make_ctype_array($PATTERN);
    my($dest, $check, $base, $room)
        = make_sparce_array($PATTERN, $tokens, $ctypes, $max_ctype);
    my $size = keys %{$PATTERN};
    printf "##dest %d check %d base %d room %d full %d %4.1f%%\n",
        $#{$dest} + 1, $#{$check} + 1,
        (scalar keys %{$base}),
        $room, $size * 37, 2 * @{$dest} / ($size * 37) * 100;
    print "##token\n";
    for my $token (sort keys %{$tokens}) {
        printf "%d %s\n", -$tokens->{$token}, $token;
    }
    print "\n";
    print "##state entries\n";
    for my $state (sort keys %{$base}) {
        printf "%4d %s\n", $base->{$state}, $state;
    }
    print "\n";
    print "##ord code chr\n";
    for my $i (0x09, 0x0a, 0x20 .. 0x7e, 0x80 .. 0xff) {
        printf "%02x %2d   %s\n", $i, $ctypes->[$i],
            q{'} eq chr $i ? qq{"'"}
            : $i >= 0x20 && $i <= 0x7e ? q{'} . (chr $i) . q{'}
            : $i == 0x09 ? qq{"\\t"}
            : $i == 0x0a ? qq{"\\n"}
            : q{}; 
    }
    print "\n";
    print "##lex state check\n";
    for my $i (0 .. $#{$dest}) {
        if (! defined $dest->[$i]) {
            warn "dest $i undefined";
            $dest->[$i] = 0;
        }
        if (! defined $check->[$i]) {
            warn "check $i undefined";
            $check->[$i] = 0;
        }
        printf "%04d  %4d %4d\n", $i, $dest->[$i], $check->[$i];
    }
}

sub print_sparce_c {
    my $tokens = make_token_table($PATTERN);
    my($ctypes, $max_ctype) = make_ctype_array($PATTERN);
    my($dest, $check, $base, $room)
        = make_sparce_array($PATTERN, $tokens, $ctypes, $max_ctype);
    my $size = keys %{$PATTERN};
    print <<'EOS';
/* Sparce DFA Array for WikiCreole1.0 and Some Additions
 *
 * entry points:
 *
 *    state S0 => LEX_STATE[0] when line top
 *    state S1 => LEX_STATE[1] when after the LEX_BLANK at line top
 *    state S2 => LEX_STATE[2] otherwise
 *
 * get (short int)next_state for (unsigned char)c on (short int)state:
 *
 *    if (LEX_CODE[c] > 0 && LEX_CHECK[state + LEX_CODE[c]] == state) {
 *        next_state = LEX_STATE[state + LEX_CODE[c]];
 *    }
 *    else {
 *        end of state-chages
 *    }
 *
 * get the token number for the current state:
 *
 *    token = LEX_CHECK[state] == state ? -LEX_STATE[state] : LEX_TEXT;
 */
EOS
    print "enum {\n";
    my @token;
    for my $name (sort keys %{$tokens}) {
        $token[$tokens->{$name}] = $name;
    }
    print "       ";
    my $col = 7;
    for my $i (0 .. $#token) {
        my $s = "LEX_$token[$i]";
        if ($i < $#token) {
            $s .= ",";
        }
        if ($col + 1 + (length $s) >= 80) {
            print "\n       ";
            $col = 7;
        }
        print " $s";
        $col += 1 + (length $s);
    }
    print "\n";
    print "};\n";
    print "enum {\n";
    print "        LEX_STATE_ENDHEADING1 = $base->{'ENDHEADING1'},\n";
    print "        LEX_STATE_VERBATIM = $base->{'VERBATIM'},\n";
    print "        LEX_STATE_VERB0 = $base->{'VERB0'},\n";
    print "        LEX_STATE_NOWIKI0 = $base->{'NOWIKI0'},\n";
    print "        LEX_STATE_URL = $base->{'URL'},\n";
    print "        LEX_STATE_ESCAPE_URL = $base->{'ESCAPE_URL'}\n";
    print "};\n";
    print "#define LEX_TOKEN_NAME_SIZE @{[ scalar @token ]}\n";
    print "static const char * const LEX_TOKEN_NAME[] = {\n";
    print "       ";
    $col = 7;
    for my $i (0 .. $#token) {
        my $s = qq{"$token[$i]"};
        if ($i < $#token) {
            $s .= ",";
        }
        if ($col + 1 + (length $s) >= 80) {
            print "\n       ";
            $col = 7;
        }
        print " $s";
        $col += 1 + (length $s);
    }
    print "\n";
    print "};\n";
    print "static const char const LEX_CODE[] = {\n";
    for my $i (0 .. 255) {
        if ($i % 16 == 0) {
            print "       ";
        }
        print " ";
        if (defined $ctypes->[$i]) {
            print $ctypes->[$i];
        }
        else {
            print -1;
        }
        if ($i < 255) {
            print ",";
        }
        if ($i % 16 == 15) {
            print "\n";
        }
    }
    print "};\n";
    print "static const short int const LEX_STATE[] = {\n";
    print "       ";
    $col = 7;
    for my $i (0 .. $#{$dest}) {
        my $s = $dest->[$i];
        if ($i < $#{$dest}) {
            $s .= ',';
        }
        if ($col + 1 + (length $s) >= 80) {
            print "\n       ";
            $col = 7;
        }
        print " $s";
        $col += 1 + (length $s);
    }
    print "\n";
    print "};\n";
    print "static const short int const LEX_CHECK[] = {\n";
    print "       ";
    $col = 7;
    for my $i (0 .. $#{$dest}) {
        my $s = $check->[$i];
        if ($i < $#{$dest}) {
            $s .= ',';
        }
        if ($col + 1 + (length $s) >= 80) {
            print "\n       ";
            $col = 7;
        }
        print " $s";
        $col += 1 + (length $s);
    }
    print "\n";
    print "};\n";
}

sub main {
    my $func;
    my $unknown = 0;
    while (@ARGV && $ARGV[0] =~ /\A-/msx) {
        for (shift @ARGV) {
            /\A-h(?:ash)?\z/msx && do{ $func = \&hash_demo; last };
            /\A-a(?:rray)?\z/msx && do{ $func = \&array_demo; last };
            /\A-l(?:ist)?\z/msx && do{ $func = \&print_sparce_list; last };
            /\A-p(?:[lm]|erl)\z/msx && do{
                $func = \&print_sparce_perl; last };
            /\A-c\z/msx && do{ $func = \&print_sparce_c; last };
            /\A-(?:\?|help)\z/mx && do{ $func = \&print_help; last };
            $unknown = 1; last;
        }
    }
    if (! $func || $unknown) {
        print_help();
        return 2;
    }
    $func->();
    return 0;
} 

sub print_help {
    print STDERR
        "DFA for WikiCreole demonstration.\n",
        "usage: perl $0 -option\n",
        "  options:\n",
        "  -h -hash   run hash demo.\n",
        "  -a -array  run array demo.\n",
        "  -l -list   print list of sparce array.\n",
        "  -pl -perl  print perl source of sparce array.\n",
        "  -c         print C source of sparce array.\n",
        "  -? -help   ptinr this help.\n";
}

1;

__END__
= Top-level heading (1 1)
== This a test for creole 0.1 (1 2)
=== This is a Subheading (1 3)
==== Subsub (1 4)
===== Subsubsub (1 5)

The ending equal signs should not be displayed:

= Top-level heading (2 1) =
== This a test for creole 0.1 (2 2) ==
=== This is a Subheading (2 3) ===
==== Subsub (2 4) ====
===== Subsubsub (2 5) =====


You can make things **bold** or //italic// or **//both//** or //**both**//.

Character formatting extends across line breaks: **bold,
this is still bold. This line deliberately does not end in star-star.

Not bold. Character formatting does not cross paragraph boundaries.

You can use [[internal links]] or [[http://www.wikicreole.org|external links]],
give the link a [[internal links|different]] name.

Here's another sentence: This wisdom is taken from [[Ward Cunningham's]]
[[http://www.c2.com/doc/wikisym/WikiSym2006.pdf|Presentation at the Wikisym 06]].

Here's a external link without a description: [[http://www.wikicreole.org]]

Be careful that italic links are rendered properly:  //[[http://my.book.example/|My Book Title]]// 

Free links without braces should be rendered as well, like http://www.wikicreole.org/ and http://www.wikicreole.org/users/~example. 

Creole1.0 specifies that http://bar and ftp://bar should not render italic,
something like foo://bar should render as italic.

You can use this to draw a line to separate the page:
----

You can use lists, start it at the first column for now, please...

unnumbered lists are like
* item a
* item b
* **bold item c**

blank space is also permitted before lists like:
  *   item a
 * item b
* item c
 ** item c.a

or you can number them
# [[item 1]]
# item 2
# // italic item 3 //
    ## item 3.1
  ## item 3.2

up to five levels
* 1
** 2
*** 3
**** 4
***** 5

* You can have
multiline list items
* this is a second multiline
list item

You can use nowiki syntax if you would like do stuff like this:

{{{
Guitar Chord C:

||---|---|---|
||-0-|---|---|
||---|---|---|
||---|-0-|---|
||---|---|-0-|
||---|---|---|
}}}

You can also use it inline nowiki {{{ in a sentence }}} like this.

= Escapes =
Normal Link: http://wikicreole.org/ - now same link, but escaped: ~http://wikicreole.org/ 

Normal asterisks: ~**not bold~**

a tilde alone: ~

a tilde escapes itself: ~~xxx

=== Creole 0.2 ===

This should be a flower with the ALT text "this is a flower" if your wiki supports ALT text on images:

{{Red-Flower.jpg|here is a red flower}}

=== Creole 0.4 ===

Tables are done like this:

|=header col1|=header col2| 
|col1|col2| 
|you         |can         | 
|also        |align\\ it. | 

You can format an address by simply forcing linebreaks:

My contact dates:\\
Pone: xyz\\
Fax: +45\\
Mobile: abc

=== Creole 0.5 ===

|= Header title               |= Another header title     |
| {{{ //not italic text// }}} | {{{ **not bold text** }}} |
| //italic text//             | **  bold text **          |

=== Creole 1.0 ===

If interwiki links are setup in your wiki, this links to the WikiCreole page about Creole 1.0 test cases: [[WikiCreole:Creole1.0TestCases]].

