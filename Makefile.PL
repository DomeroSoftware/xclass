use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'gclass',
    AUTHOR           => 'OnEhIppY @ DomeroSoftware <domerosoftware@gmail.com>',
    VERSION_FROM     => 'lib/gclass.pm',
    ABSTRACT_FROM    => 'lib/gclass.pm',
    LICENSE          => 'artistic_2',
    MIN_PERL_VERSION => '5.010',
    PREREQ_PM        => {
        'Carp'           => 0,
        'Scalar::Util'   => 0,
        'Thread::Queue'  => 0,
        'threads'        => 0,
        'threads::shared'=> 0,
        'Type::Tiny'     => 0,
        'JSON'           => 0,
        'YAML'           => 0,
        'Storable'       => 0,
    },
    TEST_REQUIRES    => {
        'Test::More'     => 0,
        'Test::Deep'     => 0,
        'Test::Exception'=> 0,
        'Test::Warn'     => 0,
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/DomeroSoftware/gclass.git',
                web  => 'https://github.com/DomeroSoftware/gclass',
            },
            bugtracker => {
                web => 'https://github.com/DomeroSoftware/gclass/issues',
            },
        },
    },
);
