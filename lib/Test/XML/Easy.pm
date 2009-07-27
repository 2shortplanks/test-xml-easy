package Test::XML::Easy;

use strict;
#use warnings; not for this module

use vars qw(@EXPORT @ISA);
use Exporter;
@ISA = qw(Exporter);

our $VERSION = '0.01';

use Carp qw(croak);
use Scalar::Util qw(blessed);

use XML::Easy::Text qw(xml10_read_document);

use Test::Builder;
my $tester = Test::Builder->new();

=head1 NAME

Test::XML::Easy - test XML with XML::Easy

=head1 SYNOPSIS

    use Test::More tests => 2;
    use Test::XML::Easy;

    is_xml $some_xml, <<'ENDOFXML', "a test";
    <?xml version="1.0" encoding="latin-1">
    <foo>
       <bar/>
       <baz buzz="bizz">fuzz</baz>
    </foo>
    ENDOFXML

    is_xml $some_xml, <<'ENDOFXML', { ignore_whitespace => 1, description => "my test" };
    <foo>
       <bar/>
       <baz buzz="bizz">fuzz</baz>
    </foo>
    ENDOFXML

    isnt_xml $some_xml, $some_xml_it_must_not_be;
    
    is_well_formed_xml $some_xml;

=head1 DESCRIPTION

A simple testing tool, with only pure Perl dependancies, that checks if
two XML documents are equal with respect to the XML 1.0 specification.

By "equal" we mean that the two documents would construct the same DOM model
when parsed, so things like character sets and if you've used two tags
or a self closing tags aren't important.

This modules is a strict superset of Test::XML's interface.

=head2 Functions

=over

=item is_xml($xml_to_test, $expected_xml, $options_hashref)

Tests that the passed XML is the same as the expected XML.
XML can be passed into this function in one of two ways.

=over

=item An XML::Easy::Element

=item A string

=back

This funtion takes several options as the third argument.

These can be passed in as a hashref:

=over

=item description

The name of the test that will be passed out.

=item ignore_whitespace

Ignore many whitespace differences in text nodes.  Currently
this has the same effect as turning on C<ignore_surrounding_whitespace>
and C<ignore_different_whitespace>.

=item ignore_surrounding_whitespace

Ignore differences in leading and trailing whitespace
between elements.  This means that

  <p>foo bar baz</p>

Is considered the same as

  <p>
    foo bar baz
  </p>

Note that this is only between elements, so this document

  <p>foo<!-- a comment -->bar</p>

Would be considered different to

  <p>
    foo
    <!-- a comment -->
    bar
  </p>

Due to the additional whitespace between "foo" and the comment
and the comment and "bar".

=item ignore_leading_whitespace

The same as C<ignore_surrounding_whitespace> but only ignore
the whitespace immediately after an element node not
immedately before.

=item ignore_trailing_whitespace

The same as C<ignore_surrounding_whitespace> but only ignore
the whitespace immediately before an element node not
immedately after.

=item ignore_different_whitespace

If set to a true value ignores differences in what characters
make up whitespace in text nodes.  In other words, this option
makes the comparison only care that wherever there's whitespace
in the expected xml there's any whitespace in the actual xml
at all, not what that whitespace is made up of.

It means the following

  <p>
    foo bar baz
  </p>

Is the same as

  <p>
    foo
    bar
    baz
  </p>

But not the same as

  <p>
    foobarbaz
  </p>

This setting has no effect on attribute comparisons.

=item verbose

If true, print obsessive amounts of debug info out while
checking things

=back

If a third argument is passed to this function and that argument
is not a hashref then it will be assumed that this argument is
the the description as passed above.  i.e.

  is_xml $xml, $expected, "my test";

is the same as

  is_xml $xml, $expected, { description => "my test" };

=cut

