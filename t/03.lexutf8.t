use strict;
use warnings;
use Test::More;
use Text::Creolize::Xs;
use utf8;

my @try_token = (
    ['TEXT', "\x{3042}\x{3044}\x{3046}\x{3048}\x{304a}"],
    ['PHRASE', '//'],
    ['TEXT', 'foo'],
    ['PHRASE', '//'],
    ['BLANK', ' ', 2],
    ['TEXT', "bar \x{304b}\x{304d}\x{304f}\x{3051}\x{3053} baz"],
    ['ESCAPE', '~[['],
    ['EOL', "\n"],
    ['EOF', ''],
);

plan tests => 2 * @try_token;

my $class = 'Text::Creolize::Xs';
my $source = join q{}, map { $_->[1] } @try_token;

for my $x (@try_token) {
    my($token, $p0, $p1) = $class->match($source);
    my $token_name = $class->token_name($token);
    
    my $s = $x->[1];
    $s =~ s/([\x{0080}-\x{ffff}])/sprintf "\\x{%04x}", ord $1/egmsx;
    $s =~ s/\t/\\t/gmsx;
    $s =~ s/\n/\\n/gmsx;
    $s =~ s/"/\\"/gmsx;

    is $p1 - $p0, length $x->[1], "match \"$s\"";
    is $token_name, $x->[0], "token $token $token_name";
}

done_testing();

