use strict;
use warnings;
use Test::Base;
use Text::Creolize::Xs;

spec_file('t/lexspec');

plan tests => 1 * blocks;
filters {
    input => [qw(eval creolize_lex)],
    expected => [qw(eval)],
};
run_is_deeply 'input' => 'expected';

sub creolize_lex {
    my($source) = @_;
    my $class = 'Text::Creolize::Xs';
    my @token_list;
    while (1) {
        my($token, $p0, $p1) = $class->match($source);
        my $token_name = $class->token_name($token);
        push @token_list, [$token_name, substr $source, $p0, $p1 - $p0];
        last if $token_name eq 'EOF';
    }
    return \@token_list;
}

