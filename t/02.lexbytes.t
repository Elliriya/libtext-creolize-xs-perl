use strict;
use warnings;
use Test::More;
use Text::Creolize::Xs;
use bytes;

my @try_token = (
    ['TEXT', "\343\201\202\343\201\204\343\201\206\343\201\210\343\201\212"],
    ['PHRASE', '**'],
    ['TEXT', '19768'],
    ['PHRASE', '**'],
    ['BLANK', ' ', 2],
    ['TEXT', "bar \343\201\213\343\201\215\343\201\217\343\201\221\343\201\223 baz"],
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
    $s =~ s/([\x80-\xff])/sprintf "\\%03o", ord $1/egmsx;
    $s =~ s/\t/\\t/gmsx;
    $s =~ s/\n/\\n/gmsx;
    $s =~ s/"/\\"/gmsx;

    is $p1 - $p0, length $x->[1], "match \"$s\"";
    is $token_name, $x->[0], "token $token $token_name";
}

done_testing();

