use strict;
use warnings;
use Test::Base;

diag "test of lex/genlex.pl";
require 'lex/genlex.pl';

spec_file('t/lexspec');

plan tests => 1 * blocks;
filters {
    input => [qw(eval creolize_lex)],
    expected => [qw(eval)],
};
run_is_deeply 'input' => 'expected';

sub creolize_lex {
    my($source) = @_;
    my @token_list;
    while (1) {
        my($token_name, $p0, $p1) = hash_match(\$source);
        push @token_list, [$token_name, substr $source, $p0, $p1 - $p0];
        last if $token_name eq 'EOF';
    }
    return \@token_list;
}

