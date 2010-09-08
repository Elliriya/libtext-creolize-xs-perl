#!/usr/bin/perl
use strict;
use warnings;
use Test::Base;
use Text::Creolize::Xs;
use Encode qw(encode_utf8);

my $U8 = "\x{898b}\x{3048}\x{3066}\x{308b}\x{ff1f}"; # can you see?

delimiters qw(.test .sect);
plan tests => 3 * blocks;

filters {
    input => [qw(expand_u8 test_creolize chomp)],
    expected => [qw(expand_u8 chomp)],
};

run {
    my($block) = @_;
    ok utf8::is_utf8($block->input), $block->name . ' input';
    ok utf8::is_utf8($block->expected), $block->name . ' expected';
    is encode_utf8($block->input), encode_utf8($block->expected), $block->name;
};

sub test_creolize {
    return Text::Creolize::Xs->new({toc => 1})->convert(@_)->result;
}

sub expand_u8 {
    my($input) = @_;
    $input =~ s/\$U8/$U8/gmosx;
    return $input;
}

__END__

.test utf8 paragraph
.sect input
can you see $U8
.sect expected
<p>can you see $U8</p>

.test utf8 link
.sect input
can you see [[a|$U8]]
.sect expected
<p>can you see <a href="http://www.example.net/wiki/a">$U8</a></p>

.test utf8 image
.sect input
can you see {{b.gif|$U8}}
.sect expected
<p>can you see <img src="http://www.example.net/static/b.gif" alt="$U8" /></p>

.test utf8 nowiki
.sect input
can you see {{{$U8}}}
.sect expected
<p>can you see <code>$U8</code></p>

.test utf8 verbatim
.sect input
{{{
can you see $U8
}}}
.sect expected
<pre>can you see $U8</pre>

.test utf8 toc
.sect input
= abcde
alphabet abcde
== $U8
kanji+hiragana $U8
.sect expected
<div class="toc">
<ul>
<li><a href="#h0mlk8br">abcde</a>
<ul>
<li><a href="#h0rqj3oc">$U8</a></li>
</ul>
</li>
</ul>
</div>
<h1 id="h0mlk8br">abcde</h1>
<p>alphabet abcde</p>
<h2 id="h0rqj3oc">$U8</h2>
<p>kanji+hiragana $U8</p>

