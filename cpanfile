# This file is generated by Dist::Zilla::Plugin::CPANFile v6.024
# Do not edit this file directly. To change prereqs, edit the `dist.ini` file.

requires "Carp" => "0";
requires "File::Spec" => "0";
requires "Path::Tiny" => "0.048";
requires "Test2::API" => "1.302166";
requires "Test2::EventFacet" => "1.302166";
requires "perl" => "5.012000";

on 'test' => sub {
  requires "Fcntl" => "0";
  requires "Test2::V0" => "0.000130";
};

on 'configure' => sub {
  requires "ExtUtils::MakeMaker" => "0";
};

on 'develop' => sub {
  requires "Test::Pod" => "1.41";
};