sub is_xml($$;$) {
  my $got = shift;
  my $expected = shift;

  unless (defined $expected) {
    croak("expected argument must be defined");
  }

  # munge the options
  my $options = shift;
  $options = { description => $options } unless ref $options;
  $options = { %{$options}, description => "xml test" } unless defined $options->{description};
  unless (blessed $expected && $expected->isa("XML::Easy::Element")) {
    # throws an exception if there isn't a problem.
    $expected = eval { xml10_read_document($expected) };
    if ($@) {
      croak "Couldn't parse expected XML document: $@";
    }
  }

  # convert into something useful if needed
  unless (blessed($got) && $got->isa("XML::Easy::Element")) {
    my $parsed = eval { xml10_read_document($got) };
    if ($@) {
      $tester->ok(0, $options->{description});
      $tester->diag("Couldn't parse submitted XML document:");
      $tester->diag("  $@");
      return;
    }

    $got = $parsed;
  }

  if(_is_xml($got,$expected,$options,"", {})) {
    $tester->ok(1,$options->{description});
    return 1;
  }

  return;
}
push @EXPORT, "is_xml";

sub _is_xml {
  my $got      = shift;
  my $expected = shift;
  my $options  = shift;

  # this is the path
  my $path     = shift;

  # the index is used to keep track of how many of a particular
  # typename of a particular element we've seen as previous siblings
  # of the node that just got in.  It's a hashref with type_name and
  # the index.
  my $index    = shift;

  # change where the errors are reported from
  local $Test::Builder::Level = $Test::Builder::Level + 1;

  # work out the details of the node we're looking at
  # nb add one to the index because xpath is weirdly 1-index
  # not 0-indexed like most other modern languages
  my $got_name       = $got->type_name();
  my $got_index      = ($index->{ $got_name } || 0) + 1;

  ### check if we've got a node to compare to

  unless ($expected) {
    $tester->ok(0, $options->{description});
    $tester->diag("Element '$path/$got_name\[$got_index]' was not expected");
    return;
  }

  ### check the node name

  # work out the details of the node we're comparing with
  my $expected_name  = $expected->type_name();
  my $expected_index = ($index->{ $expected_name } || 0) + 1;

  # alter the index hashref to record we've seen another node
  # of this name
  $index->{$got_name}++;

  $tester->diag("comparing '$path/$got_name\[$expected_index]' to '$path/$expected_name\[$expected_index]'...") if $options->{verbose};

  if ($got_name ne $expected_name) {
    $tester->ok(0, $options->{description});
    $tester->diag("Element '$path/$got_name\[$got_index]' does not match '$path/$expected_name\[$expected_index]'");
    return;
  }
  $tester->diag("...matched name") if $options->{verbose};

  ### check the attributes

  # we're not looking at decendents, so burn the path of
  # this node into the path we got passed in
  $path .= "/$got_name\[$got_index]";

  # XML::Easy returns read only data structures
  # we want to modify these to keep track of what
  # we've processed, so we need to copy them
  my %got_attr      = %{ $got->attributes };
  my $expected_attr = $expected->attributes;

  foreach my $attr (keys %{ $expected_attr }) {
    $tester->diag("checking attribute '$path/\@$attr'...") if $options->{verbose};

    if (!exists($got_attr{$attr})) {
      $tester->ok(0, $options->{description});
      $tester->diag("expected attribute '$path/\@$attr' not found");
      return;
    }
    $tester->diag("...found attribute") if $options->{verbose};

    my $expected_string = $expected_attr->{$attr};
    my $got_string      = delete $got_attr{$attr};

    if ($expected_string ne $got_string) {
      $tester->ok(0, $options->{description});
      $tester->diag("attribute value for '$path/\@$attr' didn't match");
      $tester->diag("found value:\n");
      $tester->diag("  '$got_string'\n");
      $tester->diag("expected value:\n");
      $tester->diag("  '$expected_string'\n");
      return;
    }
    $tester->diag("...the attribute contents matched") if $options->{verbose};
  }
  if (keys %got_attr) {
    $tester->ok(0, $options->{description});
    $tester->diag("found extra unexpected attribute".(keys %got_attr>1 ? "s":"").":");
    $tester->diag("  '$path/\@$_'") foreach sort keys %got_attr;
    return;
  }
  $tester->diag("the attributes all matched") if $options->{verbose};

  ### check the child nodes

  # create a new index to pass to our children distint from
  # the index that was passed in to us (as that one was created
  # by our parent for me and my siblings)
  my $child_index = {};

  # grab the child text...element...text...element...text...
  my $got_content      = $got->content;
  my $expected_content = $expected->content;

  # step though the text/elements
  # nb this loop works in steps of two;  The other $i++
  # is half way through the loop below
  for (my $i = 0; $i < @{$got_content}; $i++) {

    ### check the text node

    # extract the text from the object
    my $got_text      = $got_content->[ $i ];
    my $expected_text = $expected_content->[ $i ];
    my $comp_got_text      = $got_text;
    my $comp_expected_text = $expected_text;

    if ($options->{ignore_whitespace} || $options->{ignore_leading_whitespace} || $options->{ignore_surrounding_whitespace}) {
      $comp_got_text =~ s/ \A \s* //x;
      $comp_expected_text =~ s/ \A \s* //x;
    }

    if ($options->{ignore_whitespace} || $options->{ignore_trailing_whitespace} || $options->{ignore_surrounding_whitespace}) {
      $comp_got_text =~ s/ \s* \z//x;
      $comp_expected_text =~ s/ \s* \z//x;
    }

    if ($options->{ignore_whitespace} || $options->{ignore_different_whitespace}) {
      $comp_got_text =~ s/ \s+ / /gx;
      $comp_expected_text =~ s/ \s+ / /gx;
    }

    if ($comp_got_text ne $comp_expected_text) {

      $tester->ok(0, $options->{description});

      # I don't like these error message not being specific with xpath but as
      # far as I know  there's no easy way to express in xpath the text immediatly following
      # a particular element.  The best I could come up with was this mouthful:
      # "$path/following-sibling::text()[ previous-sibling::*[1] == $path ]"

      if ($i == 0) {
        if (@{ $got_content } == 1 && @{ $expected_content } == 1) {
          $tester->diag("text inside '$path' didn't match");
        } else {
          $tester->diag("text immediately inside opening tag of '$path' didn't match");
        }
      } elsif ($i == @{ $got_content} - 1 && $i == @{ $expected_content } - 1 ) {
        $tester->diag("text immediately before closing tag of '$path' didn't match");
      } else {
        my $name = $got_content->[ $i - 1 ]->type_name;
        my $ind = $child_index->{ $name };
        $tester->diag("text immediately after '$path/$name\[$ind]' didn't match");
      }

      $tester->diag("found:\n");
      $tester->diag("  '$got_text'\n");
      $tester->diag("expected:\n");
      $tester->diag("  '$expected_text'\n");

      if ($options->{verbose}) {
        $tester->diag("compared found text:\n");
        $tester->diag("  '$comp_got_text'\n");
        $tester->diag("against text:\n");
        $tester->diag("  '$comp_expected_text'\n");
      }

      return;
    }

    # move onto the next (elemnent) node if we didn't reach the end
    $i++;
    last if $i >= @{$got_content};

    ### check the element node

    # simply recurse for that node
    # (don't bother checking if the expected node is defined or not, the case
    # where it isn't is handled at the start of _is_xml)
    return unless _is_xml(
      $got_content->[$i],
      $expected_content->[$i],
      $options,
      $path,
      $child_index
    );
  }

  # check if we expected more nodes
  if (@{ $expected_content } > @{ $got_content }) {
    my $expected_nom = $expected_content->[ scalar @{ $got_content } ]->type_name;
    my $expected_ind = $child_index->{ $expected_nom } + 1;
    $tester->diag("Couldn't find expected node '$path/$expected_nom\[$expected_ind]'");
    $tester->ok(0, $options->{description});
    return;
  }

  return 1;
}

