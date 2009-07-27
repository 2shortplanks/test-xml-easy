#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 4;
use Test::Builder::Tester;
use Test::XML::Easy;

########################################################################
# well formed

test_out("ok 1 - xml test");
is_well_formed_xml(<<'ENDOFXML',);
<foo/>
ENDOFXML
test_test("well formed as expected");

test_out("not ok 1 - xml test");
test_fail(+2);
test_err("/.*?/");
is_well_formed_xml(<<'ENDOFXML');
This isn't XML'
ENDOFXML
test_test("not well formed, but expected it to be");

########################################################################
# not well formed

test_out("not ok 1 - xml test");
test_fail(+2);
test_err("/.*?/");
isnt_well_formed_xml(<<'ENDOFXML');
This isn't XML'
ENDOFXML
test_test("not well formed as expected");

test_out("not ok 1 - xml test");
test_fail(+2);
test_diag("Unexpectedly well formed XML");
isnt_well_formed_xml(<<'ENDOFXML');
<foo/>
ENDOFXML
test_test("well formed, but expected it not to be");
