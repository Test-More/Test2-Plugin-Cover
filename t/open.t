use Test2::Plugin::Cover;
use Test2::V0 -target => 'Test2::Plugin::Cover';
use Path::Tiny qw/path/;
use File::Spec();

BEGIN { unshift @INC => 't/lib' }

$Test2::Plugin::Cover::TRACE_OPENS = 0;

$CLASS->reset_coverage;
my $fh;
open($fh, '<', 'aaa.json');
open($fh, '<bbb.json');
$CLASS->set_from('xxx');
open($fh, '+<ccc.json');

is(@Test2::Plugin::Cover::OPENS, 0, "No Opens traced");
$Test2::Plugin::Cover::TRACE_OPENS = 1;

require OpenXXX;
OpenXXX->doit();

$CLASS->set_from(['yyy']);
open($fh, File::Spec->catfile('dir', 'eee'));

my $eee = path(File::Spec->catfile('dir', 'eee'))->relative(path('.'))->stringify();

$Test2::Plugin::Cover::TRACE_OPENS = 0;

is(
    \@Test2::Plugin::Cover::OPENS,
    [
        ['-<ddd.json', 't/lib/OpenXXX.pm', 9,  'OpenXXX'],
        ['dir/eee',    't/lib/OpenXXX.pm', 10, 'OpenXXX'],
        ['dir/eee',    't/lib/OpenXXX.pm', 11, 'OpenXXX'],
        ['dir/eee',    't/open.t',         24, 'main'],
    ],
    "Traced opens",
);

close($fh);
my $data = $CLASS->files(root => path('.'));
like(
    [ sort grep { !m/\.pm$/ } @$data ],
    array {
        item 'aaa.json';
        item 'bbb.json';
        item 'ccc.json';
        item 'ddd.json';
        item $eee;
    },
    "Got files we (tried to) open",
);

$data = $CLASS->data(root => path('.'));
like(
    $data,
    hash {
        field 'aaa.json' => {'<>' => ['*']};
        field 'bbb.json' => {'<>' => ['*']};
        field 'ccc.json' => {'<>' => ['xxx']};
        field 'ddd.json' => {'<>' => ['xxx']};
        field $eee       => {'<>' => [['yyy'], 'xxx']};
    },
    "Got list of what callers tried to open the files"
);

$CLASS->reset_coverage;

# The next several are to make sure things do not segv, nothing useful can be captured from them
my $ref = "";
open($fh, '>', \$ref);
print $fh "HI\n";
close($fh);
is($ref, "HI\n", "Wrote hi");

# This will incidentally catch the last statement as a potential file, thats
# fine.
open($fh, '-|', $^X, '-e', 'print "HI\n"; exit 0');
close($fh);
ok(1, "Made it here");

# Final cleanup
$CLASS->reset_coverage;

done_testing;
