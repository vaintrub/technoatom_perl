use ExtUtils::MakeMaker;

WriteMakefile(
    NAME            => 'Local::P2P::Client',
    VERSION_FROM    => 'lib/Local/P2P/Client.pm',
    EXE_FILES => [
        'bin/p2p-client.pl',
    ],
);
