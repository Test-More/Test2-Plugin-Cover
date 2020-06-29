use Test2::Plugin::Cover;
use Test2::V0 -target => 'Test2::Plugin::Cover';
use Path::Tiny qw/path/;
use File::Spec();
use Fcntl qw/O_RDONLY/;

BEGIN { unshift @INC => 't/lib' }

use Fake1;
use Fake2;

subtest simple_coverage => sub {
    # Start fresh
    $CLASS->clear;

    is(Fake1->fake, 'fake', "Got fake 1");
    is(Fake2->fake, 'fake', "Got fake 2");

    # This is just to add another sub call we want filtered
    path('.');

    ok(keys %Test2::Plugin::Cover::FILES > 2,                          "More than 2 files were tracked");
    ok((grep { m/Path.Tiny\.pm$/ } keys %Test2::Plugin::Cover::FILES), "Path::Tiny is in the list of files seen");

    is(
        $CLASS->files(root => path('t/lib')),
        [
            'Fake1.pm',
            'Fake2.pm',
        ],
        "Got just the 2 files under the specified dir"
    );

    $CLASS->clear;
    my %data = %Test2::Plugin::Cover::FILES;
    ok(!keys %data, "wiped out coverage data");
};

subtest goto_and_lvalue => sub {
    $CLASS->clear;
    Fake1->gfake;
    is($CLASS->files(root => path('t/lib')), ['Fake1.pm',], "Found with a goto");

    $CLASS->clear;
    Fake1->lfake = 'xxx';
    is($CLASS->files(root => path('t/lib')), ['Fake1.pm',], "Found with an lvalue");
};

subtest open_files => sub {
    $CLASS->clear;
    my $fh;
    open($fh, '<', 'aaa.json');
    open($fh, '<bbb.json');
    open($fh, '+<ccc.json');
    open($fh, '-<ddd.json');
    open($fh, File::Spec->catfile('dir', 'eee'));

    sysopen($fh, 'fff.json', O_RDONLY);
    sysopen($fh, 'ggg.json', O_RDONLY, 0);

    close($fh);
    like(
        $CLASS->files(root => path('.')),
        bag {
            item('aaa.json');
            item('bbb.json');
            item('ccc.json');
            item('ddd.json');
            item(File::Spec->catfile('dir', 'eee'));
            item('fff.json');
            item('ggg.json');
        },
        "Got files we (tried to) open"
    );
};

# Final cleanup
$CLASS->clear;
$CLASS->filter("not a file");
like($CLASS->files(), [qr/lib.Test2.Plugin.Cover\.pm$/], "Found Test::Plugin::Cover");

done_testing;
