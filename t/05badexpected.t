#!/usr/bin/perl

use strict;
use warnings;

use Test::More tests => 2;
use Test::Builder::Tester;
use Test::XML::Easy;

eval {
  test_xml("<foo/>",undef);
};
like($@, "/expected argument must be defined/","complains if you pass in undef as expected");

eval {
  test_xml("<foo/>","Not Valid XML");
};
ok($@,"complains if invalid XML expected");