=item isnt_xml($xml_to_test, $expected_xml, $options_hashref)

Exactly the same as C<is_xml> (taking exactly the same options) but passes
if and only if the xml to test is different to the expected xml.

=cut

sub isnt_xml($$;$) {
  # TODO
}
push @EXPORT, "isnt_xml";

=item is_well_formed_xml($string_containing_xml, $description)

Passes if and only if the string passed contains well formed XML.

=cut

sub is_well_formed_xml($;$) {
  # TODO
}
push @EXPORT, "is_well_formed_xml";

=item isnt_well_formed_xml($string_not_containing_xml, $description)

Passes if and only if the string passed does not contain well formed XML.

=cut

sub isnt_well_formed_xml($;$) {
  # TODO
}
push @EXPORT, "isnt_well_formed_xml";

=back

=head2 A note on Character Handling

If you do not pass it an XML::Easy::Element object then C<is_xml> will happly parse
XML from the characters contained in whatever scalars you passed it.  It will not
(and cannot) correctly parse data from a scalar that contains binary data (e.g. that
you've sucked in from a raw file handle) as it would have no idea what characters
those octlets would represent

As long as your XML document contains legal characters from the ASCII range (i.e.
chr(1) to chr(127)) this distintion will not matter to you.

However, if you use characters above codepoint 127 then you will probably need to
convert any bytes you have read in into characters.  This is usually done by using
C<Encode::decode>, or by using a PerlIO layer on the filehandle as you read the data
in.

If you don't know what any of this means I suggest you read the Encode::encode manpage
very carefully.  Tom Insam's slides at L<http://jerakeen.org/talks/perl-loves-utf8/>
may or may not help you understand this more (they at the very least contain a
cheatsheet for conversion.)

The author highly recommends those of you using latin-1 characters from a utf-8 source
to use Test::utf8 to check the string for common mistakes before handing it is_xml.

=head1 AUTHOR

Mark Fowler, C<< <mark@twoshortplanks.com> >>

Copyright 2009 PhotoBox, All Rights Reserved.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

=head1 BUGS

There's a few cavets when using this module:

=over

=item Not a validating parser

Infact, we don't process (or compare) DTDs at all.  These nodes are completely
ignored (it's as if you didn't include them in the string at all.)

=item Comments and processing instructions are ignored

We totally ignore comments and processing instructions, and it's as
if you didn't include them in the string at all either.

=item Limited entity handling

Currently we only support the five "core" named entities (i.e. C<&amp;>,
C<&lt;>, C<&gt;>, C<&apos;> and C<&quot;>) and numerical entities
(in decimal or hex form.)  It is not possible to declare further named
entities and the precence of undeclared named entities will either cause
an exception to be thrown (in the case of the expected string) or the test to
fail (in the case of the string you are testing)

=item No namespace support

Currently this is only an XML 1.0 parser, and not XML Namespaces aware (further
options may be added to later version of this module)

This means the following document:

  <foo:fred xmlns:foo="http://www.twoshortplanks.com/namespaces/test/fred" />

Is considered to be different to

  <bar:fred xmlns:bar="http://www.twoshortplanks.com/namespaces/test/fred" />

=item Perlish whitespace handling

This module considers "whitespace" to be whatever matches a \s* in a
regular expression.  This is not strictly identical to what the XML
specification considers to be whitespace.

=back

Please see http://twoshortplanks.com/dev/testxmleasy for
details of how to submit bugs, access the source control for
this project, and contact the author.

=head1 SEE ALSO

L<Test::More> (for instructions on how to test), L<XML::Easy> (for info
on the underlying xml parser) and L<Test::XML> (for a similar module that
tests using XML::Parser)

=cut

1; # End of Test::XML::Easy
