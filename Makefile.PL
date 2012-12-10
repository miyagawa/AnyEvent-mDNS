use inc::Module::Install;
name 'AnyEvent-mDNS';
all_from 'lib/AnyEvent/mDNS.pm';

requires 'AnyEvent', 7;
requires 'AnyEvent::Handle::UDP';

build_requires 'Test::More';
use_test_base;
auto_include_deps;
author_tests('xt');
auto_set_repository;
WriteAll;
