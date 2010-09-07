package Text::Creolize::Xs;
use 5.008002;
use strict;
use warnings;
use Encode qw();
use Digest::MurmurHash;

# $Id: Xs.pm,v 0.003 2010/09/07 03:03:49Z tociyuki Exp $
use version; our $VERSION = '0.003';

require XSLoader;
XSLoader::load('Text::Creolize::Xs', $VERSION);

my %MARKUP = (
    q{=} => {stag => q{<h1>}, etag => qq{</h1>\n}},
    q{==} => {stag => q{<h2>}, etag => qq{</h2>\n}},
    q{===} => {stag => q{<h3>}, etag => qq{</h3>\n}},
    q{====} => {stag => q{<h4>}, etag => qq{</h4>\n}},
    q{=====} => {stag => q{<h5>}, etag => qq{</h5>\n}},
    q{======} => {stag => q{<h6>}, etag => qq{</h6>\n}},
    q{p} => {stag => q{<p>}, etag => qq{</p>\n}},
    q{verbatim} => {stag => q{<pre>}, etag => qq{</pre>\n}},
    q{----} => {tag => qq{<hr />\n}},
    q{*} => {
        stag => qq{<ul>\n<li>}, etag => qq{</li>\n</ul>\n},
        q{*} => qq{</li>\n<li>}, q{#} => qq{</li>\n</ul>\n<ol>\n<li>},
        q{;} => qq{</li>\n</ul>\n<dl>\n<dt>},
        q{:} => qq{</li>\n</ul>\n<dl>\n<dd>},
    },
    q{#} => {
        stag => qq{<ol>\n<li>}, etag => qq{</li>\n</ol>\n},
        q{#} => qq{</li>\n<li>}, q{*} => qq{</li>\n</ol>\n<ul>\n<li>},
        q{;} => qq{</li>\n</ol>\n<dl>\n<dt>},
        q{:} => qq{</li>\n</ul>\n<dl>\n<dd>},
    },
    q{;} =>  {
        stag => qq{<dl>\n<dt>}, etag => qq{</dt>\n</dl>\n},
        q{;} => qq{</dt>\n<dt>}, q{:} => qq{</dt>\n<dd>},
        q{*} => qq{</dt>\n</dl>\n<ul>\n<li>},
        q{#} => qq{</dt>\n</dl>\n<ol>\n<li>},
    },
    q{:} =>  {
        stag => qq{<dl>\n<dd>}, etag => qq{</dd>\n</dl>\n},
        q{;} => qq{</dd>\n<dt>}, q{:} => qq{</dd>\n<dd>},
        q{*} => qq{</dd>\n</dl>\n<ul>\n<li>},
        q{#} => qq{</dd>\n</dl>\n<ol>\n<li>},
    },
    q{||} => {
        stag => qq{<table>\n<tr>}, etag => qq{</tr>\n</table>\n},
        q{||} => qq{</tr>\n<tr>},
    },
    q{|} =>  {stag => q{<td>}, etag => q{</td>}},
    q{|=} => {stag => q{<th>}, etag => q{</th>}},
    q{>} => {
        stag => qq{<div style="margin-left:2em">\n}, etag => qq{</div>\n},
    },
    q{**} => {stag => q{<strong>}, etag => q{</strong>}},
    q{//} => {stag => q{<em>}, etag => q{</em>}},
    q{##} => {stag => q{<tt>}, etag => q{</tt>}},
    q{^^} => {stag => q{<sup>}, etag => q{</sup>}},
    q{,,} => {stag => q{<sub>}, etag => q{</sub>}},
    q{__} => {stag => q{<span class="underline">}, etag => q{</span>}},
    q{\\\\} =>   {tag => qq{<br />\n}},
    q{nowiki} => {stag => q{<code>}, etag => q{</code>}},
    q{<<<} => {stag => q{<span class="placeholder">}, etag => q{</span>}},
    q{toc} => {stag => qq{<div class="toc">\n}, etag => qq{</div>\n}},
);
my @BASE36 = ('0' .. '9', 'a' .. 'z');
my %XML_SPECIAL = (
    q{&} => q{&amp;}, q{<} => q{&lt;}, q{>} => q{&gt;},
    q{"} => q{&quot;}, q{'} => q{&#39;},
);
my $AMP = qr{(?:[a-zA-Z_][a-zA-Z0-9_]*|\#(?:[0-9]{1,5}|x[0-9a-fA-F]{2,4}))}msx;
my $S = qr{[\x20\t]}msx;
my $WTYPE_NULL = 0;
my $WTYPE_TEXT = 1;
my $WTYPE_STAG = 2;
my $WTYPE_ETAG = 3;

# Text::Creolize::Xs->new(script_name => 'http:example.net/wiki/', ...);
# Text::Creolize::Xs->new({script_name => 'http:example.net/wiki/', ...});
sub new {
    my($class, @arg) = @_;
    my $self = bless {}, $class;
    $self->_init(@arg);
    $self->_xs_alloc;
    return $self;
}

sub DESTROY {
    my($self) = @_;
    $self->_xs_free;
    return;
}

sub script_name { return shift->_attr(script_name => @_) }
sub static_location { return shift->_attr(static_location => @_) }
sub link_visitor { return shift->_attr(link_visitor => @_) }
sub plugin_visitor { return shift->_attr(plugin_visitor => @_) }
sub result { return shift->_attr(result => @_) }
sub toc { return shift->_attr(toc => @_) }
sub tocinfo { return shift->_attr(tocinfo => @_) }

sub convert {
    my($self, $wiki_source) = @_;
    $wiki_source =~ s/(?:\r\n?|\n)/\n/gmosx;
    chomp $wiki_source;
    $wiki_source .= "\n";
    $self->_scan($wiki_source);
    if (defined $self->{toc} && @{$self->{tocinfo}} >= $self->{toc}) {
        my $toc = $self->_list_toc->result;
        $self->{result} = $toc . $self->{result};
    }
    return $self;
}

sub _init {
    my($self, @arg) = @_;
    %{$self} = (
        link_visitor => undef,
        plugin_visitor => undef,
        markup_visitor => undef,
        script_name => 'http://www.example.net/wiki/',
        static_location => 'http://www.example.net/static/',
        result => q{},
        tocinfo => [],
    );
    my $opt = ref $arg[0] eq 'HASH' && @arg == 1 ? $arg[0] : {@arg};
    for my $k (qw(
        script_name static_location
        link_visitor plugin_visitor markup_visitor toc
    )) {
        next if ! exists $opt->{$k};
        $self->{$k} = $opt->{$k};
    }
    return;
}

sub _attr {
    my($self, $f, @arg) = @_;
    if (@arg) {
        $self->{$f} = $arg[0];
    }
    return $self->{$f};
}

# VISITORS
# $hash_anchor = $creolize->link_visitor->visit_link($link, $title, $creolize);
sub visit_link {
    my($self, $link, $title, $builder) = @_;
    return if $link =~ /script:/imosx;
    if ($link !~ m{\A(?:(?:https?|ftps?)://|\#)}mosx) {
        $link = $builder->script_name . $link;
    }
    return {href => $link};
}

# $hash_image = $creolize->link_visitor->visit_image($link, $title, $creolize);
sub visit_image {
    my($self, $link, $title, $builder) = @_;
    if ($link !~ m{\Ahttps?://}mosx) {
        $link = $builder->static_location . $link;
    }
    return {src => $link, alt => $title};
}

# $src = $creolize->plugin_visitor->visit_plugin($data, $creolize);
sub visit_plugin {
    my($self, $data, $builder) = @_;
    return $self;
}

# GENERATORS
sub _start_block {
    my($self, $mark) = @_;
    $self->_put_markup_string($MARKUP{$mark}{'stag'}, 'stag');
    $self->{phrase} = {};
    return $self;
}

sub _end_block {
    my($self, $mark) = @_;
    $self->_phrase_flush;
    $self->_put_markup_string($MARKUP{$mark}{'etag'}, 'etag');
    return $self;
}

sub _put_markup {
    my($self, $mark, $type) = @_;
    $self->_put_markup_string($MARKUP{$mark}{$type}, $type);
    return $self;
}

sub escape_xml {
    my($self, $data) = @_;
    $data =~ s{([&<>"'])}{ $XML_SPECIAL{$1} }egmosx;
    return $data;
}

sub escape_text {
    my($self, $data) = @_;
    $data =~ s{(?:([<>"'])|\&(?:($AMP);)?)}{
        $1 ? $XML_SPECIAL{$1} : $2 ? qq{\&$2;} : q{&amp;}
    }egmosx;
    return $data;
}

sub escape_uri {
    my($self, $uri) = @_;
    if (utf8::is_utf8($uri)) {
        $uri = Encode::encode('utf-8', $uri);
    }
    $uri =~ s{
        (?:(\%([0-9A-Fa-f]{2})?)|(&(?:amp;)?)|([^a-zA-Z0-9_~\-.=+\$,:\@/;?\#]))
    }{
        $2 ? $1 : $1 ? '%25' : $3 ? '&amp;' : sprintf '%%%02X', ord $4
    }egmosx;
    return $uri;
}

sub escape_name {
    my($self, $name) = @_;
    if (utf8::is_utf8($name)) {
        $name = Encode::encode('utf-8', $name);
    }
    $name =~ s{([^a-zA-Z0-9_.\-:/])}{ sprintf "%%%02X", ord($1) }msxge;
    return $name;
}

sub hash_base36 {
    my($self, $text) = @_;
    if (utf8::is_utf8($text)) {
        $text = Encode::encode_utf8($text);
    }
    my $x = Digest::MurmurHash::murmur_hash($text);
    my $b36 = q{};
    for my $e (2176782336, 60466176, 1679616, 46656, 1296, 36, 1) {
        $b36 .= $BASE36[$x / $e];
        $x = $x % $e;
    }
    return $b36;
}

# BLOCK ACTIONS
# paragraphs
sub _start_p { return shift->_start_block('p') }
sub _end_p { return shift->_end_block('p') }

# horizontal rules
sub _insert_hr { return shift->_put_markup(q{----}, 'tag') }

# headings
sub _start_h {
    my($self, $data) = @_;
    ($self->{heading}) = $data =~ /\A(={1,6})/mosx;
    $self->{heading_pos} = length $self->{result};
    return $self->_start_block($self->{heading});
}

sub _end_h {
    my($self, $data) = @_;
    my $mark = delete $self->{heading};
    $self->_end_block($mark);
    return $self if ! defined $self->{toc};
    my $p = index $self->{result}, q{<h}, $self->{heading_pos};
    return $self if $p < 0;
    my $text = substr $self->{result}, $self->{heading_pos};
    chomp $text;
    $text =~ s/<.*?>//gmosx;
    return $self if ! $text;
    my $id = 'h' . $self->hash_base36($text);
    substr $self->{result}, $p + 3, 0, qq{ id="$id"};
    push @{$self->{tocinfo}}, [length $mark, $id, $text];
    return $self;
}

sub _list_toc {
    my($self) = @_;
    my $toc = (ref $self)->new;
    $toc->_put_markup('toc', 'stag');
    $toc->{list} = [];
    for my $info (@{$self->{tocinfo}}) {
        $toc->_insert_list(q{*} x $info->[0]);
        $toc->_insert_link($info->[2], "#$info->[1]", $info->[2]);
    }
    $toc->_end_list;
    $toc->_put_markup('toc', 'etag');
    return $toc;
}

# verbatims: block level nowiki "\n{{{\n...\n}}}\n"
sub _insert_verbatim {
    my($self, $data) = @_;
    ($data) = $data =~ m/\A\{\{\{\n(.*?)$S*\n\}\}\}\n\z/mosx;
    $data =~ s/\A\x20\}\}\}/\}\}\}/mosx;
    $data =~ s/\n\x20\}\}\}/\n\}\}\}/gmosx;
    $self->_put_markup('verbatim', 'stag');
    $self->put_xml($data);
    $self->_put_markup('verbatim', 'etag');
    return $self;
}

# lists: "* ...", "# ...", "; ...\n: ..."
sub _start_list {
    my($self, $data) = @_;
    $self->{list} = [];
    $self->_phrase_clear;
    return $self->_insert_list($data);
}

# inline colon "; term : definition"
sub _insert_colon {
    my($self, $data) = @_;
    return $self->_insert_list(q[:] x $self->{list}[-1][0]);
}

sub _insert_list {
    my($self, $data) = @_;
    $self->_phrase_flush;
    my($mark) = $data =~ /\A([\*\#;:]+)/mosx;
    my $level = length $mark;
    $mark = substr $mark, 0, 1;
    while (@{$self->{list}} > 1 && $level < $self->{list}[-1][0]) {
        if ($self->{list}[-2][0] < $level) {
            $self->{list}[-1][0] = $level;
            last;
        }
        my $e = pop @{$self->{list}};
        $self->_put_markup($e->[1], 'etag');
    }
    if (! @{$self->{list}}) {
        $self->_put_markup($mark, 'stag');
        push @{$self->{list}}, [$level, $mark];
    }
    elsif ($self->{list}[-1][0] < $level) {
        my $prev = $self->{list}[-1][1];
        if ($prev eq q{;} && ($mark eq q{*} || $mark eq q{#})) {
            $self->_put_markup(q[;], q[:]);
            $self->{list}[-1][1] = q[:];
        }
        $self->puts(q{});
        $self->_put_markup($mark, 'stag');
        push @{$self->{list}}, [$level, $mark];
    }
    else {
        my $prev = $self->{list}[-1][1];
        $self->_put_markup($prev, $mark);
        @{$self->{list}[-1]} = ($level, $mark);
    }
    $self->_phrase_clear;
    return $self;
}

sub _end_list {
    my($self, $data) = @_;
    $self->_phrase_flush;
    while (@{$self->{list}}) {
        my $e = pop @{$self->{list}};
        $self->_put_markup($e->[1], 'etag');
    }
    $self->{list} = undef;
    return $self;
}

# tables: "|=..|..|..|"
sub _start_table {
    my($self, $data) = @_;
    $self->_put_markup(q[||], 'stag');
    ($self->{table}) = $data =~ /\A(\|=?)/mosx;
    return $self->_start_block($self->{table});
}

sub _insert_tr {
    my($self, $data) = @_;
    $self->_end_block($self->{table});
    $self->_put_markup(q[||], q[||]);
    ($self->{table}) = $data =~ /\A(\|=?)/mosx;
    return $self->_start_block($self->{table});
}

sub _insert_td {
    my($self, $data) = @_;
    $self->_end_block($self->{table});
    ($self->{table}) = $data =~ /\A(\|=?)/mosx;
    return $self->_start_block($self->{table});
}

sub _end_table {
    my($self, $data) = @_;
    $self->_end_block($self->{table});
    $self->_put_markup(q[||], 'etag');
    $self->{table} = undef;
    return $self;
}

# indented paragraphs: ": ...", "> ..."
sub _start_indent {
    my($self, $data) = @_;
    $self->{indent} = 0;
    return $self->_insert_indent($data);
}

sub _insert_indent {
    my($self, $data) = @_;
    $data =~ s/$S+//mosx;
    my $level = length $data;
    while ($self->{indent} > $level) {
        $self->_put_markup(q{>}, 'etag');
        --$self->{indent};
    }
    if ($self->{indent} < $level) {
        while ($self->{indent} < $level) {
            $self->_put_markup(q{>}, 'stag');
            ++$self->{indent};
        }
    }
    else {
        $self->{indent} = $level;
    }
    return $self;
}

sub _end_indent {
    my($self, $data) = @_;
    return $self->_insert_indent(q{});
}

# INLINE ACTION
# phrases: bold("**"), italic("//"),
#   monospace("##"), superscript("^^"), subscript(",,"), underline("__")
sub _phrase_clear {
    my($self) = @_;
    $self->{phrase} = {};
    $self->{phrase_stack} = [];
    return $self;
}

sub _insert_phrase {
    my($self, $mark) = @_;
    if (! $self->{phrase}{$mark}) {
        $self->{phrase}{$mark} = 1;
        push @{$self->{phrase_stack}}, $mark;
        $self->_put_markup($mark, 'stag');
    }
    elsif ($self->{phrase_stack}[-1] eq $mark) {
        $self->{phrase}{$mark} = 0;
        pop @{$self->{phrase_stack}};
        $self->_put_markup($mark, 'etag');
    }
    else {
        $self->put($mark);
    }
    return $self;
}

sub _phrase_flush {
    my($self) = @_;
    return $self if ! $self->{phrase_stack} || ! @{$self->{phrase_stack}};
    while (my $mark = pop @{$self->{phrase_stack}}) {
        $self->_put_markup($mark, 'etag');
    }
    $self->{phrase} = {};
    return $self;
}

# break lines: "\\\\"
sub _insert_br { return shift->_put_markup(q{\\\\}, 'tag') }

# inline nowikis: "{{{...}}}"
sub _insert_nowiki {
    my($self, $data) = @_;
    my($text) = $data =~ /\A\{\{\{$S*(.*?)$S*\}\}\}\z/mosx;
    $self->_put_markup('nowiki', 'stag');
    $self->put_xml($text);
    $self->_put_markup('nowiki', 'etag');
    return $self;
}

# an escaped mark and an escaped character: "~..."
sub _insert_escaped {
    my($self, $data) = @_;
    my $text = length $data == 1 ? $data : (substr $data, 1);
    $self->put($text);
    return $self;
}

# placeholders: "<<< ... >>>"
sub _insert_placeholder {
    my($self, $data) = @_;
    my($body) = $data =~ m{\A<<<(.*)>>>\z}mosx;
    $self->_put_markup(q{<<<}, 'stag');
    $self->put_xml($body);
    $self->_put_markup(q{<<<}, 'etag');
    return $self;
}

# plugin calls: "<< ... >>"
sub _insert_plugin {
    my($self, $data) = @_;
    if (! $self->{plugin_run}) { # avoid infinite recursive calls
        local $self->{plugin_run} = 1; ## no critic qw(LocalVars)
        my $visitor = $self->{plugin_visitor} || $self;
        my($body) = $data =~ m{\A<<$S*(.*?)$S*>>\z}mosx;
        $visitor->visit_plugin($body, $self);
    }
    return $self;
}

# links: "[[ url | description ]]"
sub _insert_bracketed {
    my($self, $data) = @_;
    if ($data =~ /\A\[\[$S*([^\|]*?)$S*(?:\|$S*(.*?)$S*)?\]\]\z/mosx) {
        return $self->_insert_link($data, $1, ! defined $2 ? $1 : $2);
    }
    return $self->put($data);
}

# freestand links: url and CamelCased wiki words
sub _insert_freestand {
    my($self, $data) = @_;
    return $self->_insert_link($data, $data, $data);
}

sub _insert_link {
    my($self, $data, $link, $title) = @_;
    my $visitor = $self->{link_visitor} || $self;
    my $anchor = $visitor->visit_link($link, $title, $self);
    if (! $anchor || (! $anchor->{name} && ! $anchor->{href})) {
        return $self->put($data);
    }
    my $attr = q{};
    if (my $href = $anchor->{href}) {
        $attr .= q{ href="} . $self->escape_uri($href) . q{"};
    }
    for my $k (qw(id name class rel rev type title)) {
        next if ! $anchor->{$k};
        $attr .= qq{ $k="} . $self->escape_text($anchor->{$k}) . q{"};
    }
    if (exists $anchor->{before}) {
        $self->put_raw($anchor->{before});
    }
    $self->put_raw(qq{<a$attr>});
    $self->put(exists $anchor->{data} ? $anchor->{data} : $title);
    $self->put_raw(q{</a>});
    if (exists $anchor->{after}) {
        $self->put_raw($anchor->{after});
    }
    return $self;
}

# images: "{{ url | description }}"
sub _insert_braced {
    my($self, $data) = @_;
    if ($data =~ /\A\{\{$S*([^\|]*?)$S*(?:\|$S*(.*?)$S*)?\}\}\z/mosx) {
        my($link, $title) = ($1, ! defined $2 ? $1 : $2);
        my $visitor = $self->{link_visitor} || $self;
        my $image = $visitor->visit_image($link, $title, $self);
        if (! $image || ! $image->{src}) {
            return $self->put($data);
        }
        my $attr = q{ src="} . $self->escape_uri($image->{src}) . q{"};
        for my $k (qw(id class alt title)) {
            next if ! $image->{$k};
            $attr .= qq{ $k="} . $self->escape_text($image->{$k}) . q{"};
        }
        $self->put_raw(qq{<img$attr />});
        return $self;
    }
    return $self->put($data);
}

1;

__END__

=pod

=head1 NAME

Text::Creolize::Xs - A practical converter for WikiCreole to XHTML.

=head1 VERSION

0.003

=head1 SYNOPSIS

    use Text::Creolize::Xs;
    use File::Slrup;
    use Encode;

    # from http://www.wikicreole.org/wiki/Creole1.0TestCases
    my $source = read_file('creole1.0test.txt');
    $source = decode('UTF-8', $source);
    my $xhtml = Text::Creolize::Xs->new->convert($source)->result;
    print encode('UTF-8', $xhtml);

=head1 DESCRIPTION

This module provides you to convert a WikiCreole formatted string
to XHTML.

=head1 METHODS

=over

=item C<< $creolize = Text::Creolize->new >>

Creates new converter.

=item C<< $creolize->script_name >>

Readwrite attribute accessor for the script_name.
The attribute value may be used to construct word links.

=item C<< $creolize->static_location >>

Readwrite attribute accessor for the static location.
The attribute value may be used to construct image sources.

=item C<< $creolize->link_visitor >>

Readwrite attribute accessor for the link visitor.

=item C<< $creolize->plugin_visitor >>

Readwrite attribute accessor for the plugin visitor.

=item C<< $creolize->convert($string) >>

Converts from a WikiCreole formatted string to a XHTML one.
The utf8 flag of the string should be turned on.

=item C<< $creolize->toc(4) >>

When number of headings is greater than this property value,
creates and inserts the table of contents at the top of the
XHTML result.

=item C<< $toc_arrayref = $creolize->tocinfo >>

Gets the list of headings's nesting level, its XML element id,
and inner text.

=item C<< $creolize->put($string) >>

Appends string with escaping as a parsed XML TEXT.
The utf8 flag of the string should be turned on.

=item C<< $creolize->puts >>

Appends end of line mark or blank.

=item C<< $creolize->put_xml($string) >>

Appends string with escaping as an unparsed XML TEXT.
The utf8 flag of the string should be turned on.

=item C<< $creolize->put_raw($string) >>

Appends string without escapings.
The utf8 flag of the string should be turned on.

=item C<< $base36 = $creolize->hash_base36($string) >>

Calculates the hash value of the given string.

=item C<< $string = $creolize->result >>

Gets a converted result. It's utf8 flag will be turned on.

=item C<< $link_visitor->visit_link($link, $title, $builder) >>

The visitor's hook when the converter catches a href link.

=item C<< $link_visitor->visit_image($link, $title, $builder) >>

The visitor's hook when the converter catches a image link.

=item C<< $plugin_visitor->visit_plugin($data, $builder) >>

The visitor's hook when the converter catches a plugin.

=item C<< $markup_visitor->visit_markup($mark, $type, $builder) >>

The visitor's hook when the converter catches a markup.

=item C<< $string = $creolize->escape_text($string) >>

Escapes XML special characters without XHTML entities.

=item C<< $string = $creolize->escape_xml($string) >>

Escapes XML special characters.

=item C<< $string = $creolize->escape_uri($string) >>

Encode URI with parcent encoded.

=item C<< $string = $creolize->escape_name($string) >>

Encode URI with parcent encoded for a name part.

=back

=head1 LIMITATION

Cannot recognize double bracketted arrow links.

=head1 DEPENDENCIES

L<Encode>
L<Digest::MurmurHash>

=head1 SEE ALSO

L<Text::WikiCreole>
L<http://www.wikicreole.org/wiki/Creole1.0>
L<http://www.wikicreole.org/wiki/CreoleAdditions>

=head1 AUTHOR

MIZUTANI Tociyuki  C<< <tociyuki@gmail.com> >>

=head1 LICENSE AND COPYRIGHT

Copyright (c) 2010, MIZUTANI Tociyuki C<< <tociyuki@gmail.com> >>.
All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself.

=cut

