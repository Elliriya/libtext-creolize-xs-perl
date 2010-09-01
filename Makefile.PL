use 5.008002;
use ExtUtils::MakeMaker;

WriteMakefile(
    NAME          => 'Text::Creolize::Xs',
    VERSION_FROM  => 'lib/Text/Creolize/Xs.pm',
    PREREQ_PM     => {
        'Test::Base' => 0,
        'Encode' => 0,
        'Digest::MurmurHash' => 0,
    },
    ABSTRACT_FROM => 'lib/Text/Creolize/Xs.pm',
    AUTHOR        => 'MIZUTANI Tociyuki <tociyuki@gmail.com>',
    PL_FILES      => {},
    LIBS          => [''],  # e.g., '-lm'
    DEFINE        => '',    # e.g., '-DHAVE_SOMETHING'
    INC           => '-I.', # e.g., '-I. -I/usr/include/other'
    # OBJECT       => '$(O_FILES)', # link all the C files too
    depend        => {'Xs.o' => 'lex/creolize-lex.h lex/creolize-grammar.h'},
    clean         => {FILES => 'lex/creolize-lex.h lex/creolize-grammar.h'},
    dist          => {COMPRESS => 'gzip -9f', SUFFIX => 'gz',},
);

sub MY::postamble {
'
lex/creolize-lex.h :: lex/genlex.pl
	$(PERL) lex/genlex.pl -c >lex/creolize-lex.h

lex/creolize-grammar.h :: lex/gengrammar.pl
	$(PERL) lex/gengrammar.pl -c >lex/creolize-grammar.h

hashdemo ::
	$(PERL) lex/genlex.pl -h

arraydemo ::
	$(PERL) lex/genlex.pl -a
';
}

