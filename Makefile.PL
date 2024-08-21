use ExtUtils::MakeMaker;

WriteMakefile(
    NAME             => 'xclass',
    AUTHOR           => 'OnEhIppY @ DomeroSoftware <domerosoftware@gmail.com>',
    VERSION_FROM     => 'lib/xclass.pm',
    ABSTRACT_FROM    => 'lib/xclass.pm',
    LICENSE          => 'perl_5',
    MIN_PERL_VERSION => '5.010',
    PREREQ_PM        => {
        'threads'          => 0,
        'threads::shared'  => 0,
        'Thread::Semaphore'=> 0,
        'Thread::Queue'    => 0,
        'Scalar::Util'     => 0,
        'List::Util'       => 0,
        'Time::HiRes'      => 0,
        'Try::Tiny'        => 0,
        'JSON::XS'         => 0,
        'YAML::XS'         => 0,
        'Storable'         => 0,
        'IO::Handle'       => 0,
        'Fcntl'            => 0,
        'Encode'           => 0,
        'Compress::Zlib'   => 0,
        'File::Temp'       => 0,
        'Socket'           => 0,
        'Data::MessagePack'=> 0,
        'B::Deparse'       => 0,
        'Devel::Size'      => 0,
        'Devel::Cycle'     => 0,
        'Benchmark'        => 0,
        'Log::Log4perl'    => 0,
    },
    TEST_REQUIRES    => {
        'Test::More'        => 0,
        'Test::MemoryGrowth'=> 0,
        'Test::Exception'   => 0,
        'Test::Warn'        => 0,
    },
    META_MERGE => {
        'meta-spec' => { version => 2 },
        resources => {
            repository => {
                type => 'git',
                url  => 'https://github.com/DomeroSoftware/xclass.git',
                web  => 'https://github.com/DomeroSoftware/xclass',
            },
            bugtracker => {
                web => 'https://github.com/DomeroSoftware/xclass/issues',
            },
        },
    },
);
